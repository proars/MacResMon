import Foundation

// Builds the JSON the web UI (src/) consumes: one snapshot per tick plus the rolling history samples.
// The shape is the contract with src/useStream.js and the cards; change both sides together.

public struct SystemSample {
    public var procs: [Proc] = []
    public var battery: Battery?
    public var disk: Disk?
    public var netIn, netOut, diskRead, diskWrite: Double?
    public init() {}
}

private func procJSON(_ p: Proc) -> [String: Any] { ["pid": p.pid, "name": p.name, "cpu": p.cpu, "rss": p.rss] }
private let null = NSNull()
private func orNull(_ v: Double?) -> Any { v ?? null }

private func fanJSON(_ f: Fan) -> [String: Any] { ["name": f.name ?? null, "rpm": f.rpm, "max": f.max] }

/// One rolling-history sample (what the graphs read). Missing values are null.
public func historyPoint(hw: Hardware, sys: SystemSample, ts: Int64) -> [String: Any] {
    [
        "ts": ts, "cpu": orNull(hw.cpu), "gpu": orNull(hw.gpu), "power": orNull(hw.sysPower), "ram": orNull(hw.ramUsed),
        "netIn": orNull(sys.netIn), "netOut": orNull(sys.netOut), "diskR": orNull(sys.diskRead), "diskW": orNull(sys.diskWrite),
        "cpuTemp": orNull(hw.cpuTemp), "gpuTemp": orNull(hw.gpuTemp), "fans": hw.fans.map(fanJSON),
    ]
}

/// The per-tick snapshot. Without hardware data it carries an `error` string and the UI shows a placeholder.
public func snapshotDictionary(hw: Hardware?, sys: SystemSample, error: String?, sensorTs: Int64?, ts: Int64, uptime: Int, point: [String: Any]?, intervalMs: Int = 1000) -> [String: Any] {
    var s: [String: Any] = [:]
    if let hw = hw {
        for (k, v) in [("cpu", hw.cpu), ("gpu", hw.gpu), ("gpuFreq", hw.gpuFreq), ("gpuPower", hw.gpuPower), ("cpuPower", hw.cpuPower), ("chipPower", hw.chipPower),
                       ("sysPower", hw.sysPower),
                       ("cpuTemp", hw.cpuTemp), ("gpuTemp", hw.gpuTemp), ("ramTotal", hw.ramTotal), ("ramUsed", hw.ramUsed),
                       ("swapTotal", hw.swapTotal), ("swapUsed", hw.swapUsed)] {
            if let v = v { s[k] = v }
        }
        s["clusters"] = hw.clusters.map { c in
            ["name": c.name ?? null, "freq": c.freq, "load": c.load,
             "cores": c.cores.map { ["id": $0.id, "activeRatio": $0.activeRatio, "freq": $0.freq] }] as [String: Any]
        }
        s["fans"] = hw.fans.map(fanJSON)
    } else {
        s["error"] = error ?? "macmon not connected yet"
    }
    s["procs"] = ["cpu": topBy(sys.procs, { $0.cpu }).map(procJSON), "mem": topBy(sys.procs, { $0.rss }).map(procJSON)]
    s["battery"] = sys.battery.map { b in
        ["percent": b.percent, "onBattery": b.onBattery, "charging": b.charging, "state": b.state,
         "remaining": b.remaining ?? null, "adapterW": b.adapterW ?? null] as [String: Any]
    } ?? null
    s["disk"] = sys.disk.map { ["total": $0.total, "free": $0.free] as [String: Any] } ?? null
    s["net"] = ["in": orNull(sys.netIn), "out": orNull(sys.netOut)]
    s["diskIO"] = ["read": orNull(sys.diskRead), "write": orNull(sys.diskWrite)]
    s["source"] = "macmon"
    s["sensorTs"] = sensorTs.map { $0 as Any } ?? null
    s["ts"] = ts
    s["uptime"] = uptime
    s["intervalMs"] = intervalMs
    s["point"] = point ?? null
    return s
}

/// Compact JSON text of a dictionary (valid JavaScript too, so it can be passed to the web view directly).
public func jsonString(_ object: Any) -> String {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object),
          let text = String(data: data, encoding: .utf8) else { return "null" }
    return text
}
