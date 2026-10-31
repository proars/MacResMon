import Foundation
import MonitorCore

// Unit checks for MonitorCore: macmon frame parsing, host-metric parsers, snapshot and alert rules.
// Run: swift run CoreChecks   (exits 1 on any failure)

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    print("\(ok ? "✔" : "✖") \(name)\(ok ? "" : "  -> \(detail())")")
    if !ok { failures += 1 }
}
func near(_ a: Double?, _ b: Double, _ eps: Double = 1e-9) -> Bool { a.map { abs($0 - b) < eps } ?? false }

// ---- parseHardware ----
let frame: [String: Any] = [
    "cpu_active_ratio": 0.1, "pcpu_freq_mhz": 2948,
    "pcpu_cores": [["active_ratio": 0.1, "core_id": 0, "freq_mhz": 2776], ["active_ratio": 0.2, "core_id": 1, "freq_mhz": 2912]],
    "ecpu_freq_mhz": 1344,
    "ecpu_cores": [["active_ratio": 0.0, "core_id": 4, "freq_mhz": 0], ["active_ratio": 0.3, "core_id": 10, "freq_mhz": 1618]],
    "gpu_active_ratio": 0.36, "gpu_freq_mhz": 651, "gpu_power": 0.6, "cpu_power": 1.4, "all_power": 2.1, "sys_power": 5.2,
    "temp": ["cpu_temp_avg": 41.5, "gpu_temp_avg": 40.2],
    "memory": ["ram_total": 68719476736, "ram_usage": 35000000000, "swap_total": 4294967296, "swap_usage": 100],
    "fans": [["name": "fan0", "rpm": 1800, "max_rpm": 7826]],
]
let hw = parseHardware(frame, tierNames: ["Performance", "Efficiency"])
check("maps utilization, power and temperatures", near(hw.cpu, 0.1) && near(hw.gpuFreq, 651) && near(hw.sysPower, 5.2) && near(hw.cpuPower, 1.4) && near(hw.chipPower, 2.1) && near(hw.cpuTemp, 41.5))
check("maps memory and swap bytes", near(hw.ramTotal, 68719476736) && near(hw.swapUsed, 100))
check("builds clusters with mean load and names", hw.clusters.count == 2 && hw.clusters[0].name == "Performance" && near(hw.clusters[0].load, 0.15) && near(hw.clusters[1].load, 0.15) && hw.clusters[1].cores[1].id == 10)
check("reshapes fans to name/rpm/max", hw.fans.count == 1 && hw.fans[0].rpm == 1800 && hw.fans[0].max == 7826)
let empty = parseHardware([:])
check("tolerates an empty frame", empty.cpu == nil && empty.clusters.count == 2 && empty.clusters[0].cores.isEmpty && empty.clusters[0].load == 0 && empty.fans.isEmpty)
check("ignores non-finite and non-numeric values", parseHardware(["cpu_active_ratio": "abc", "gpu_power": Double.nan]).cpu == nil)

// ---- extractObjects ----
let (objs, rest) = extractObjects("{\"a\":1}\n{\"b\":\"}\"}\n{\"c\":{\"d\":2")
check("extractObjects finds complete objects, handles braces in strings, keeps the rest", objs == ["{\"a\":1}", "{\"b\":\"}\"}"] && rest == "{\"c\":{\"d\":2", "\(objs) | \(rest)")

// ---- system parsers ----
let procs = parseProcesses("""
  615  39.1 311280 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
39561   8.4 2297344 /Applications/Brave Browser.app/Contents/MacOS/Brave Browser Helper (Renderer)
garbage line
""")
check("parseProcesses reads pid, cpu, rss bytes and executable name", procs.count == 2 && procs[0].name == "WindowServer" && procs[0].rss == 311280 * 1024 && procs[1].name == "Brave Browser Helper (Renderer)", "\(procs)")
check("topBy sorts descending and limits", topBy([Proc(pid: 1, cpu: 1, rss: 0, name: "a"), Proc(pid: 2, cpu: 9, rss: 0, name: "b"), Proc(pid: 3, cpu: 5, rss: 0, name: "c")], { $0.cpu }, count: 2).map(\.pid) == [2, 3])

let ac = parseBattery("Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t80%; AC attached; not charging present: true", ac: " Wattage = 65W\n")
check("parseBattery on AC, not charging", ac?.percent == 80 && ac?.onBattery == false && ac?.state == "not charging" && ac?.adapterW == 65 && ac?.remaining == nil, "\(String(describing: ac))")
let dis = parseBattery("Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t55%; discharging; 3:41 remaining present: true")
check("parseBattery discharging with time left", dis?.percent == 55 && dis?.onBattery == true && dis?.remaining == "3:41" && dis?.adapterW == nil, "\(String(describing: dis))")
check("parseBattery charging; no battery -> nil", parseBattery("Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t40%; charging; 1:10 remaining present: true")?.charging == true && parseBattery("Now drawing from 'AC Power'\n") == nil && parseBattery("") == nil)

let d = parseDisk("Filesystem 1024-blocks Used Available Capacity iused ifree %iused Mounted on\n/dev/disk3s5 1948404040 636512180 1281897480 34% 1 2 0% /System/Volumes/Data")
check("parseDisk total and free bytes", d?.total == 1948404040 * 1024 && d?.free == 1281897480 * 1024 && parseDisk("") == nil)

check("rate gives bytes/second and rejects bad input", rate(1000, 3000, dtMs: 1000) == 2000 && rate(1000, 2000, dtMs: 500) == 2000 && rate(3000, 1000, dtMs: 1000) == nil && rate(nil, 5, dtMs: 1000) == nil)

