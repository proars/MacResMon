import Foundation
import MonitorCore

/// Ticks once per refresh interval (Settings, 1 s by default): merges the sampler's data into a snapshot, keeps the 60-sample history and
/// hands both to the web view through `window.__nativeHub` (see useStream.js on the UI side).
final class Monitor {
    static let historyLength = 60
    private let sampler = Sampler()
    private var history: [[String: Any]] = []
    /// When the Mac booted (sleep time counts, like the `uptime` command).
    private let booted: Date = {
        var tv = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return Date() }
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec))
    }()
    private var timer: Timer?
    /// Called on the main thread with ("history" | "snapshot", JSON text).
    var onEvent: ((String, String) -> Void)?
    /// Called on the main thread every tick with the readings, for the menu bar and notifications.
    var onTick: ((Live) -> Void)?
    private var latest: [String: Any] = [:]
    /// Asked every tick: is the web page visible? A hidden page is not fed (it would only burn CPU and memory).
    var wantsWeb: () -> Bool = { true }

    private var interval = Preferences.shared.refreshInterval

    func start() {
        sampler.interval = interval
        sampler.start()
        schedule()
        NotificationCenter.default.addObserver(forName: Preferences.didChange, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, Preferences.shared.refreshInterval != self.interval else { return }
            self.interval = Preferences.shared.refreshInterval
            self.sampler.interval = self.interval
            self.schedule()
        }
    }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() { timer?.invalidate(); sampler.stop() }

    private func tick() {
        let cur = sampler.current()
        let ts = nowMs()
        var point: [String: Any]?
        if let hw = cur.hw {   // nothing to record until the first sensor frame
            let p = historyPoint(hw: hw, sys: cur.sys, ts: ts)
            history.append(p)
            if history.count > Monitor.historyLength { history.removeFirst(history.count - Monitor.historyLength) }
            point = p
        }
        let snap = snapshotDictionary(hw: cur.hw, sys: cur.sys, error: cur.error, sensorTs: cur.at, ts: ts,
                                      uptime: Int(Date().timeIntervalSince(booted)), point: point, intervalMs: Int(interval * 1000))
        latest = snap
        if wantsWeb() { onEvent?("snapshot", jsonString(snap)) }
        onTick?(Live(hw: cur.hw, sys: cur.sys, alerts: evaluateAlerts(hw: cur.hw, sys: cur.sys, unit: Preferences.shared.unit), error: cur.error))
    }

    /// Replays the state to a freshly loaded page.
    func replay() {
        onEvent?("history", jsonString(history))
        onEvent?("snapshot", jsonString(latest))
    }
}
