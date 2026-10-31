import Foundation
import ServiceManagement
import MonitorCore

/// User settings, kept in UserDefaults. `didChange` is posted after any change so the menu bar, the
/// notifier and the app react immediately.
final class Preferences {
    static let shared = Preferences()
    static let didChange = Notification.Name("PreferencesDidChange")
    private let defaults = UserDefaults.standard

    private func flag(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
    private func set(_ value: Any, _ key: String) { defaults.set(value, forKey: key); NotificationCenter.default.post(name: Self.didChange, object: nil) }

    /// Show the live readout in the menu bar.
    var showMenuBar: Bool { get { flag("showMenuBar", true) } set { set(newValue, "showMenuBar") } }
    /// Closing the window keeps the app (and its menu-bar item) running instead of quitting.
    var keepRunning: Bool { get { flag("keepRunning", true) } set { set(newValue, "keepRunning") } }
    /// macOS notifications for alerts (overheating, fan at maximum, memory, battery, disk).
    var notifications: Bool { get { flag("notifications", true) } set { set(newValue, "notifications") } }
    /// 0 = Celsius, 1 = Fahrenheit, 2 = follow the system region. Used by the menu bar and notifications.
    var unitChoice: Int { get { defaults.object(forKey: "unitChoice") as? Int ?? 0 } set { set(newValue, "unitChoice") } }

    /// Seconds between updates (sensors, snapshot, menu bar, window). One of `refreshChoices`.
    static let refreshChoices: [Double] = [0.5, 1, 2, 5]
    var refreshInterval: Double {
        get { let v = defaults.object(forKey: "refreshInterval") as? Double ?? 1; return Self.refreshChoices.contains(v) ? v : 1 }
        set { set(newValue, "refreshInterval") }
    }

    var unit: TempUnit {
        switch unitChoice {
        case 1: return .fahrenheit
        case 2: return Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
        default: return .celsius
        }
    }
}

/// Launch at login through the system's login-item service (macOS 13+). The state lives in macOS, not in
/// UserDefaults, so the checkbox always shows the truth (the user can also change it in System Settings).
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    static var isEnabled: Bool { status == .enabled }
    static var needsApproval: Bool { status == .requiresApproval }

    /// Registers or unregisters the app. Throws when macOS refuses (for example when not running from an .app).
    static func set(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
