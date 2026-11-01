import AppKit
import MonitorCore

/// Keeps the ReportLog on disk (`~/Library/Application Support/MacResMon/reports.json`). Main thread only.
/// Saved every 30 s, when a spike starts or ends, and on quit; the write itself happens off the main thread.
final class ReportStore {
    static let shared = ReportStore()
    private(set) var log = ReportLog()
    private let url: URL
    private var lastTick: Date?
    private var lastSave = Date()
    private var dirty = false
    private let io = DispatchQueue(label: "reports.io")

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacResMon", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("reports.json")
        guard let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode(ReportLog.self, from: data) {
            log = loaded
        } else {   // unreadable: keep it aside instead of overwriting it
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("bad"))
        }
    }

    func record(_ hw: Hardware?, laptop: Bool = false, now: Date = Date()) {
        let dt = lastTick.map { now.timeIntervalSince($0) } ?? 0
        lastTick = now
        guard hw != nil else { return }
        dirty = true
        let edge = log.record(hw, at: now.timeIntervalSince1970 * 1000, dt: dt,
                            maxW: laptop ? ReportLog.maxPlausibleLaptopW : ReportLog.maxPlausibleW)
        if edge || now.timeIntervalSince(lastSave) >= 30 { save() }
    }

    func save(wait: Bool = false) {
        guard dirty else { return }
        dirty = false; lastSave = Date()
        guard let data = try? JSONEncoder().encode(log) else { return }
        let url = self.url
        let write: () -> Void = { try? data.write(to: url, options: .atomic) }
        if wait { io.sync(execute: write) } else { io.async(execute: write) }
    }

    /// On quit: close open spikes and write synchronously.
    func finish() { log.finish(); dirty = true; save(wait: true) }

    func reset() { log = ReportLog(); lastTick = nil; dirty = true; save() }

    var payload: String {
        let p = Preferences.shared
        return jsonString(reportDictionary(log, price: p.electricityPrice, currency: p.currencySymbol, unit: p.unit))
    }
}

/// The dialogs behind the Reports page and Settings: save a CSV, confirm and erase.
enum ReportActions {
    /// Asks for a file name and writes `text` there. `done(true)` when written, false when cancelled or failed.
    static func export(_ text: String, name: String, in window: NSWindow?, done: @escaping (Bool) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [.commaSeparatedText]
        let finish: (NSApplication.ModalResponse) -> Void = { r in
            guard r == .OK, let url = panel.url else { done(false); return }
            done((try? text.write(to: url, atomically: true, encoding: .utf8)) != nil)
        }
        if let window = window { panel.beginSheetModal(for: window, completionHandler: finish) } else { finish(panel.runModal()) }
    }

    /// Confirms, then erases the whole log. `done(true)` when erased.
    static func confirmReset(in window: NSWindow?, done: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Erase all reports?"
        alert.informativeText = "The power log and temperature spikes will be deleted. This cannot be undone. Export them to CSV first if you need them."
        alert.addButton(withTitle: "Erase")
        alert.addButton(withTitle: "Cancel")
        let finish: (NSApplication.ModalResponse) -> Void = { r in
            if r == .alertFirstButtonReturn { ReportStore.shared.reset(); done(true) } else { done(false) }
        }
        if let window = window { alert.beginSheetModal(for: window, completionHandler: finish) } else { finish(alert.runModal()) }
    }

    /// Handles a request from the Reports page and answers with a short string the page understands.
    static func handle(_ type: String, _ data: [String: Any], window: NSWindow?, reply: @escaping (String) -> Void) {
        let store = ReportStore.shared, p = Preferences.shared
        let range = reportRange(store.log, from: data["from"] as? String)
        let stamp = (data["from"] as? String).flatMap { $0.isEmpty ? nil : "from-\($0)" } ?? "all"
        switch type {
        case "reports.get": reply(store.payload)
        case "reports.exportDays":
            export(daysCSV(range.days, price: p.electricityPrice), name: "macresmon-power-\(stamp).csv", in: window) { reply($0 ? "saved" : "cancelled") }
        case "reports.exportSpikes":
            export(spikesCSV(range.spikes, unit: p.unit), name: "macresmon-spikes-\(stamp).csv", in: window) { reply($0 ? "saved" : "cancelled") }
        case "reports.reset": confirmReset(in: window) { reply($0 ? "reset" : "cancelled") }
        default: reply("unknown")
        }
    }
}
