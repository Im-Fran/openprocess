import Foundation
import IOKit

final class CPUSampler {
    private struct Ticks { var user, system, idle, nice: UInt64 }
    private var previous: [Ticks] = []
    /// (kind, display name) per logical CPU.
    let topology: [(kind: String, name: String)] = CPUSampler.readTopology()

    func sample() -> CPUSnapshot {
        var snap = CPUSnapshot()
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)
        snap.loadAverage = loads

        let current = Self.readTicks()
        defer { previous = current }
        guard previous.count == current.count else { return snap }

        var totalUser = 0.0, totalSystem = 0.0
        for (i, (old, new)) in zip(previous, current).enumerated() {
            let user = Double(new.user &- old.user + new.nice &- old.nice)
            let system = Double(new.system &- old.system)
            let all = user + system + Double(new.idle &- old.idle)
            let u = all > 0 ? user / all : 0, s = all > 0 ? system / all : 0
            totalUser += u; totalSystem += s
            let topo = i < topology.count ? topology[i] : (kind: "?", name: "")
            snap.cores.append(CoreLoad(id: i, clusterKind: topo.kind, clusterName: topo.name, user: u, system: s))
        }
        let n = Double(current.count)
        snap.user = totalUser / n
        snap.system = totalSystem / n
        return snap
    }

    private static func readTicks() -> [Ticks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        return (0..<Int(count)).map { i in
            let base = i * Int(CPU_STATE_MAX)
            func t(_ state: Int32) -> UInt64 { UInt64(UInt32(bitPattern: info[base + Int(state)])) }
            return Ticks(user: t(CPU_STATE_USER), system: t(CPU_STATE_SYSTEM), idle: t(CPU_STATE_IDLE), nice: t(CPU_STATE_NICE))
        }
    }

    /// Cluster type per logical CPU from the device tree; names from `hw.perflevelN.name`.
    static func readTopology() -> [(kind: String, name: String)] {
        // Apple's cluster names ("Super", "Performance", "Efficiency") stay in English in every language.
        let pName = Sysctl.string("hw.perflevel0.name") ?? "Performance"
        let eName = Sysctl.string("hw.perflevel1.name") ?? "Efficiency"
        var kinds: [String] = []
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        defer { IOObjectRelease(cpus) }
        var iterator: io_iterator_t = 0
        if cpus != 0, IORegistryEntryGetChildIterator(cpus, "IODeviceTree", &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            while case let entry = IOIteratorNext(iterator), entry != 0 {
                defer { IOObjectRelease(entry) }
                let data = IORegistryEntryCreateCFProperty(entry, "cluster-type" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? Data
                kinds.append(data.map { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) } ?? "?")
            }
        }
        if kinds.isEmpty || kinds.contains("?") {
            // Fallback: efficiency cores come first on Apple silicon.
            let e = Sysctl.integer("hw.perflevel1.logicalcpu") ?? 0
            let p = Sysctl.integer("hw.perflevel0.logicalcpu") ?? (Sysctl.integer("hw.logicalcpu") ?? 0)
            kinds = Array(repeating: "E", count: e) + Array(repeating: "P", count: p)
        }
        return kinds.map { ($0, $0 == "E" ? eName : pName) }
    }
}
