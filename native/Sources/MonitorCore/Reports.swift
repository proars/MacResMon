import Foundation

// Reports: a persistent per-day record of power use and a log of temperature spikes. Pure (no files, no UI):
// ReportStore in the app persists it, the Reports page and the CSV export read it. Cost is never stored,
// it is energy x the current price, so changing the price re-costs the whole history.

public struct SpikeEvent: Codable, Equatable {
    public var start: Double          // ms since 1970
    public var end: Double
    public var sensor: String         // "CPU" | "GPU"
    public var peakC: Double
    public var ongoing = false
    public var peakAt: Double?        // when the peak was reached (nil in logs saved before this existed)
    public var peakSecs: Double?      // seconds spent within `peakBand` °C of the peak
    /// "At the peak" means this close to the highest temperature of the episode.
    public static let peakBand = 1.0
    public init(start: Double, end: Double, sensor: String, peakC: Double, ongoing: Bool = false, peakAt: Double? = nil, peakSecs: Double? = nil) {
        self.start = start; self.end = end; self.sensor = sensor; self.peakC = peakC; self.ongoing = ongoing
        self.peakAt = peakAt ?? start; self.peakSecs = peakSecs ?? 0
    }
}

public struct DayStats: Codable, Equatable {
    public var day: String            // local "YYYY-MM-DD"
    public var energyJ = 0.0          // whole-Mac energy (sys_power x time) while the app ran
    public var seconds = 0.0          // time that energy covers
    public var peakW = 0.0
    public var spikes = 0
    public var maxTempC: Double?
    public init(day: String) { self.day = day }
}

/// Local calendar day of a timestamp, "YYYY-MM-DD".
public func dayKey(_ ms: Double, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: ms / 1000))
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

public struct ReportLog: Codable, Equatable {
    /// Longest gap counted as time between two ticks (a sleeping Mac must not add hours of energy).
    public static let maxGap = 10.0
    /// Whole-Mac power above this is a sensor glitch, not a reading (no Apple Silicon Mac draws that much): ignored.
    public static let maxPlausibleW = 600.0
    /// A laptop (it has a battery) cannot draw more than its charger plus the battery: above this is a glitch too.
    public static let maxPlausibleLaptopW = 200.0
    /// Oldest spikes are dropped beyond this many, so the file stays small.
    public static let maxSpikes = 5000

    public private(set) var days: [String: DayStats] = [:]
    public private(set) var spikes: [SpikeEvent] = []
    private var open: [String: SpikeEvent] = [:]
    /// Seconds spent at each temperature (tenths of a degree) during an open episode, to tell at the end how long it stayed near the peak.
    private var heat: [String: [Int: Double]] = [:]
    private enum CodingKeys: String, CodingKey { case days, spikes }

    public init() {}

    /// Folds one tick in. `dt` is the seconds since the previous tick. Returns true when a spike started or ended
    /// (worth saving at once).
    @discardableResult
    public mutating func record(_ hw: Hardware?, at ms: Double, dt: Double, calendar: Calendar = .current, maxW: Double = ReportLog.maxPlausibleW) -> Bool {
        guard let hw = hw else { return false }
        let key = dayKey(ms, calendar: calendar)
        var day = days[key] ?? DayStats(day: key)
        var changed = false

        // Only ticks that cover time count (the first one has no dt), and only believable readings.
        if let w = hw.sysPower, w >= 0, w <= maxW, dt > 0 {
            let t = min(dt, Self.maxGap)
            day.energyJ += w * t
            day.seconds += t
            day.peakW = max(day.peakW, w)
        }

        for (sensor, temp) in [("CPU", hw.cpuTemp), ("GPU", hw.gpuTemp)] {
            if let t = temp, t.isFinite { day.maxTempC = max(day.maxTempC ?? t, t) }
            if let t = temp, t >= Limits.temp {
                heat[sensor, default: [:]][Int((t * 10).rounded()), default: 0] += min(max(dt, 0), Self.maxGap)
                if var e = open[sensor] {
                    e.end = ms
                    if t > e.peakC { e.peakC = t; e.peakAt = ms }
                    open[sensor] = e
                } else {
                    open[sensor] = SpikeEvent(start: ms, end: ms, sensor: sensor, peakC: t, ongoing: true)
                    day.spikes += 1
                    changed = true
                }
            } else if let e = open.removeValue(forKey: sensor) {
                append(closed(e))
                changed = true
            }
        }
        days[key] = day
        return changed
    }

    /// Closes episodes still open (on quit).
    public mutating func finish() {
        for e in open.values { append(closed(e)) }
        open = [:]
    }

