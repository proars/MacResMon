import Foundation

// Host metrics that macmon does not provide. Pure parsers over the output of macOS commands;
// the app runs the commands and feeds the text in. Network and disk
// counters are read directly by the app (Counters.swift) instead.

public struct Proc {
    public var pid: Int; public var cpu: Double; public var rss: Double; public var name: String
    public init(pid: Int, cpu: Double, rss: Double, name: String) { self.pid = pid; self.cpu = cpu; self.rss = rss; self.name = name }
}
public struct Battery {
    public var percent: Int, onBattery: Bool, charging: Bool
    public var state: String, remaining: String?, adapterW: Int?
    public init(percent: Int, onBattery: Bool, charging: Bool, state: String, remaining: String?, adapterW: Int?) {
        self.percent = percent; self.onBattery = onBattery; self.charging = charging; self.state = state; self.remaining = remaining; self.adapterW = adapterW
    }
}
public struct Disk {
    public var total: Double; public var free: Double
    public init(total: Double, free: Double) { self.total = total; self.free = free }
}

/// `ps -Ao pid=,pcpu=,rss=,comm=` -> processes (rss in bytes, name = executable name).
public func parseProcesses(_ text: String) -> [Proc] {
    var out: [Proc] = []
    for line in text.split(separator: "\n") {
        let f = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard f.count == 4, let pid = Int(f[0]), let cpu = Double(f[1]), let rss = Double(f[2]) else { continue }
        let path = f[3].trimmingCharacters(in: .whitespaces)
        out.append(Proc(pid: pid, cpu: cpu, rss: rss * 1024, name: path.split(separator: "/").last.map(String.init) ?? path))
    }
    return out
}

public func topBy(_ procs: [Proc], _ key: (Proc) -> Double, count: Int = 5) -> [Proc] {
    Array(procs.sorted { key($0) > key($1) }.prefix(count))
}

/// `pmset -g batt` (+ `pmset -g ac` for adapter watts) -> battery, or nil on a Mac without one.
public func parseBattery(_ batt: String, ac: String = "") -> Battery? {
    guard let line = batt.split(separator: "\n").first(where: { $0.contains("InternalBattery") }) else { return nil }
    var text = String(line)
    if let r = text.range(of: #"\s+present:.*$"#, options: .regularExpression) { text.removeSubrange(r) }
    let fields = (text.split(separator: "\t").last.map(String.init) ?? text)
        .split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
    guard let first = fields.first, first.hasSuffix("%"), let percent = Int(first.dropLast()) else { return nil }
    let onBattery = batt.contains("Now drawing from 'Battery Power'")
    let state = ["discharging", "finishing charge", "not charging", "charging", "charged"].first { fields.contains($0) } ?? "unknown"
    var remaining: String?
    for f in fields.dropFirst() {
        if let r = f.range(of: #"^\d+:\d+(?= remaining)"#, options: .regularExpression), String(f[r]) != "0:00" { remaining = String(f[r]) }
    }
    var adapter: Int?
    if !onBattery, let r = ac.range(of: #"Wattage\s*=\s*(\d+)\s*W"#, options: [.regularExpression, .caseInsensitive]) {
        adapter = Int(ac[r].filter(\.isNumber))
    }
    return Battery(percent: percent, onBattery: onBattery, charging: state == "charging", state: state, remaining: remaining, adapterW: adapter)
}

/// `df -k <path>` -> total and free bytes.
public func parseDisk(_ text: String) -> Disk? {
    let lines = text.split(separator: "\n")
    guard lines.count >= 2 else { return nil }
    let f = lines[1].split(separator: " ", omittingEmptySubsequences: true)
    guard f.count >= 4, let total = Double(f[1]), let free = Double(f[3]), total > 0 else { return nil }
    return Disk(total: total * 1024, free: free * 1024)
}

/// Bytes/second between two cumulative samples; nil if a counter went backwards.
public func rate(_ prev: Double?, _ cur: Double?, dtMs: Double) -> Double? {
    guard let p = prev, let c = cur, dtMs > 0, c >= p else { return nil }
    return (c - p) / dtMs * 1000
}
