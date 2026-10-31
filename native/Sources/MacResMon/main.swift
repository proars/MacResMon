import AppKit

// MacResMon (native shell): the web UI in a window, fed directly by Swift (no HTTP server),
// plus a menu-bar item, alert notifications and Settings.
//   MacResMon                              normal run
//   MacResMon --screenshot FILE            save a PNG of the window after a few seconds, then quit
//   MacResMon --screenshot-settings FILE   save a PNG of the Settings window, then quit
//   MacResMon --dump-status                print the menu-bar title and menu rows, then quit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = Monitor()
    let host = WebHost()
    let statusBar = StatusBar()
    lazy var settings = SettingsWindowController()
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 1000),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "MacResMon"
        window.isReleasedWhenClosed = false   // closing hides it; the menu bar can bring it back
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
        // The page is only fed while it can be seen; when it becomes visible again it gets the current state at once.
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                if self?.webVisible == true { self?.monitor.replay() }
            }
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
        showWindow()
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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() { settings.show() }

    /// Clicking the Dock icon with the window closed brings it back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !Preferences.shared.keepRunning }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop() }

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

    @objc func reload() { host.webView.reload() }
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