    /// Finished spikes plus those in progress, oldest first.
    public var allSpikes: [SpikeEvent] { (spikes + open.values.map(withPeakTime)).sorted { $0.start < $1.start } }

    /// The episode with `peakSecs` filled in: time spent within `peakBand` degrees of its highest temperature.
    private func withPeakTime(_ e: SpikeEvent) -> SpikeEvent {
        var e = e
        let floor = Int(((e.peakC - SpikeEvent.peakBand) * 10).rounded(.up))
        e.peakSecs = (heat[e.sensor] ?? [:]).reduce(0) { $1.key >= floor ? $0 + $1.value : $0 }
        return e
    }

    private mutating func closed(_ e: SpikeEvent) -> SpikeEvent {
        var done = withPeakTime(e)
        done.ongoing = false
        heat[e.sensor] = nil
        return done
    }

    public var sortedDays: [DayStats] { days.values.sorted { $0.day < $1.day } }

    private mutating func append(_ e: SpikeEvent) {
        spikes.append(e)
        if spikes.count > Self.maxSpikes { spikes.removeFirst(spikes.count - Self.maxSpikes) }
    }
}

// ---- views of the log: UI payload and CSV ----

/// Days and spikes from `from` ("YYYY-MM-DD") on; nil = everything.
public func reportRange(_ log: ReportLog, from: String?, calendar: Calendar = .current) -> (days: [DayStats], spikes: [SpikeEvent]) {
    guard let from = from, !from.isEmpty else { return (log.sortedDays, log.allSpikes) }
    return (log.sortedDays.filter { $0.day >= from }, log.allSpikes.filter { dayKey($0.start, calendar: calendar) >= from })
}

/// What the Reports page reads (window.__native.request("reports.get")).
public func reportDictionary(_ log: ReportLog, price: Double, currency: String, unit: TempUnit) -> [String: Any] {
    [
        "price": price, "currency": currency, "unit": unit == .fahrenheit ? "F" : "C",
        "days": log.sortedDays.map { d -> [String: Any] in
            ["day": d.day, "energyJ": d.energyJ, "seconds": d.seconds, "peakW": d.peakW, "spikes": d.spikes, "maxTempC": d.maxTempC.map { $0 as Any } ?? NSNull()]
        },
        "spikes": log.allSpikes.map { ["start": $0.start, "end": $0.end, "sensor": $0.sensor, "peakC": $0.peakC, "ongoing": $0.ongoing,
                                       "peakAt": $0.peakAt ?? $0.start, "peakSecs": $0.peakSecs ?? 0] as [String: Any] },
    ]
}

/// A CSV field, quoted when it holds a comma, quote or newline.
public func csvField(_ s: String) -> String {
    s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
}

private func csv(_ header: [String], _ rows: [[String]]) -> String {
    ([header] + rows).map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\n") + "\n"
}

/// Cost of `energyJ` joules at `price` per kWh.
public func energyCost(_ energyJ: Double, price: Double) -> Double { energyJ / 3.6e6 * price }

public func daysCSV(_ days: [DayStats], price: Double) -> String {
    csv(["date", "energy_Wh", "avg_W", "peak_W", "hours_measured", "cost", "price_per_kWh", "temp_spikes", "max_temp_C"],
        days.map { d in
            [d.day, String(format: "%.2f", d.energyJ / 3600), d.seconds > 0 ? String(format: "%.1f", d.energyJ / d.seconds) : "",
             String(format: "%.1f", d.peakW), String(format: "%.2f", d.seconds / 3600), String(format: "%.4f", energyCost(d.energyJ, price: price)),
             String(price), String(d.spikes), d.maxTempC.map { String(format: "%.1f", $0) } ?? ""]
        })
}

public func spikesCSV(_ spikes: [SpikeEvent], unit: TempUnit, calendar: Calendar = .current) -> String {
    let f = DateFormatter()
    f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    func stamp(_ ms: Double) -> String { f.string(from: Date(timeIntervalSince1970: ms / 1000)) }
    let f1 = unit == .fahrenheit ? "peak_F" : "peak_C"
    return csv(["start", "end", "sensor", f1, "peak_at", "seconds_near_peak", "duration_s", "ongoing"],
               spikes.map { e in
                   let peak = unit == .fahrenheit ? e.peakC * 9 / 5 + 32 : e.peakC
                   return [stamp(e.start), stamp(e.end), e.sensor, String(format: "%.1f", peak), stamp(e.peakAt ?? e.start), String(Int((e.peakSecs ?? 0).rounded())), String(Int(((e.end - e.start) / 1000).rounded())), e.ongoing ? "yes" : "no"]
               })
}
