import Foundation
import MonitorCore

// Unit checks for MonitorCore: macmon frame parsing, host-metric parsers, snapshot and alert rules.
// Run: swift run CoreChecks   (exits 1 on any failure)

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    print("\(ok ? "✔" : "✖") \(name)\(ok ? "" : "  -> \(detail())")")
    if !ok { failures += 1 }
}
func near(_ a: Double?, _ b: Double, _ eps: Double = 1e-9) -> Bool { a.map { abs($0 - b) < eps } ?? false }

// ---- parseHardware ----
let frame: [String: Any] = [
    "cpu_active_ratio": 0.1, "pcpu_freq_mhz": 2948,
    "pcpu_cores": [["active_ratio": 0.1, "core_id": 0, "freq_mhz": 2776], ["active_ratio": 0.2, "core_id": 1, "freq_mhz": 2912]],
    "ecpu_freq_mhz": 1344,
    "ecpu_cores": [["active_ratio": 0.0, "core_id": 4, "freq_mhz": 0], ["active_ratio": 0.3, "core_id": 10, "freq_mhz": 1618]],
    "gpu_active_ratio": 0.36, "gpu_freq_mhz": 651, "gpu_power": 0.6, "cpu_power": 1.4, "all_power": 2.1, "sys_power": 5.2,
    "temp": ["cpu_temp_avg": 41.5, "gpu_temp_avg": 40.2],
    "memory": ["ram_total": 68719476736, "ram_usage": 35000000000, "swap_total": 4294967296, "swap_usage": 100],
    "fans": [["name": "fan0", "rpm": 1800, "max_rpm": 7826]],
]
let hw = parseHardware(frame, tierNames: ["Performance", "Efficiency"])
check("maps utilization, power and temperatures", near(hw.cpu, 0.1) && near(hw.gpuFreq, 651) && near(hw.sysPower, 5.2) && near(hw.cpuPower, 1.4) && near(hw.chipPower, 2.1) && near(hw.cpuTemp, 41.5))
check("maps memory and swap bytes", near(hw.ramTotal, 68719476736) && near(hw.swapUsed, 100))
check("builds clusters with mean load and names", hw.clusters.count == 2 && hw.clusters[0].name == "Performance" && near(hw.clusters[0].load, 0.15) && near(hw.clusters[1].load, 0.15) && hw.clusters[1].cores[1].id == 10)
check("reshapes fans to name/rpm/max", hw.fans.count == 1 && hw.fans[0].rpm == 1800 && hw.fans[0].max == 7826)
let empty = parseHardware([:])
check("tolerates an empty frame", empty.cpu == nil && empty.clusters.count == 2 && empty.clusters[0].cores.isEmpty && empty.clusters[0].load == 0 && empty.fans.isEmpty)
check("ignores non-finite and non-numeric values", parseHardware(["cpu_active_ratio": "abc", "gpu_power": Double.nan]).cpu == nil)

// ---- extractObjects ----
let (objs, rest) = extractObjects("{\"a\":1}\n{\"b\":\"}\"}\n{\"c\":{\"d\":2")
check("extractObjects finds complete objects, handles braces in strings, keeps the rest", objs == ["{\"a\":1}", "{\"b\":\"}\"}"] && rest == "{\"c\":{\"d\":2", "\(objs) | \(rest)")

// ---- system parsers ----
let procs = parseProcesses("""
  615  39.1 311280 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
39561   8.4 2297344 /Applications/Brave Browser.app/Contents/MacOS/Brave Browser Helper (Renderer)
garbage line
""")
check("parseProcesses reads pid, cpu, rss bytes and executable name", procs.count == 2 && procs[0].name == "WindowServer" && procs[0].rss == 311280 * 1024 && procs[1].name == "Brave Browser Helper (Renderer)", "\(procs)")
check("topBy sorts descending and limits", topBy([Proc(pid: 1, cpu: 1, rss: 0, name: "a"), Proc(pid: 2, cpu: 9, rss: 0, name: "b"), Proc(pid: 3, cpu: 5, rss: 0, name: "c")], { $0.cpu }, count: 2).map(\.pid) == [2, 3])

