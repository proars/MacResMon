import Foundation

// Alert rules: a port of src/alerts.js (same thresholds and texts), used for native notifications and
// the menu-bar item. Pure, so it is covered by CoreChecks.

public enum TempUnit { case celsius, fahrenheit }

public struct Alert: Equatable {
    public enum Level: String { case warning, critical }
    public var id: String
    public var level: Level
    public var text: String
    public init(id: String, level: Level, text: String) { self.id = id; self.level = level; self.text = text }
}

public enum Limits {
    public static let temp = 90.0, tempCritical = 100.0
    public static let fan = 0.95
    public static let mem = 0.9, memCritical = 0.95
    public static let battery = 10, batteryCritical = 5
    public static let diskFree = 0.1
}

/// "63°C" / "145°F" (rounded); "–" when unknown.
public func formatTemp(_ celsius: Double?, _ unit: TempUnit) -> String {
    guard let c = celsius, c.isFinite else { return "–" }
    switch unit {
    case .celsius: return "\(Int(c.rounded()))°C"
    case .fahrenheit: return "\(Int((c * 9 / 5 + 32).rounded()))°F"
    }
}

private func percentText(_ ratio: Double) -> String { "\(Int((ratio * 100).rounded()))%" }

/// Active alerts for the current readings. `id` stays the same while a condition lasts.
public func evaluateAlerts(hw: Hardware?, sys: SystemSample, unit: TempUnit) -> [Alert] {
    var out: [Alert] = []
    if let hw = hw {
        for (id, label, t) in [("cpu-temp", "CPU", hw.cpuTemp), ("gpu-temp", "GPU", hw.gpuTemp)] {
            if let t = t, t >= Limits.temp {
                out.append(Alert(id: id, level: t >= Limits.tempCritical ? .critical : .warning, text: "\(label) is hot: \(formatTemp(t, unit))"))
            }
        }
        for (i, f) in hw.fans.enumerated() where f.max > 0 && f.rpm / f.max >= Limits.fan {
            out.append(Alert(id: "fan-\(i)", level: .warning, text: "Fan \(i + 1) is at its maximum (\(Int(f.rpm.rounded())) rpm)"))
        }
        if let total = hw.ramTotal, total > 0, let used = hw.ramUsed {
            let r = used / total
            if r >= Limits.mem { out.append(Alert(id: "mem", level: r >= Limits.memCritical ? .critical : .warning, text: "Memory is \(percentText(r)) full")) }
        }
    }
    if let b = sys.battery, b.onBattery, b.percent <= Limits.battery {
        out.append(Alert(id: "battery", level: b.percent <= Limits.batteryCritical ? .critical : .warning, text: "Battery is low: \(b.percent)%"))
    }
    if let d = sys.disk, d.total > 0, d.free / d.total <= Limits.diskFree {
        out.append(Alert(id: "disk", level: .warning, text: "Disk is almost full: \(percentText(d.free / d.total)) free"))
    }
    return out
}

/// Remembers which alerts are active so a notification fires once when one appears, not every tick.
public struct AlertTracker {
    private var active = Set<String>()
    public init() {}
    /// Returns the alerts that are new since the last call.
    public mutating func update(_ alerts: [Alert]) -> [Alert] {
        let fresh = alerts.filter { !active.contains($0.id) }
        active = Set(alerts.map(\.id))
        return fresh
    }
}