// ---- snapshot ----
var sys = SystemSample()
sys.netIn = 1000; sys.battery = ac; sys.procs = procs
let pt = historyPoint(hw: hw, sys: sys, ts: 1)
let snap = snapshotDictionary(hw: hw, sys: sys, error: nil, sensorTs: 5, ts: 6, uptime: 3, point: pt)
let json = jsonString(snap)
check("snapshot reports the refresh interval", (snap["intervalMs"] as? Int) == 1000 && (snapshotDictionary(hw: hw, sys: sys, error: nil, sensorTs: 5, ts: 6, uptime: 3, point: pt, intervalMs: 500)["intervalMs"] as? Int) == 500)
check("snapshot carries the temperature unit", (snap["unit"] as? String) == "C" && (snapshotDictionary(hw: hw, sys: sys, error: nil, sensorTs: 5, ts: 6, uptime: 3, point: pt, unit: .fahrenheit)["unit"] as? String) == "F")
let back = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
check("snapshot has the keys the UI reads", ["cpu", "clusters", "fans", "procs", "battery", "disk", "net", "diskIO", "source", "sensorTs", "ts", "uptime", "intervalMs", "unit", "point"].allSatisfy { back[$0] != nil }, "\(back.keys.sorted())")
check("snapshot round-trips as JSON with null for missing values", (back["disk"] is NSNull) && ((back["point"] as? [String: Any])?["diskR"] is NSNull) && ((back["net"] as? [String: Any])?["in"] as? Double) == 1000)
let err = snapshotDictionary(hw: nil, sys: SystemSample(), error: "macmon not found", sensorTs: nil, ts: 6, uptime: 0, point: nil)
check("without hardware the snapshot carries an error and no cpu", (err["error"] as? String) == "macmon not found" && err["cpu"] == nil)

// ---- alerts ----
func ids(_ a: [Alert]) -> [String] { a.map(\.id) }
var calm = Hardware(); calm.cpuTemp = 60; calm.gpuTemp = 55; calm.ramTotal = 100; calm.ramUsed = 50; calm.fans = [Fan(name: nil, rpm: 2000, max: 7000)]
check("no alerts for a calm system or no data", evaluateAlerts(hw: calm, sys: SystemSample(), unit: .celsius).isEmpty && evaluateAlerts(hw: nil, sys: SystemSample(), unit: .celsius).isEmpty)
var hot = Hardware(); hot.cpuTemp = 89.9; hot.gpuTemp = 90
check("temperature alerts start at 90 °C", ids(evaluateAlerts(hw: hot, sys: SystemSample(), unit: .celsius)) == ["gpu-temp"])
hot.cpuTemp = 100
let tempAlerts = evaluateAlerts(hw: hot, sys: SystemSample(), unit: .celsius)
check("temperature is critical from 100 °C, warning below", tempAlerts.first { $0.id == "cpu-temp" }?.level == .critical && tempAlerts.first { $0.id == "gpu-temp" }?.level == .warning)
hot.cpuTemp = 95
check("alert text follows the unit", evaluateAlerts(hw: hot, sys: SystemSample(), unit: .fahrenheit).first?.text == "CPU is hot: 203°F" && evaluateAlerts(hw: hot, sys: SystemSample(), unit: .celsius).first?.text == "CPU is hot: 95°C")
var fans = Hardware(); fans.fans = [Fan(name: nil, rpm: 6700, max: 7000), Fan(name: nil, rpm: 100, max: 7000), Fan(name: nil, rpm: 9999, max: 0)]
check("fan at >= 95% of max alerts; max 0 ignored", ids(evaluateAlerts(hw: fans, sys: SystemSample(), unit: .celsius)) == ["fan-0"])
var mem = Hardware(); mem.ramTotal = 100; mem.ramUsed = 90
check("memory alert at 90%, critical at 95%", ids(evaluateAlerts(hw: mem, sys: SystemSample(), unit: .celsius)) == ["mem"] && { mem.ramUsed = 96; return evaluateAlerts(hw: mem, sys: SystemSample(), unit: .celsius).first?.level == .critical }())
var lowBat = SystemSample(); lowBat.battery = Battery(percent: 8, onBattery: true, charging: false, state: "discharging", remaining: nil, adapterW: nil)
var acBat = SystemSample(); acBat.battery = Battery(percent: 3, onBattery: false, charging: false, state: "not charging", remaining: nil, adapterW: 65)
var fullDisk = SystemSample(); fullDisk.disk = Disk(total: 100, free: 9)
var okDisk = SystemSample(); okDisk.disk = Disk(total: 100, free: 50)
check("battery alert only on battery; disk alert at <= 10% free", ids(evaluateAlerts(hw: nil, sys: lowBat, unit: .celsius)) == ["battery"] && evaluateAlerts(hw: nil, sys: acBat, unit: .celsius).isEmpty && ids(evaluateAlerts(hw: nil, sys: fullDisk, unit: .celsius)) == ["disk"] && evaluateAlerts(hw: nil, sys: okDisk, unit: .celsius).isEmpty)
check("formatTemp rounds and converts", formatTemp(63.4, .celsius) == "63°C" && formatTemp(100, .fahrenheit) == "212°F" && formatTemp(0, .fahrenheit) == "32°F" && formatTemp(nil, .celsius) == "–")
var tracker = AlertTracker()
let a1 = Alert(id: "mem", level: .warning, text: "m"), a2 = Alert(id: "disk", level: .warning, text: "d")
let n1 = tracker.update([a1]), n2 = tracker.update([a1]), n3 = tracker.update([a1, a2]), n4 = tracker.update([]), n5 = tracker.update([a1])
check("AlertTracker reports an alert once, again after it clears", n1 == [a1] && n2.isEmpty && n3 == [a2] && n4.isEmpty && n5 == [a1])

print(failures == 0 ? "\nALL CHECKS PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