let ac = parseBattery("Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t80%; AC attached; not charging present: true", ac: " Wattage = 65W\n")
check("parseBattery on AC, not charging", ac?.percent == 80 && ac?.onBattery == false && ac?.state == "not charging" && ac?.adapterW == 65 && ac?.remaining == nil, "\(String(describing: ac))")
let dis = parseBattery("Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t55%; discharging; 3:41 remaining present: true")
check("parseBattery discharging with time left", dis?.percent == 55 && dis?.onBattery == true && dis?.remaining == "3:41" && dis?.adapterW == nil, "\(String(describing: dis))")
check("parseBattery charging; no battery -> nil", parseBattery("Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t40%; charging; 1:10 remaining present: true")?.charging == true && parseBattery("Now drawing from 'AC Power'\n") == nil && parseBattery("") == nil)
let chargeIO = "  | |   \"Amperage\" = 1500\n  | |   \"Voltage\" = 12900\n"
let drainIO = "  | |   \"Amperage\" = 18446744073709550116\n  | |   \"Voltage\" = 12000\n"   // -1500 mA as ioreg prints it
check("parseBatteryPower: charging +, discharging -, missing -> nil", abs((parseBatteryPower(chargeIO) ?? 0) - 19.35) < 0.001 && abs((parseBatteryPower(drainIO) ?? 0) + 18.0) < 0.001 && parseBatteryPower("") == nil)
check("parseBattery carries battery watts", parseBattery("Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t55%; discharging; 3:41 remaining present: true", power: drainIO)?.batteryW != nil && ac?.batteryW == nil)
let profiler = #"{"SPHardwareDataType":[{"machine_name":"MacBook Pro","machine_model":"Mac17,7","chip_type":"Apple M5 Pro","physical_memory":"64 GB"}],"SPDisplaysDataType":[{"sppci_cores":"20"}]}"#
let mach = parseMachine(profiler: profiler, os: "26.1", tiers: [Tier(name: "Super", cores: 6), Tier(name: "Performance", cores: 12)])
check("parseMachine reads chip, model, memory, GPU cores, tiers", mach.chip == "Apple M5 Pro" && mach.name == "MacBook Pro" && mach.model == "Mac17,7" && mach.memory == "64 GB" && mach.gpuCores == 20 && mach.os == "26.1" && mach.tiers.map(\.cores) == [6, 12])
check("parseMachine survives garbage", parseMachine(profiler: "nope", os: "", tiers: []).chip == nil)

let d = parseDisk("Filesystem 1024-blocks Used Available Capacity iused ifree %iused Mounted on\n/dev/disk3s5 1948404040 636512180 1281897480 34% 1 2 0% /System/Volumes/Data")
check("parseDisk total and free bytes", d?.total == 1948404040 * 1024 && d?.free == 1281897480 * 1024 && parseDisk("") == nil)

check("rate gives bytes/second and rejects bad input", rate(1000, 3000, dtMs: 1000) == 2000 && rate(1000, 2000, dtMs: 500) == 2000 && rate(3000, 1000, dtMs: 1000) == nil && rate(nil, 5, dtMs: 1000) == nil)

