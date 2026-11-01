import Foundation

// What the menu-bar item shows. Pure, so the text is covered by CoreChecks; the choice is a setting
// (Preferences.menuBarItems) and the item list in Settings is built from `allCases`.

public enum MenuBarItem: String, CaseIterable {
    case cpuLoad, cpuTemp, gpuLoad, gpuTemp, memory, fan, power, battery

    /// Shown in Settings.
    public var label: String {
        switch self {
        case .cpuLoad: return "CPU load"
        case .cpuTemp: return "CPU temperature"
        case .gpuLoad: return "GPU load"
        case .gpuTemp: return "GPU temperature"
        case .memory: return "Memory used"
        case .fan: return "Fan speed"
        case .power: return "Power (W)"
        case .battery: return "Battery level"
        }
    }

    /// The default: what the menu bar showed before this was a setting.
    public static let defaults: Set<MenuBarItem> = [.cpuLoad, .cpuTemp]

    /// Items from stored strings; unknown ones are ignored.
    public static func set(from raw: [String]) -> Set<MenuBarItem> { Set(raw.compactMap(MenuBarItem.init(rawValue:))) }
}

/// The button text, e.g. " 14%  48°" (and "⚠︎" in front while an alert is active). Fixed order, two spaces between parts;
/// only the icon when nothing is chosen. `error` is shown as " –" while there is no sensor data yet.
public func menuBarTitle(hw: Hardware?, battery: Battery?, items: Set<MenuBarItem>, unit: TempUnit, alerting: Bool, error: String?) -> String {
    guard let hw = hw else { return error == nil ? "" : " –" }
    func degrees(_ c: Double) -> String { formatTemp(c, unit).replacingOccurrences(of: "C", with: "").replacingOccurrences(of: "F", with: "") }
    var parts: [String] = []
    for item in MenuBarItem.allCases where items.contains(item) {
        switch item {
        case .cpuLoad: if let v = hw.cpu { parts.append("\(Int((v * 100).rounded()))%") }
        case .cpuTemp: if let t = hw.cpuTemp { parts.append(degrees(t)) }
        case .gpuLoad: if let v = hw.gpu { parts.append("GPU \(Int((v * 100).rounded()))%") }
        case .gpuTemp: if let t = hw.gpuTemp { parts.append("GPU \(degrees(t))") }
        case .memory: if let used = hw.ramUsed, let total = hw.ramTotal, total > 0 { parts.append("RAM \(Int((used / total * 100).rounded()))%") }
        case .fan: if let rpm = hw.fans.map(\.rpm).max() { parts.append("\(Int(rpm.rounded())) rpm") }
        case .power: if let w = hw.sysPower { parts.append(String(format: "%.0f W", w)) }
        case .battery: if let b = battery { parts.append("Bat \(b.percent)%") }
        }
    }
    return (alerting ? " ⚠︎ " : " ") + parts.joined(separator: "  ")
}
