import Foundation
import IOKit

enum IOKitRegistry {
    static func properties(_ entry: io_registry_entry_t) -> [String: Any] {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return [:] }
        return dict
    }

    static func forEach(matching className: String, _ body: (io_object_t) -> Void) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            body(entry)
            IOObjectRelease(entry)
        }
    }

    static func forEachChild(of entry: io_object_t, _ body: (io_object_t) -> Void) {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        while case let child = IOIteratorNext(iterator), child != 0 {
            body(child)
            IOObjectRelease(child)
        }
    }
}

enum GPUSampler {
    /// Overall utilization plus cumulative GPU nanoseconds per pid.
    static func sample() -> (GPUSnapshot, [Int32: UInt64]) {
        var snap = GPUSnapshot()
        var perPID: [Int32: UInt64] = [:]
        IOKitRegistry.forEach(matching: "IOAccelerator") { accel in
            let stats = IOKitRegistry.properties(accel)["PerformanceStatistics"] as? [String: Any] ?? [:]
            snap.device = max(snap.device, (stats["Device Utilization %"] as? Double ?? 0) / 100)
            snap.renderer = max(snap.renderer, (stats["Renderer Utilization %"] as? Double ?? 0) / 100)
            snap.tiler = max(snap.tiler, (stats["Tiler Utilization %"] as? Double ?? 0) / 100)
            snap.memoryInUse += stats["In use system memory"] as? UInt64 ?? 0

            IOKitRegistry.forEachChild(of: accel) { client in
                let props = IOKitRegistry.properties(client)
                guard let creator = props["IOUserClientCreator"] as? String,
                      let pid = parsePID(creator),
                      let usage = props["AppUsage"] as? [[String: Any]] else { return }
                let ns = usage.reduce(UInt64(0)) { $0 + ($1["accumulatedGPUTime"] as? UInt64 ?? 0) }
                perPID[pid, default: 0] += ns
            }
        }
        return (snap, perPID)
    }

    /// Parses `"pid 410, WindowServer"`.
    static func parsePID(_ creator: String) -> Int32? {
        guard creator.hasPrefix("pid ") else { return nil }
        return Int32(creator.dropFirst(4).prefix { $0.isNumber })
    }
}

final class DiskSampler {
    private var previous: (read: UInt64, written: UInt64, readOps: UInt64, writeOps: UInt64)?

    func sample(seconds: Double) -> IOSnapshot {
        var read: UInt64 = 0, written: UInt64 = 0, rOps: UInt64 = 0, wOps: UInt64 = 0
        IOKitRegistry.forEach(matching: "IOBlockStorageDriver") { driver in
            guard let stats = IOKitRegistry.properties(driver)["Statistics"] as? [String: Any] else { return }
            read += stats["Bytes (Read)"] as? UInt64 ?? 0
            written += stats["Bytes (Write)"] as? UInt64 ?? 0
            rOps += stats["Operations (Read)"] as? UInt64 ?? 0
            wOps += stats["Operations (Write)"] as? UInt64 ?? 0
        }
        defer { previous = (read, written, rOps, wOps) }
        var snap = IOSnapshot(totalRead: read, totalWritten: written)
        snap.readRate = ProcessSampler.rate(previous?.read, read, seconds: seconds)
        snap.writeRate = ProcessSampler.rate(previous?.written, written, seconds: seconds)
        snap.readOps = ProcessSampler.rate(previous?.readOps, rOps, seconds: seconds)
        snap.writeOps = ProcessSampler.rate(previous?.writeOps, wOps, seconds: seconds)
        return snap
    }
}
