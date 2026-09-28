import Darwin

enum MemorySampler {
    static let totalMemory = UInt64(Sysctl.integer("hw.memsize") ?? 0)

    static func sample() -> MemorySnapshot {
        var snap = MemorySnapshot()
        snap.total = totalMemory
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let ok = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if ok == KERN_SUCCESS { apply(stats, pageSize: UInt64(sysconf(_SC_PAGESIZE)), to: &snap) }

        if let swap = Sysctl.value("vm.swapusage", as: xsw_usage.self) {
            snap.swapUsed = swap.xsu_used
            snap.swapTotal = swap.xsu_total
        }
        snap.pressure = MemoryPressure(rawValue: Sysctl.integer("kern.memorystatus_vm_pressure_level") ?? 1) ?? .normal
        if let level = Sysctl.integer("kern.memorystatus_level") {
            snap.pressurePercent = Double(100 - min(100, max(0, level)))
        }
        return snap
    }

    /// Activity Monitor–style breakdown.
    static func apply(_ s: vm_statistics64_data_t, pageSize: UInt64, to snap: inout MemorySnapshot) {
        let internalPages = UInt64(s.internal_page_count)
        let purgeable = UInt64(s.purgeable_count)
        let external = UInt64(s.external_page_count)
        snap.app = (internalPages &- min(internalPages, purgeable)) * pageSize
        snap.wired = UInt64(s.wire_count) * pageSize
        snap.compressed = UInt64(s.compressor_page_count) * pageSize
        snap.purgeable = purgeable * pageSize
        snap.cached = (external + purgeable) * pageSize
        snap.free = UInt64(s.free_count &- min(s.free_count, s.speculative_count)) * pageSize
    }
}
