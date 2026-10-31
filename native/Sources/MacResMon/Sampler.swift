import Foundation
import MonitorCore

/// Runs a macOS command and returns its stdout ("" on failure or timeout).
func run(_ path: String, _ args: [String], timeout: TimeInterval = 4) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let out = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return "" }
    let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    killer.cancel()
    return String(decoding: data, as: UTF8.self)
}

/// Collects everything the dashboard shows: macmon frames (CPU/GPU/power/temps/fans/memory) from a
/// long-running child process, plus host metrics (processes every 5 s, battery every 10 s, disk space every 30 s, network and disk I/O every refresh interval).
final class Sampler {
    private let lock = NSLock()
    private var hardware: Hardware?
    private var hardwareAt: Int64?
    private var system = SystemSample()
    private var macmonError: String? = "macmon not connected yet"
    private var macmon: Process?
    private var stopped = false
    private var restartingMacmon = false
    private var _interval = 1.0

    /// Seconds between readings. Changing it restarts macmon with the new frame interval.
    var interval: Double {
        get { lock.lock(); defer { lock.unlock() }; return _interval }
        set {
            lock.lock()
            let changed = newValue != _interval
            _interval = newValue
            if changed, let p = macmon, p.isRunning { restartingMacmon = true; p.terminate() }
            lock.unlock()
        }
    }

    func start() {
        DispatchQueue.global(qos: .utility).async { [self] in startMacmon() }
        Thread.detachNewThread { [self] in systemLoop() }
    }

    func stop() {
        stopped = true
        macmon?.terminate()
    }

    /// Latest hardware (nil until the first frame), when it arrived, the host metrics and the last macmon error.
    func current() -> (hw: Hardware?, at: Int64?, sys: SystemSample, error: String?) {
        lock.lock(); defer { lock.unlock() }
        return (hardware, hardwareAt, system, macmonError)
    }

    // ---- macmon ----

    private func macmonPath() -> String? {
        let env = ProcessInfo.processInfo.environment["MACMON_BIN"]
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("bin/macmon").path
        return [env, bundled, "/opt/homebrew/bin/macmon", "/usr/local/bin/macmon"]
            .compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func setError(_ text: String?) { lock.lock(); macmonError = text; lock.unlock() }

    private func startMacmon() {
        while !stopped {
            guard let path = macmonPath() else {
                setError("macmon was not found. Install it with `brew install macmon`.")
                Thread.sleep(forTimeInterval: 5)
                continue
            }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            lock.lock(); restartingMacmon = false; let ms = Int(_interval * 1000); lock.unlock()
            p.arguments = ["pipe", "-i", String(ms)]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            var buffer = ""
            out.fileHandleForReading.readabilityHandler = { [self] h in
                let data = h.availableData
                if data.isEmpty { return }
                buffer += String(decoding: data, as: UTF8.self)
                let (objects, rest) = extractObjects(buffer)
                buffer = rest
                for o in objects {
                    guard let obj = try? JSONSerialization.jsonObject(with: Data(o.utf8)) as? [String: Any] else { continue }
                    let hw = parseHardware(obj, tierNames: ["Performance", "Efficiency"])
                    lock.lock(); hardware = hw; hardwareAt = nowMs(); macmonError = nil; lock.unlock()
                }
            }
            macmon = p
            do { try p.run() } catch { setError("macmon failed to start: \(error.localizedDescription)"); Thread.sleep(forTimeInterval: 5); continue }
            p.waitUntilExit()
            out.fileHandleForReading.readabilityHandler = nil
            lock.lock(); let intended = restartingMacmon; lock.unlock()
            if !stopped && !intended { setError("macmon stopped; restarting…"); Thread.sleep(forTimeInterval: 2) }
        }
    }

    // ---- host metrics ----

    private func systemLoop() {
        var last: (net: (rx: Double, tx: Double), io: (read: Double, write: Double), t: Int64)?
        let network = NetworkCounter()
        var lastProcs: Int64 = 0, lastBattery: Int64 = 0, lastDisk: Int64 = 0
        while !stopped {
            // Rates: every refresh interval, from counters read directly (no processes spawned).
            let t = nowMs()
            let net = network.read()
            let io = diskCounters()
            var nin: Double?, nout: Double?, dr: Double?, dw: Double?
            if let l = last {
                let dt = Double(t - l.t)
                nin = rate(l.net.rx, net.rx, dtMs: dt); nout = rate(l.net.tx, net.tx, dtMs: dt)
                dr = rate(l.io.read, io.read, dtMs: dt); dw = rate(l.io.write, io.write, dtMs: dt)
            }
            last = (net, io, t)
            lock.lock(); system.netIn = nin; system.netOut = nout; system.diskRead = dr; system.diskWrite = dw; lock.unlock()

            if t - lastProcs >= 5000 {   // processes: every 5 s
                let procs = parseProcesses(run("/bin/ps", ["-Ao", "pid=,pcpu=,rss=,comm="]))
                lock.lock(); system.procs = procs; lock.unlock()
                lastProcs = t
            }
            if t - lastBattery >= 10000 {  // battery: every 10 s
                let b = parseBattery(run("/usr/bin/pmset", ["-g", "batt"]), ac: run("/usr/bin/pmset", ["-g", "ac"]))
                lock.lock(); system.battery = b; lock.unlock()
                lastBattery = t
            }
            if t - lastDisk >= 30000 {  // disk space: every 30 s
                let d = parseDisk(run("/bin/df", ["-k", "/System/Volumes/Data"])) ?? parseDisk(run("/bin/df", ["-k", "/"]))
                lock.lock(); system.disk = d; lock.unlock()
                lastDisk = t
            }
            let spent = Double(nowMs() - t) / 1000
            Thread.sleep(forTimeInterval: max(0.05, interval - spent))
        }
    }
}

func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
