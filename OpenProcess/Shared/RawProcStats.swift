import Darwin

/// Cumulative per-process counters read via `proc_pid_rusage`. Requires same uid or root.
struct RawProcStats: Codable, Sendable, Hashable {
    var pid: Int32
    var cpuTimeNs: UInt64
    var pCoreTimeNs: UInt64
    var footprint: UInt64
    var diskRead: UInt64
    var diskWrite: UInt64
    var energyNJ: UInt64
    var wakeups: UInt64
    var threads: Int32

    static let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (UInt64(info.numer), UInt64(info.denom))
    }()

    static func ns(_ abs: UInt64) -> UInt64 { abs &* timebase.numer / timebase.denom }

    static func read(pid: Int32) -> RawProcStats? {
        var ri = rusage_info_v6()
        let ok = withUnsafeMutablePointer(to: &ri) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) }
        }
        guard ok == 0 else { return nil }
        var ti = proc_taskinfo()
        let n = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, Int32(MemoryLayout<proc_taskinfo>.size))
        return RawProcStats(
            pid: pid,
            cpuTimeNs: ns(ri.ri_user_time + ri.ri_system_time),
            pCoreTimeNs: ns(ri.ri_user_ptime + ri.ri_system_ptime),
            footprint: ri.ri_phys_footprint,
            diskRead: ri.ri_diskio_bytesread,
            diskWrite: ri.ri_diskio_byteswritten,
            energyNJ: ri.ri_energy_nj,
            wakeups: ri.ri_pkg_idle_wkups + ri.ri_interrupt_wkups,
            threads: n > 0 ? ti.pti_threadnum : 0
        )
    }
}
