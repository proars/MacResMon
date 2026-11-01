import AppKit
import MonitorCore

/// Everything the menu bar shows for one tick.
struct Live {
    var hw: Hardware?
    var sys: SystemSample
    var alerts: [Alert]
    var error: String?
}

/// The menu-bar item: a fan icon with a short live readout, and a menu with the details.
final class StatusBar: NSObject {
    private var item: NSStatusItem?
    private let menu = NSMenu()
    private var lines: [NSMenuItem] = []
    private let alertItem = NSMenuItem()
    private var live: Live?
    private var knownAlerts = Set<String>()
    private var blinkTimer: Timer?
    private var blinkUntil = Date.distantPast
    var onShowWindow: (() -> Void)?
    var onSettings: (() -> Void)?

    override init() {
        super.init()
        for _ in 0..<6 { let m = NSMenuItem(); m.isEnabled = false; lines.append(m); menu.addItem(m) }
        alertItem.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(alertItem)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open MacResMon", action: #selector(showWindow), keyEquivalent: "o"); open.target = self
        let prefs = NSMenuItem(title: "Settings…", action: #selector(settings), keyEquivalent: ","); prefs.target = self
        menu.addItem(open); menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MacResMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applyVisibility()
        NotificationCenter.default.addObserver(self, selector: #selector(prefsChanged), name: Preferences.didChange, object: nil)
    }

    @objc private func showWindow() { onShowWindow?() }
    @objc private func settings() { onSettings?() }
    @objc private func prefsChanged() { applyVisibility(); if let l = live { update(l) } }

    private func applyVisibility() {
        if Preferences.shared.showMenuBar {
            guard item == nil else { return }
            let i = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let image = NSImage(systemSymbolName: "fan", accessibilityDescription: "MacResMon") ?? NSImage(systemSymbolName: "gauge", accessibilityDescription: "MacResMon")
            image?.isTemplate = true
            i.button?.image = image
            i.button?.imagePosition = .imageLeading
            i.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
            i.menu = menu
            item = i
        } else if let i = item {
            NSStatusBar.system.removeStatusItem(i)
            item = nil
        }
    }

    /// The button text, e.g. " 14%  48°" (and "⚠︎" in front while an alert is active); the parts are chosen in Settings.
    static func title(_ l: Live, unit: TempUnit, items: Set<MenuBarItem> = Preferences.shared.menuBarItems) -> String {
        menuBarTitle(hw: l.hw, battery: l.sys.battery, items: items, unit: unit, alerting: !l.alerts.isEmpty, error: l.error)
    }

    /// The menu rows.
    static func rows(_ l: Live, unit: TempUnit) -> [String] {
        guard let hw = l.hw else { return [l.error ?? "Waiting for sensor data…"] }
        func pct(_ v: Double?) -> String { v.map { "\(Int(($0 * 100).rounded()))%" } ?? "–" }
        func gb(_ v: Double?) -> String { v.map { String(format: "%.1f", $0 / 1_073_741_824) } ?? "–" }
        var rows = [
            "CPU  \(pct(hw.cpu))  ·  \(formatTemp(hw.cpuTemp, unit))",
            "GPU  \(pct(hw.gpu))  ·  \(formatTemp(hw.gpuTemp, unit))",
            "Memory  \(gb(hw.ramUsed)) / \(gb(hw.ramTotal)) GB",
            hw.fans.isEmpty ? "Fans  none" : "Fans  " + hw.fans.map { "\(Int($0.rpm.rounded())) rpm" }.joined(separator: "  ·  "),
            "Power  " + (hw.sysPower.map { String(format: "%.1f W", $0) } ?? "–"),
        ]
        if let b = l.sys.battery { rows.append("Battery  \(b.percent)%  ·  \(b.onBattery ? "on battery" : "AC power")") }
        return rows
    }

    func update(_ l: Live) {
        live = l
        let unit = Preferences.shared.unit
        setTitle(Self.title(l, unit: unit), alerts: l.alerts)
        noteAlerts(l.alerts)
        let rows = Self.rows(l, unit: unit)
        for (i, m) in lines.enumerated() {
            m.title = i < rows.count ? rows[i] : ""
            m.isHidden = i >= rows.count
        }
        alertItem.title = l.alerts.isEmpty ? "No alerts" : l.alerts.map { "⚠︎ " + $0.text }.joined(separator: "\n")
    }

    /// Orange for a warning, red for a critical alert (icon and text); the normal menu-bar look otherwise.
    private func setTitle(_ text: String, alerts: [Alert]) {
        guard let button = item?.button else { return }
        let color: NSColor? = alerts.isEmpty ? nil : alerts.contains { $0.level == .critical } ? .systemRed : .systemOrange
        button.contentTintColor = color
        guard let color = color else { button.title = text; return }   // plain title: the system picks the right color for the menu bar
        button.attributedTitle = NSAttributedString(string: text, attributes: [.font: button.font ?? NSFont.menuBarFont(ofSize: 0), .foregroundColor: color])
    }

    /// A new alert makes the item blink for a few seconds (it is visible with the window closed); the color stays while the alert lasts.
    private func noteAlerts(_ alerts: [Alert]) {
        let ids = Set(alerts.map(\.id))
        if !ids.subtracting(knownAlerts).isEmpty { blinkUntil = Date().addingTimeInterval(8) }
        knownAlerts = ids
        if Date() < blinkUntil, blinkTimer == nil {
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in self?.blink() }
            RunLoop.main.add(blinkTimer!, forMode: .common)
        }
    }

    private func blink() {
        guard let button = item?.button else { blinkTimer?.invalidate(); blinkTimer = nil; return }
        if Date() >= blinkUntil || knownAlerts.isEmpty {
            blinkTimer?.invalidate(); blinkTimer = nil
            button.alphaValue = 1
        } else {
            button.alphaValue = button.alphaValue == 1 ? 0.25 : 1
        }
    }

    /// For `--dump-status` (checks without looking at the menu bar).
    func dump() -> String {
        var out = ["title: \"\(item?.button?.title ?? "(hidden)")\""]
        out += lines.filter { !$0.isHidden }.map { "row: \($0.title)" }
        out.append("alerts: \(alertItem.title)")
        return out.joined(separator: "\n")
    }
}