// ---- snapshot ----
var sys = SystemSample()
sys.netIn = 1000; sys.battery = ac; sys.procs = procs; sys.machine = mach
let pt = historyPoint(hw: hw, sys: sys, ts: 1)
let snap = snapshotDictionary(hw: hw, sys: sys, error: nil, sensorTs: 5, ts: 6, uptime: 3, point: pt)
let json = jsonString(snap)
check("snapshot reports the refresh interval", (snap["intervalMs"] as? Int) == 1000 && (snapshotDictionary(hw: hw, sys: sys, error: nil, sensorTs: 5, ts: 6, uptime: 3, point: pt, intervalMs: 500)["intervalMs"] as? Int) == 500)
check("snapshot carries the temperature unit", (snap["unit"] as? String) == "C" && (snapshotDictionary(hw: hw, sys: sys, error: nil, sensorTs: 5, ts: 6, uptime: 3, point: pt, unit: .fahrenheit)["unit"] as? String) == "F")
let back = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
check("snapshot has the keys the UI reads", ["cpu", "clusters", "fans", "procs", "battery", "disk", "net", "diskIO", "source", "sensorTs", "ts", "uptime", "intervalMs", "unit", "machine", "point"].allSatisfy { back[$0] != nil }, "\(back.keys.sorted())")
check("snapshot round-trips as JSON with null for missing values", (back["disk"] is NSNull) && ((back["point"] as? [String: Any])?["diskR"] is NSNull) && ((back["net"] as? [String: Any])?["in"] as? Double) == 1000)
let err = snapshotDictionary(hw: nil, sys: SystemSample(), error: "macmon not found", sensorTs: nil, ts: 6, uptime: 0, point: nil)
check("without hardware the snapshot carries an error and no cpu", (err["error"] as? String) == "macmon not found" && err["cpu"] == nil)

// ---- alerts ----
func ids(_ a: [Alert]) -> [String] { a.map(\.id) }
var calm = Hardware(); calm.cpuTemp = 60; calm.gpuTemp = 55; calm.ramTotal = 100; calm.ramUsed = 50; calm.fans = [Fan(name: nil, rpm: 2000, max: 7000)]
check("no alerts for a calm system or no data", evaluateAlerts(hw: calm, sys: SystemSample(), unit: .celsius).isEmpty && evaluateAlerts(hw: nil, sys: SystemSample(), unit: .celsius).isEmpty)
var hot = Hardware(); hot.cpuTemp = 89.9; hot.gpuTemp = 90
check("temperature alerts start at 90 °C", ids(evaluateAlerts(hw: hot, sys: SystemSample(), unit: .celsius)) == ["gpu-temp"])
hot.cpuTemp = 100
let tempAlerts = evaluateAlerts(hw: hot, sys: SystemSample(), unit: .celsius)
check("temperature is critical from 100 °C, warning below", tempAlerts.first { $0.id == "cpu-temp" }?.level == .critical && tempAlerts.first { $0.id == "gpu-temp" }?.level == .warning)
hot.cpuTemp = 95
check("alert text follows the unit", evaluateAlerts(hw: hot, sys: SystemSample(), unit: .fahrenheit).first?.text == "CPU is hot: 203°F" && evaluateAlerts(hw: hot, sys: SystemSample(), unit: .celsius).first?.text == "CPU is hot: 95°C")
var fans = Hardware(); fans.fans = [Fan(name: nil, rpm: 6700, max: 7000), Fan(name: nil, rpm: 100, max: 7000), Fan(name: nil, rpm: 9999, max: 0)]
check("fan at >= 95% of max alerts; max 0 ignored", ids(evaluateAlerts(hw: fans, sys: SystemSample(), unit: .celsius)) == ["fan-0"])
var mem = Hardware(); mem.ramTotal = 100; mem.ramUsed = 90
check("memory alert at 90%, critical at 95%", ids(evaluateAlerts(hw: mem, sys: SystemSample(), unit: .celsius)) == ["mem"] && { mem.ramUsed = 96; return evaluateAlerts(hw: mem, sys: SystemSample(), unit: .celsius).first?.level == .critical }())
var lowBat = SystemSample(); lowBat.battery = Battery(percent: 8, onBattery: true, charging: false, state: "discharging", remaining: nil, adapterW: nil)
var acBat = SystemSample(); acBat.battery = Battery(percent: 3, onBattery: false, charging: false, state: "not charging", remaining: nil, adapterW: 65)
var fullDisk = SystemSample(); fullDisk.disk = Disk(total: 100, free: 9)
var okDisk = SystemSample(); okDisk.disk = Disk(total: 100, free: 50)
check("battery alert only on battery; disk alert at <= 10% free", ids(evaluateAlerts(hw: nil, sys: lowBat, unit: .celsius)) == ["battery"] && evaluateAlerts(hw: nil, sys: acBat, unit: .celsius).isEmpty && ids(evaluateAlerts(hw: nil, sys: fullDisk, unit: .celsius)) == ["disk"] && evaluateAlerts(hw: nil, sys: okDisk, unit: .celsius).isEmpty)
check("formatTemp rounds and converts", formatTemp(63.4, .celsius) == "63°C" && formatTemp(100, .fahrenheit) == "212°F" && formatTemp(0, .fahrenheit) == "32°F" && formatTemp(nil, .celsius) == "–")
var tracker = AlertTracker()
let a1 = Alert(id: "mem", level: .warning, text: "m"), a2 = Alert(id: "disk", level: .warning, text: "d")
let n1 = tracker.update([a1]), n2 = tracker.update([a1]), n3 = tracker.update([a1, a2]), n4 = tracker.update([]), n5 = tracker.update([a1])
check("AlertTracker reports an alert once, again after it clears", n1 == [a1] && n2.isEmpty && n3 == [a2] && n4.isEmpty && n5 == [a1])

