import Foundation
import UserNotifications
import MonitorCore

/// macOS notifications. They only work from a real .app bundle (not from `swift run`), and the user must
/// allow them once; the permission prompt appears the first time we need it.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private var tracker = AlertTracker()

    var available: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    func start() {
        guard available else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// Called every tick with the active alerts; notifies once per alert that just appeared.
    func process(_ alerts: [Alert]) {
        let fresh = tracker.update(alerts)
        guard Preferences.shared.notifications, !fresh.isEmpty else { return }
        for a in fresh { post(title: a.level == .critical ? "Critical" : "Warning", body: a.text, id: a.id, critical: a.level == .critical) }
    }

    func sendTest() {
        post(title: "MacResMon", body: "Notifications are working.", id: "test-\(Date().timeIntervalSince1970)", critical: false)
    }

    /// Asks for permission when needed, then delivers. `completion(false)` means notifications are off or denied.
    private func post(title: String, body: String, id: String, critical: Bool, completion: ((Bool) -> Void)? = nil) {
        guard available else { completion?(false); return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let deliver = {
                let content = UNMutableNotificationContent()
                content.title = title; content.body = body
                if critical { content.sound = .default }
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { _ in completion?(true) }
            }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: deliver()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in granted ? deliver() : completion?(false) }
            default: completion?(false)
            }
        }
    }

    /// "allowed", "denied" or "not asked yet", for the Settings window.
    func authorizationText(_ done: @escaping (String) -> Void) {
        guard available else { done("unavailable outside the app bundle"); return }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let text: String
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: text = "allowed"
            case .denied: text = "blocked in System Settings › Notifications"
            default: text = "not asked yet"
            }
            DispatchQueue.main.async { done(text) }
        }
    }

    // Show banners even while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
