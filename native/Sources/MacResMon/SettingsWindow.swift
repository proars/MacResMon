import AppKit

/// The Settings window (⌘,): launch at login, menu-bar item, keep running, notifications, temperature unit, update interval.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow!
    private let launch = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let launchHint = NSTextField(wrappingLabelWithString: "")
    private let menuBar = NSButton(checkboxWithTitle: "Show live readout in the menu bar", target: nil, action: nil)
    private let keep = NSButton(checkboxWithTitle: "Keep running in the menu bar when the window is closed", target: nil, action: nil)
    private let notify = NSButton(checkboxWithTitle: "Notify me about alerts (heat, fans, memory, battery, disk)", target: nil, action: nil)
    private let notifyStatus = NSTextField(labelWithString: "")
    private let unit = NSPopUpButton(frame: .zero, pullsDown: false)
    private let interval = NSPopUpButton(frame: .zero, pullsDown: false)

    override init() {
        super.init()
        for b in [launch, menuBar, keep, notify] { b.target = self }
        launch.action = #selector(toggleLaunch); menuBar.action = #selector(toggleMenuBar)
        keep.action = #selector(toggleKeep); notify.action = #selector(toggleNotify)
        launchHint.textColor = .secondaryLabelColor; launchHint.font = .systemFont(ofSize: 11)
        notifyStatus.textColor = .secondaryLabelColor; notifyStatus.font = .systemFont(ofSize: 11)
        unit.addItems(withTitles: ["Celsius (°C)", "Fahrenheit (°F)", "Follow system region"])
        unit.target = self; unit.action = #selector(changeUnit)
        interval.addItems(withTitles: Preferences.refreshChoices.map { $0 == 1 ? "1 second (default)" : "\($0.formatted()) seconds" })
        interval.target = self; interval.action = #selector(changeRefresh)

        let test = NSButton(title: "Send test notification", target: self, action: #selector(sendTest))
        let loginSettings = NSButton(title: "Open Login Items…", target: self, action: #selector(openLoginItems))
        let unitRow = NSStackView(views: [NSTextField(labelWithString: "Temperature unit:"), unit])
        unitRow.spacing = 8
        let refreshRow = NSStackView(views: [NSTextField(labelWithString: "Update interval:"), interval])
        refreshRow.spacing = 8
        let notifyRow = NSStackView(views: [test, notifyStatus]); notifyRow.spacing = 10
        let loginRow = NSStackView(views: [launchHint, loginSettings]); loginRow.spacing = 10

        let stack = NSStackView(views: [launch, loginRow, sep(), menuBar, keep, sep(), notify, notifyRow, sep(), unitRow, refreshRow])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 22, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSView()
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: window.contentView!.trailingAnchor),
        ])
        window.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Preferences.didChange, object: nil)
        refresh()
    }

    private func sep() -> NSBox { let b = NSBox(); b.boxType = .separator; b.widthAnchor.constraint(equalToConstant: 440).isActive = true; return b }

    func show() {
        refresh()
        // Fit the window to its content.
        if let size = window.contentView?.subviews.first?.fittingSize { window.setContentSize(NSSize(width: max(520, size.width), height: size.height)) }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Re-reads every control from the real state (login item status comes from macOS).
    @objc func refresh() {
        let p = Preferences.shared
        launch.state = LoginItem.isEnabled || LoginItem.needsApproval ? .on : .off
        launchHint.stringValue = LoginItem.needsApproval ? "Waiting for your approval in System Settings › General › Login Items." : ""
        menuBar.state = p.showMenuBar ? .on : .off
        keep.state = p.keepRunning ? .on : .off
        notify.state = p.notifications ? .on : .off
        unit.selectItem(at: p.unitChoice)
        interval.selectItem(at: Preferences.refreshChoices.firstIndex(of: p.refreshInterval) ?? 1)
        Notifier.shared.authorizationText { [weak self] t in self?.notifyStatus.stringValue = "macOS permission: \(t)" }
        launchHint.isHidden = launchHint.stringValue.isEmpty
    }

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
    @objc private func toggleMenuBar() { Preferences.shared.showMenuBar = menuBar.state == .on }
    @objc private func toggleKeep() { Preferences.shared.keepRunning = keep.state == .on }
    @objc private func toggleNotify() {
        Preferences.shared.notifications = notify.state == .on
        if notify.state == .on { Notifier.shared.sendTest() }   // triggers the one-time permission prompt
    }
    @objc private func changeUnit() { Preferences.shared.unitChoice = unit.indexOfSelectedItem }
    @objc private func changeRefresh() { Preferences.shared.refreshInterval = Preferences.refreshChoices[interval.indexOfSelectedItem] }
    @objc private func sendTest() { Notifier.shared.sendTest(); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refresh() } }
    @objc private func openLoginItems() { LoginItem.openSystemSettings() }
}