// ---- reports ----
var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
let t0 = 1_767_225_600_000.0   // 2026-01-01 00:00:00 UTC
func sample(_ cpu: Double?, _ gpu: Double?, _ w: Double?) -> Hardware { var h = Hardware(); h.cpuTemp = cpu; h.gpuTemp = gpu; h.sysPower = w; return h }
var log = ReportLog()
log.record(sample(60, 50, 20), at: t0, dt: 0, calendar: utc)
log.record(sample(61, 50, 30), at: t0 + 1000, dt: 1, calendar: utc)
log.record(sample(62, 50, 10), at: t0 + 2000, dt: 1, calendar: utc)
let d1 = log.days["2026-01-01"]
check("report day sums power x time, peak and max temperature", near(d1?.energyJ, 40) && near(d1?.seconds, 2) && near(d1?.peakW, 30) && near(d1?.maxTempC, 62), "\(String(describing: d1))")
log.record(sample(60, 50, 10), at: t0 + 3000, dt: 3600, calendar: utc)
check("a long gap (sleep) counts at most maxGap seconds", near(log.days["2026-01-01"]?.seconds, 2 + ReportLog.maxGap))
log.record(sample(60, 50, nil), at: t0 + 4000, dt: 1, calendar: utc)
check("a tick without power adds no energy", near(log.days["2026-01-01"]?.seconds, 2 + ReportLog.maxGap))
log.record(sample(60, 50, 10), at: t0 + 86_400_000, dt: 1, calendar: utc)
check("days are split at local midnight", log.days.count == 2 && log.sortedDays.map(\.day) == ["2026-01-01", "2026-01-02"])

var glitch = ReportLog()
glitch.record(sample(60, 50, 5724.6), at: t0, dt: 1, calendar: utc)
glitch.record(sample(60, 50, 12), at: t0 + 1000, dt: 0, calendar: utc)
glitch.record(sample(60, 50, 20), at: t0 + 2000, dt: 1, calendar: utc)
check("implausible power and ticks without time are ignored for energy and peak", near(glitch.days["2026-01-01"]?.peakW, 20) && near(glitch.days["2026-01-01"]?.energyJ, 20) && near(glitch.days["2026-01-01"]?.seconds, 1), "\(String(describing: glitch.days["2026-01-01"]))")

