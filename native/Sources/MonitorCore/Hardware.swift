import Foundation

// macmon frame -> normalized hardware snapshot, in the shape the web UI reads.
// Missing fields stay nil and a partial frame never crashes.

public struct Core {
    public var id: Int; public var activeRatio: Double; public var freq: Double
    public init(id: Int, activeRatio: Double, freq: Double) { self.id = id; self.activeRatio = activeRatio; self.freq = freq }
}
public struct Cluster {
    public var name: String?; public var cores: [Core]; public var freq: Double; public var load: Double
    public init(name: String?, cores: [Core], freq: Double, load: Double) { self.name = name; self.cores = cores; self.freq = freq; self.load = load }
}
public struct Fan {
    public var name: String?; public var rpm: Double; public var max: Double
    public init(name: String?, rpm: Double, max: Double) { self.name = name; self.rpm = rpm; self.max = max }
}

public struct Hardware {
    public var cpu, gpu, gpuFreq, gpuPower, cpuPower, chipPower, sysPower, cpuTemp, gpuTemp: Double?
    public var ramTotal, ramUsed, swapTotal, swapUsed: Double?
    public var clusters: [Cluster] = []
    public var fans: [Fan] = []
    public init() {}
}

/// Any JSON number-ish value as a finite Double, else nil.
public func number(_ v: Any?) -> Double? {
    let d: Double?
    switch v {
    case let n as NSNumber: d = n.doubleValue
    case let s as String: d = Double(s)
    default: d = nil
    }
    guard let x = d, x.isFinite else { return nil }
    return x
}

private func cluster(_ cores: Any?, _ freq: Any?, _ name: String?) -> Cluster {
    let list = (cores as? [[String: Any]] ?? []).enumerated().map { i, c in
        Core(id: Int(number(c["core_id"]) ?? Double(i)), activeRatio: number(c["active_ratio"]) ?? 0, freq: number(c["freq_mhz"]) ?? 0)
    }
    let load = list.isEmpty ? 0 : list.reduce(0) { $0 + $1.activeRatio } / Double(list.count)
    return Cluster(name: name, cores: list, freq: number(freq) ?? 0, load: load)
}

/// `tierNames` name the clusters in order (performance, then efficiency).
public func parseHardware(_ frame: [String: Any], tierNames: [String] = []) -> Hardware {
    var hw = Hardware()
    hw.cpu = number(frame["cpu_active_ratio"])
    hw.gpu = number(frame["gpu_active_ratio"])
    hw.gpuFreq = number(frame["gpu_freq_mhz"])
    hw.gpuPower = number(frame["gpu_power"])
    hw.cpuPower = number(frame["cpu_power"])
    hw.chipPower = number(frame["all_power"])
    hw.sysPower = number(frame["sys_power"])
    let temp = frame["temp"] as? [String: Any]
    hw.cpuTemp = number(temp?["cpu_temp_avg"])
    hw.gpuTemp = number(temp?["gpu_temp_avg"])
    if let m = frame["memory"] as? [String: Any] {
        hw.ramTotal = number(m["ram_total"]); hw.ramUsed = number(m["ram_usage"])
        hw.swapTotal = number(m["swap_total"]); hw.swapUsed = number(m["swap_usage"])
    }
    hw.clusters = [
        cluster(frame["pcpu_cores"], frame["pcpu_freq_mhz"], tierNames.indices.contains(0) ? tierNames[0] : nil),
        cluster(frame["ecpu_cores"], frame["ecpu_freq_mhz"], tierNames.indices.contains(1) ? tierNames[1] : nil),
    ]
    hw.fans = (frame["fans"] as? [[String: Any]] ?? []).map {
        Fan(name: $0["name"] as? String, rpm: number($0["rpm"]) ?? 0, max: number($0["max_rpm"]) ?? 0)
    }
    return hw
}

/// Complete top-level JSON objects from a byte stream, tolerant of pretty-printed or
/// newline-delimited output. Returns the objects and the unfinished remainder.
public func extractObjects(_ buffer: String) -> (objects: [String], rest: String) {
    var out: [String] = []
    var depth = 0, inStr = false, esc = false
    var start: String.Index?
    var i = buffer.startIndex
    while i < buffer.endIndex {
        let c = buffer[i]
        if inStr {
            if esc { esc = false } else if c == "\\" { esc = true } else if c == "\"" { inStr = false }
        } else if c == "\"" {
            inStr = true
        } else if c == "{" {
            if depth == 0 { start = i }
            depth += 1
        } else if c == "}" {
            depth -= 1
            if depth == 0, let s = start { out.append(String(buffer[s...i])); start = nil }
        }
        i = buffer.index(after: i)
    }
    return (out, start.map { String(buffer[$0...]) } ?? "")
}
