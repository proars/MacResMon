import Foundation
import IOKit
import Darwin

// Cumulative network and disk counters read straight from the system (no `netstat` / `ioreg` processes).

/// Total bytes received / sent over the physical network interfaces since boot, built from getifaddrs.
/// The kernel's per-interface counters are 32-bit and wrap, so deltas are accumulated into 64-bit totals.
final class NetworkCounter {
    private var last: [String: (rx: UInt32, tx: UInt32)] = [:]
    private var rx: UInt64 = 0, tx: UInt64 = 0
    private static let skip = ["lo", "gif", "stf", "ap", "awdl", "llw", "utun", "bridge", "anpi"]

    /// Reads the counters and returns the running totals.
    func read() -> (rx: Double, tx: Double) {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return (Double(rx), Double(tx)) }
        defer { freeifaddrs(list) }
        var seen = Set<String>()
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = p.pointee
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), let data = ifa.ifa_data else { continue }
            let name = String(cString: ifa.ifa_name)
            guard !Self.skip.contains(where: { name.hasPrefix($0) }), seen.insert(name).inserted else { continue }
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            if let prev = last[name] {
                rx &+= UInt64(d.ifi_ibytes &- prev.rx)   // wrapping subtraction handles the 32-bit rollover
                tx &+= UInt64(d.ifi_obytes &- prev.tx)
            }
            last[name] = (d.ifi_ibytes, d.ifi_obytes)
        }
        return (Double(rx), Double(tx))
    }
}

/// Total bytes read / written by all block-storage drivers since boot (the IOKit registry's statistics).
func diskCounters() -> (read: Double, write: Double) {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else { return (0, 0) }
    defer { IOObjectRelease(iterator) }
    var read = 0.0, write = 0.0
    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }
        guard let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any] else { continue }
        read += (stats["Bytes (Read)"] as? NSNumber)?.doubleValue ?? 0
        write += (stats["Bytes (Write)"] as? NSNumber)?.doubleValue ?? 0
    }
    return (read, write)
}