var sp = ReportLog()
check("spike opens at the alert threshold (not below)", !sp.record(sample(Limits.temp - 0.1, 50, 5), at: t0, dt: 1, calendar: utc) && sp.allSpikes.isEmpty)
check("spike start is reported", sp.record(sample(Limits.temp, 50, 5), at: t0 + 1000, dt: 1, calendar: utc) && sp.allSpikes.count == 1 && sp.allSpikes[0].ongoing && sp.spikes.isEmpty)
sp.record(sample(97, 91, 5), at: t0 + 2000, dt: 1, calendar: utc)
sp.record(sample(93, 91, 5), at: t0 + 3000, dt: 1, calendar: utc)
check("one episode per sensor tracks its peak", sp.allSpikes.count == 2 && sp.allSpikes.first { $0.sensor == "CPU" }?.peakC == 97 && sp.days["2026-01-01"]?.spikes == 2)
check("spike end is reported and the event is stored", sp.record(sample(80, 91, 5), at: t0 + 4000, dt: 1, calendar: utc) && sp.spikes.count == 1
      && sp.spikes[0].sensor == "CPU" && near(sp.spikes[0].start, t0 + 1000) && near(sp.spikes[0].end, t0 + 3000) && !sp.spikes[0].ongoing)
sp.finish()
check("finish closes episodes still open", sp.spikes.count == 2 && sp.allSpikes.allSatisfy { !$0.ongoing })
sp.record(sample(95, nil, 5), at: t0 + 5000, dt: 1, calendar: utc)
check("a new episode after a finished one counts again", sp.days["2026-01-01"]?.spikes == 3)
let reloaded = try? JSONDecoder().decode(ReportLog.self, from: JSONEncoder().encode(sp))
check("the log survives a JSON round trip (open episodes are not saved)", reloaded?.days == sp.days && reloaded?.spikes == sp.spikes && reloaded?.allSpikes.count == 2)
var pk = ReportLog()
for (i, t) in [91.0, 95, 95.4, 94.8, 93, 95.2, 80].enumerated() { pk.record(sample(t, nil, 5), at: t0 + Double(i) * 1000, dt: 1, calendar: utc) }
check("spike keeps when the peak was reached and how long it stayed within 1 °C of it", pk.spikes.count == 1 && near(pk.spikes[0].peakC, 95.4) && near(pk.spikes[0].peakAt, t0 + 2000) && near(pk.spikes[0].peakSecs, 4), "\(pk.spikes)")
let oldSpike = try? JSONDecoder().decode(SpikeEvent.self, from: Data(#"{"start":1,"end":2,"sensor":"CPU","peakC":91,"ongoing":false}"#.utf8))
check("spikes saved before peak times existed still load (readers fall back to the start)", oldSpike != nil && oldSpike?.peakAt == nil && oldSpike?.peakSecs == nil && spikesCSV([oldSpike!], unit: .celsius, calendar: utc).contains(",1970-01-01 00:00:00,0,"))
var climb = ReportLog()
var climbTemps = Array(repeating: 94.0, count: 10) + [94.9, 95.8, 50]
for (i, t) in climbTemps.enumerated() { climb.record(sample(t, nil, 5), at: t0 + Double(i) * 1000, dt: 1, calendar: utc) }
check("a slow climb does not count the time spent far below the final peak", climb.spikes.count == 1 && near(climb.spikes[0].peakC, 95.8) && near(climb.spikes[0].peakSecs, 2), "\(climb.spikes)")
var many = ReportLog()
for i in 0..<(ReportLog.maxSpikes + 5) {
    many.record(sample(95, nil, 5), at: t0 + Double(i) * 2000, dt: 1, calendar: utc)
    many.record(sample(50, nil, 5), at: t0 + Double(i) * 2000 + 1000, dt: 1, calendar: utc)
}
check("only the newest maxSpikes are kept", many.spikes.count == ReportLog.maxSpikes && near(many.spikes[0].start, t0 + 5 * 2000))
check("range filter keeps days and spikes from the given day", reportRange(sp, from: "2026-01-02", calendar: utc).days.isEmpty && reportRange(sp, from: "2026-01-02", calendar: utc).spikes.isEmpty
      && reportRange(sp, from: nil, calendar: utc).days.count == 1 && reportRange(sp, from: "2026-01-01", calendar: utc).spikes.count == 3)
check("energy cost: 1 kWh at 0.25 = 0.25", near(energyCost(3.6e6, price: 0.25), 0.25))
let dc = daysCSV(log.sortedDays, price: 0.2).split(separator: "\n").map(String.init)
check("days CSV has a header and one row per day", dc.count == 3 && dc[0].hasPrefix("date,energy_Wh,avg_W") && dc[1].hasPrefix("2026-01-01,"), "\(dc)")
let sc = spikesCSV(sp.allSpikes, unit: .fahrenheit, calendar: utc).split(separator: "\n").map(String.init)
check("spikes CSV converts to the unit and formats times", sc.count == 4 && sc[0] == "start,end,sensor,peak_F,peak_at,seconds_near_peak,duration_s,ongoing" && sc[1].hasPrefix("2026-01-01 00:00:01,2026-01-01 00:00:03,CPU,206.6,2026-01-01 00:00:02,1,2,no"), "\(sc)")
check("CSV fields with commas, quotes or newlines are quoted", csvField("a,b") == "\"a,b\"" && csvField("say \"hi\"") == "\"say \"\"hi\"\"\"" && csvField("x\ny") == "\"x\ny\"" && csvField("plain") == "plain")
let rd = reportDictionary(log, price: 0.2, currency: "$", unit: .celsius)
let rdBack = (try? JSONSerialization.jsonObject(with: Data(jsonString(rd).utf8))) as? [String: Any]
check("report payload has price, unit, days and spikes", rdBack?["unit"] as? String == "C" && rdBack?["price"] as? Double == 0.2 && (rdBack?["days"] as? [Any])?.count == 2 && (rdBack?["spikes"] as? [Any])?.isEmpty == true)

// ---- menu-bar title ----
var mb = Hardware(); mb.cpu = 0.12; mb.cpuTemp = 54.4; mb.gpu = 0.39; mb.gpuTemp = 53; mb.ramUsed = 46; mb.ramTotal = 100; mb.sysPower = 15.2
mb.fans = [Fan(name: nil, rpm: 2319, max: 7000), Fan(name: nil, rpm: 2503.4, max: 7000)]
let mbBat = Battery(percent: 80, onBattery: false, charging: false, state: "not charging", remaining: nil, adapterW: 65)
func mbTitle(_ items: Set<MenuBarItem>, hw: Hardware? = mb, unit: TempUnit = .celsius, alerting: Bool = false, error: String? = nil) -> String {
    menuBarTitle(hw: hw, battery: mbBat, items: items, unit: unit, alerting: alerting, error: error)
}
check("default menu-bar title is CPU load and temperature (as before)", MenuBarItem.defaults == [.cpuLoad, .cpuTemp] && mbTitle(MenuBarItem.defaults) == " 12%  54°", mbTitle(MenuBarItem.defaults))
check("every item formats its value", mbTitle([.gpuLoad]) == " GPU 39%" && mbTitle([.gpuTemp]) == " GPU 53°" && mbTitle([.memory]) == " RAM 46%" && mbTitle([.fan]) == " 2503 rpm" && mbTitle([.power]) == " 15 W" && mbTitle([.battery]) == " Bat 80%")
check("parts come in a fixed order whatever the selection", mbTitle(Set(MenuBarItem.allCases)) == " 12%  54°  GPU 39%  GPU 53°  RAM 46%  2503 rpm  15 W  Bat 80%", mbTitle(Set(MenuBarItem.allCases)))
check("menu-bar temperature follows the unit", mbTitle([.cpuTemp], unit: .fahrenheit) == " 130°")
check("alert prefix, empty selection and missing data", mbTitle([.cpuLoad], alerting: true) == " ⚠︎ 12%" && mbTitle([]) == " " && mbTitle([.cpuLoad], hw: nil) == "" && mbTitle([.cpuLoad], hw: nil, error: "x") == " –" && mbTitle([.fan], hw: Hardware()) == " " && mbTitle([.battery], hw: Hardware()) == " Bat 80%")
check("stored item names map back, unknown names are ignored", MenuBarItem.set(from: ["cpuLoad", "fan", "nope"]) == [.cpuLoad, .fan] && MenuBarItem.set(from: []).isEmpty)

print(failures == 0 ? "\nALL CHECKS PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
