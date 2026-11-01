import AppKit

// MacResMon (native shell): the web UI in a window, fed directly by Swift (no HTTP server),
// plus a menu-bar item, alert notifications and Settings.
//   MacResMon                              normal run
//   MacResMon --screenshot FILE            save a PNG of the window after a few seconds, then quit
//   MacResMon --screenshot-settings FILE   save a PNG of the Settings window, then quit
//   MacResMon --dump-status                print the menu-bar title and menu rows, then quit
//   MacResMon --background                 start like a login item: menu-bar item only, no window, no Dock icon

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let monitor = Monitor()
    let host = WebHost()
    let statusBar = StatusBar()
    lazy var settings = SettingsWindowController()
    var window: NSWindow!
    /// Started by the login-item service (Launch at login): stay in the menu bar, no window, no Dock icon.
    var launchedAtLogin = false

    /// True when macOS opened the app as a login item: the launch event carries 'lgit' in its 'prdt' parameter.
    /// `--background` asks for the same by hand.
    private static func detectLoginLaunch() -> Bool {
        if CommandLine.arguments.contains("--background") { return true }
        let prdt: AEKeyword = 0x70726474, lgit: OSType = 0x6C676974
        return NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: prdt)?.enumCodeValue == lgit
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchedAtLogin = Self.detectLoginLaunch()
        NSApp.mainMenu = makeMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 1000),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "MacResMon"
        window.isReleasedWhenClosed = false   // closing hides it; the menu bar can bring it back
        window.delegate = self
        window.contentView = host.webView
        window.setFrameAutosaveName("MainWindow")
        if !window.setFrameUsingName("MainWindow") { window.center() }

        statusBar.onShowWindow = { [weak self] in self?.showWindow() }
        statusBar.onSettings = { [weak self] in self?.showSettings() }
        Notifier.shared.start()
        monitor.onEvent = { [host] type, json in host.emit(type, json) }
        monitor.wantsWeb = { [weak self] in self?.webVisible ?? true }
        monitor.onTick = { [statusBar] live in statusBar.update(live); Notifier.shared.process(live.alerts) }
        host.onLoaded = { [monitor] in monitor.replay() }
        host.onRequest = { [weak self] type, data, reply in
            if type == "reports.get", self?.webVisible != true { reply("null") }   // a hidden page is not fed
            else if type == "settings.open" { self?.showSettings(); reply("ok") }
            else if type == "state.set" {
                if let key = data["key"] as? String, let value = data["value"] as? String, key.count < 64, value.count < 256 {
                    Preferences.shared.webState[key] = value
                }
                reply("ok")
            } else { ReportActions.handle(type, data, window: self?.window, reply: reply) }
        }
        // The page is only fed while it can be seen; when it becomes visible again it gets the current state at once.
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                if self?.webVisible == true { self?.monitor.replay() }
            }
        }
        // Without the menu-bar item a hidden app could not be reached: switching it off brings the window back.
        NotificationCenter.default.addObserver(forName: Preferences.didChange, object: nil, queue: .main) { [weak self] _ in
            if !Preferences.shared.showMenuBar, NSApp.activationPolicy() != .regular { self?.showWindow() }
        }
        host.load()
        monitor.start()

        let args = CommandLine.arguments
        func value(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
        if let file = value("--screenshot-settings") {
            showSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [settings] in
                if let v = settings.window.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: file))
                }
                NSApp.terminate(nil)
            }
            return
        }
        let forced = value("--screenshot") != nil || args.contains("--dump-status")
        if launchedAtLogin && !forced && Preferences.shared.showMenuBar {
            NSApp.setActivationPolicy(.accessory)   // login start: only the menu-bar item, no window and no Dock icon
        } else {
            showWindow()
        }
        if let file = value("--screenshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [host] in host.snapshot(to: file) { NSApp.terminate(nil) } }
        }
        if args.contains("--dump-status") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [statusBar] in print(statusBar.dump()); NSApp.terminate(nil) }
        }
    }

    /// True while the window is on screen and not covered, minimized or on another Space.
    var webVisible: Bool { window.isVisible && !window.isMiniaturized && window.occlusionState.contains(.visible) }

    func showWindow() {
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }   // the Dock icon is back while the window is open
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() { settings.show() }

    /// The red close button: with "Keep running in the menu bar" on (and the item shown) the window and the Dock icon go away
    /// and the app keeps monitoring from the menu bar; otherwise closing behaves as usual (the app quits or stays in the Dock).
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === window, Preferences.shared.keepRunning, Preferences.shared.showMenuBar else { return true }
        window.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    /// Clicking the Dock icon with the window closed brings it back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    /// Never in menu-bar-only mode (a login start has no main window; closing Settings must not quit the app).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !Preferences.shared.keepRunning && NSApp.activationPolicy() == .regular }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop(); ReportStore.shared.finish() }

    private func makeMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let app = NSMenu(); appItem.submenu = app
        app.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        app.addItem(.separator())
        app.addItem(withTitle: "Quit MacResMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let view = NSMenu(title: "View"); viewItem.submenu = view
        view.addItem(withTitle: "Reload", action: #selector(reload), keyEquivalent: "r").target = self
        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "Window"); winItem.submenu = win
        win.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return main
    }

    @objc func reload() { host.installHub(); host.webView.reload() }
    @objc func openSettings() { showSettings() }
}

// Quit cleanly on SIGTERM / SIGINT too (applicationWillTerminate stops the macmon child process).
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { NSApp.terminate(nil) }
    source.resume()
    signalSources.append(source)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
