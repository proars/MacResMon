import AppKit
import MonitorCore

/// The Settings window (⌘,), in sections: General, Menu bar (what it shows), Notifications, Display, Reports.
/// Every control writes to `Preferences` at once (UserDefaults), so nothing needs a Save button and everything is
/// back at the next launch. The window position is remembered too.
final class SettingsWindowController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private static let width: CGFloat = 540
    private static let inset: CGFloat = 24

    private(set) var window: NSWindow!
    private let launch = NSButton(checkboxWithTitle: "Launch at login (starts hidden in the menu bar)", target: nil, action: nil)
    private let launchHint = NSTextField(wrappingLabelWithString: "")
    private let keep = NSButton(checkboxWithTitle: "Keep running in the menu bar when the window is closed", target: nil, action: nil)
    private let menuBar = NSButton(checkboxWithTitle: "Show the live readout in the menu bar", target: nil, action: nil)
    private var itemBoxes: [MenuBarItem: NSButton] = [:]
    private let notify = NSButton(checkboxWithTitle: "Notify me about alerts (heat, fans, memory, battery, disk)", target: nil, action: nil)
    private let notifyStatus = NSTextField(labelWithString: "")
    private let unit = NSPopUpButton(frame: .zero, pullsDown: false)
    private let interval = NSPopUpButton(frame: .zero, pullsDown: false)
    private let price = NSTextField(string: "")
    private let currency = NSTextField(labelWithString: "")
    private var hasSavedFrame = false

    override init() {
        super.init()
        for b in [launch, keep, menuBar, notify] { b.target = self }
        launch.action = #selector(toggleLaunch); keep.action = #selector(toggleKeep)
        menuBar.action = #selector(toggleMenuBar); notify.action = #selector(toggleNotify)
        for t in [launchHint, notifyStatus] { t.textColor = .secondaryLabelColor; t.font = .systemFont(ofSize: 11) }
        unit.addItems(withTitles: ["Celsius (°C)", "Fahrenheit (°F)", "Follow system region"])
        unit.target = self; unit.action = #selector(changeUnit)
        interval.addItems(withTitles: Preferences.refreshChoices.map { $0 == 1 ? "1 second (default)" : "\($0.formatted()) seconds" })
        interval.target = self; interval.action = #selector(changeRefresh)
        for (i, item) in MenuBarItem.allCases.enumerated() {
            let b = NSButton(checkboxWithTitle: item.label, target: self, action: #selector(toggleItem(_:)))
            b.tag = i
            itemBoxes[item] = b
        }
        price.alignment = .right; price.widthAnchor.constraint(equalToConstant: 70).isActive = true
        price.target = self; price.action = #selector(changePrice); price.delegate = self
        (price.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = true

        // Sections
        let loginRow = NSStackView(views: [launchHint, NSButton(title: "Open Login Items…", target: self, action: #selector(openLoginItems))]); loginRow.spacing = 10
        let keepHint = NSTextField(labelWithString: "The red close button then hides the window and the Dock icon; open it again from the menu bar.")
        keepHint.textColor = .secondaryLabelColor; keepHint.font = .systemFont(ofSize: 11)
        let keepBox = NSStackView(views: [keep, keepHint]); keepBox.orientation = .vertical; keepBox.alignment = .leading; keepBox.spacing = 2
        keepHint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let general = section("General", [launch, loginRow, keepBox])

        let grid = NSGridView(views: stride(from: 0, to: MenuBarItem.allCases.count, by: 2).map { i in
            MenuBarItem.allCases[i..<min(i + 2, MenuBarItem.allCases.count)].map { itemBoxes[$0]! as NSView }
        })
        grid.columnSpacing = 24; grid.rowSpacing = 8
        let itemsRow = NSStackView(views: [grid]); itemsRow.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        let bar = section("Menu bar", [menuBar, itemsRow])

        let notifyRow = NSStackView(views: [NSButton(title: "Send test notification", target: self, action: #selector(sendTest)), notifyStatus]); notifyRow.spacing = 10
        let notifications = section("Notifications", [notify, notifyRow])

        let display = section("Display", [labeled("Temperature unit:", unit), labeled("Update interval:", interval)])

        let kwh = NSStackView(views: [currency, price, NSTextField(labelWithString: "per kWh")]); kwh.spacing = 6
        let reports = section("Reports", [labeled("Electricity price:", kwh), NSButton(title: "Reset reports…", target: self, action: #selector(resetReports))])

        let stack = NSStackView(views: [general, sep(), bar, sep(), notifications, sep(), display, sep(), reports])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: Self.inset, bottom: 22, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSView()
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            stack.widthAnchor.constraint(equalToConstant: Self.width),
        ])
        window.delegate = self
        hasSavedFrame = window.setFrameUsingName("SettingsWindow")
        window.setFrameAutosaveName("SettingsWindow")
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Preferences.didChange, object: nil)
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in self?.storePrice() }
        refresh()
    }

    // ---- layout helpers ----

    /// A bold heading with its controls below, indented a little.
    private func section(_ title: String, _ views: [NSView]) -> NSStackView {
        let head = NSTextField(labelWithString: title)
        head.font = .boldSystemFont(ofSize: 13)
        let body = NSStackView(views: views)
        body.orientation = .vertical; body.alignment = .leading; body.spacing = 8
        body.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        let s = NSStackView(views: [head, body])
        s.orientation = .vertical; s.alignment = .leading; s.spacing = 8
        return s
    }

    private func labeled(_ text: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: text)
        label.widthAnchor.constraint(equalToConstant: 130).isActive = true
        let row = NSStackView(views: [label, control]); row.spacing = 8
        return row
    }

    private func sep() -> NSBox {
        let b = NSBox(); b.boxType = .separator
        b.widthAnchor.constraint(equalToConstant: Self.width - 2 * Self.inset).isActive = true
        return b
    }

    func show() {
        refresh()
        // Fit the window to its content, keeping its top-left corner where it is.
        if let size = window.contentView?.subviews.first?.fittingSize {
            let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
            window.setContentSize(NSSize(width: Self.width, height: size.height))
            if hasSavedFrame { window.setFrameTopLeftPoint(topLeft) }
        }
        if !hasSavedFrame { window.center() }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)   // do not open with the price field in edit mode
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Re-reads every control from the real state (login item status comes from macOS).
    @objc func refresh() {
        let p = Preferences.shared
        launch.state = LoginItem.isEnabled || LoginItem.needsApproval ? .on : .off
        launchHint.stringValue = LoginItem.needsApproval ? "Waiting for your approval in System Settings › General › Login Items." : ""
        launchHint.isHidden = launchHint.stringValue.isEmpty
        keep.state = p.keepRunning ? .on : .off
        menuBar.state = p.showMenuBar ? .on : .off
        let chosen = p.menuBarItems
        for (item, box) in itemBoxes { box.state = chosen.contains(item) ? .on : .off; box.isEnabled = p.showMenuBar }
        notify.state = p.notifications ? .on : .off
        unit.selectItem(at: p.unitChoice)
        interval.selectItem(at: Preferences.refreshChoices.firstIndex(of: p.refreshInterval) ?? 1)
        if price.currentEditor() == nil { price.stringValue = String(p.electricityPrice) }   // not while the user is typing
        currency.stringValue = p.currencySymbol
        Notifier.shared.authorizationText { [weak self] t in self?.notifyStatus.stringValue = "macOS permission: \(t)" }
    }

    // ---- actions ----

    @objc private func toggleLaunch() {
        let want = launch.state == .on
        do { try LoginItem.set(want) } catch {
            let a = NSAlert()
            a.messageText = want ? "Could not enable launch at login" : "Could not disable launch at login"
            a.informativeText = "\(error.localizedDescription)\n\nThis works only when MacResMon runs as an app (build it with `npm run native:build`) and may need your approval in System Settings › General › Login Items."
            a.runModal()
        }
        refresh()
    }
    @objc private func toggleKeep() { Preferences.shared.keepRunning = keep.state == .on }
    @objc private func toggleMenuBar() { Preferences.shared.showMenuBar = menuBar.state == .on }
    @objc private func toggleItem(_ sender: NSButton) {
        var items = Preferences.shared.menuBarItems
        let item = MenuBarItem.allCases[sender.tag]
        if sender.state == .on { items.insert(item) } else { items.remove(item) }
        Preferences.shared.menuBarItems = items
    }
    @objc private func toggleNotify() {
        Preferences.shared.notifications = notify.state == .on
        if notify.state == .on { Notifier.shared.sendTest() }   // triggers the one-time permission prompt
    }
    @objc private func changeUnit() { Preferences.shared.unitChoice = unit.indexOfSelectedItem }
    @objc private func changeRefresh() { Preferences.shared.refreshInterval = Preferences.refreshChoices[interval.indexOfSelectedItem] }

    /// Saves the typed price when it is a valid number (comma or dot); returns whether it was.
    @discardableResult private func storePrice() -> Bool {
        guard let v = Double(price.stringValue.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")), v.isFinite, v >= 0 else { return false }
        if v != Preferences.shared.electricityPrice { Preferences.shared.electricityPrice = v }
        return true
    }
    /// Every keystroke is saved, so closing the window or quitting while the field is still being edited loses nothing.
    func controlTextDidChange(_ obj: Notification) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(savePrice), object: nil)
        perform(#selector(savePrice), with: nil, afterDelay: 0.4)   // not on every key: each save notifies the whole app
    }
    @objc private func savePrice() { storePrice() }
    /// Enter or leaving the field: invalid text goes back to the stored value.
    @objc private func changePrice() { if !storePrice() { price.stringValue = String(Preferences.shared.electricityPrice) } }
    func windowWillClose(_ notification: Notification) { window.makeFirstResponder(nil); changePrice() }
    @objc private func resetReports() { ReportActions.confirmReset(in: window) { _ in } }
    @objc private func sendTest() { Notifier.shared.sendTest(); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refresh() } }
    @objc private func openLoginItems() { LoginItem.openSystemSettings() }
}
