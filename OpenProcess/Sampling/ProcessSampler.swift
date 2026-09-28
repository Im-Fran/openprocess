import Darwin
import Foundation

/// Minimal per-process info readable for every process without privileges (`KERN_PROC_ALL`).
struct BSDProcess: Sendable {
    let pid: Int32
    let ppid: Int32
    let uid: UInt32
    let comm: String
    let start: Date
    let translated: Bool

    static func all() -> [BSDProcess] {
        guard let bytes = Sysctl.data([CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]) else { return [] }
        let count = bytes.count / MemoryLayout<kinfo_proc>.stride
        return bytes.withUnsafeBytes { raw in
            raw.bindMemory(to: kinfo_proc.self).prefix(count).compactMap { kp in
                let pid = kp.kp_proc.p_pid
                guard pid >= 0 else { return nil }
                let tv = kp.kp_proc.p_un.__p_starttime
                return BSDProcess(
                    pid: pid,
                    ppid: kp.kp_eproc.e_ppid,
                    uid: kp.kp_eproc.e_ucred.cr_uid,
                    comm: pid == 0 ? "kernel_task" : String(tuple: kp.kp_proc.p_comm),
                    start: Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1e6),
                    translated: kp.kp_proc.p_flag & P_TRANSLATED != 0
                )
            }
        }
    }
}

final class ProcessSampler {
    private struct Previous {
        let start: Date
        let stats: RawProcStats?
        let gpuNs: UInt64?
        let net: (in: UInt64, out: UInt64)?
    }

    private var previous: [Int32: Previous] = [:]
    private var pathCache: [Int32: (start: Date, path: String?)] = [:]
    private var userCache: [UInt32: String] = [:]

    /// Per-second rate of a cumulative counter; 0 if it went backwards.
    static func rate(_ old: UInt64?, _ new: UInt64, seconds: Double) -> Double {
        guard let old, new >= old, seconds > 0 else { return 0 }
        return Double(new - old) / seconds
    }

    func build(
        processes: [BSDProcess],
        stats: [Int32: RawProcStats],
        gpuTime: [Int32: UInt64],
        network: [Int32: (in: UInt64, out: UInt64)],
        seconds: Double
    ) -> [ProcessRow] {
        var next: [Int32: Previous] = [:]
        let rows = processes.map { p -> ProcessRow in
            let prev = previous[p.pid].flatMap { $0.start == p.start ? $0 : nil }
            let s = stats[p.pid]
            let gpuNs = gpuTime[p.pid]
            let net = network[p.pid]
            next[p.pid] = Previous(start: p.start, stats: s, gpuNs: gpuNs, net: net)

            let path = self.path(for: p)
            var row = ProcessRow(
                pid: p.pid, ppid: p.ppid, uid: p.uid,
                name: path.map { ($0 as NSString).lastPathComponent } ?? p.comm,
                path: path, user: user(for: p.uid),
                startTime: p.start, isTranslated: p.translated
            )
            if let gpuNs {
                row.gpu = Self.rate(prev?.gpuNs, gpuNs, seconds: seconds) / 1e9 * 100
            }
            if let net {
                row.netIn = Self.rate(prev?.net?.in, net.in, seconds: seconds)
                row.netOut = Self.rate(prev?.net?.out, net.out, seconds: seconds)
            }
            guard let s else { return row }
            let old = prev?.stats
            row.hasStats = true
            row.cpu = Self.rate(old?.cpuTimeNs, s.cpuTimeNs, seconds: seconds) / 1e9 * 100
            if let old, s.cpuTimeNs > old.cpuTimeNs, s.pCoreTimeNs >= old.pCoreTimeNs {
                row.pCoreShare = min(1, Double(s.pCoreTimeNs - old.pCoreTimeNs) / Double(s.cpuTimeNs - old.cpuTimeNs))
            }
            row.cpuTime = Double(s.cpuTimeNs) / 1e9
            row.threads = Int(s.threads)
            row.memory = s.footprint
            row.diskRead = Self.rate(old?.diskRead, s.diskRead, seconds: seconds)
            row.diskWrite = Self.rate(old?.diskWrite, s.diskWrite, seconds: seconds)
            row.power = Self.rate(old?.energyNJ, s.energyNJ, seconds: seconds) / 1e9
            row.wakeups = Self.rate(old?.wakeups, s.wakeups, seconds: seconds)
            return row
        }
        previous = next
        pathCache = pathCache.filter { next[$0.key] != nil }
        return rows
    }

    private func path(for p: BSDProcess) -> String? {
        if let cached = pathCache[p.pid], cached.start == p.start { return cached.path }
        var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let path = proc_pidpath(p.pid, &buf, UInt32(buf.count)) > 0 ? String(nulTerminated: buf) : nil
        pathCache[p.pid] = (p.start, path)
        return path
    }

    private func user(for uid: UInt32) -> String {
        if let name = userCache[uid] { return name }
        let name = getpwuid(uid).flatMap { String(validatingCString: $0.pointee.pw_name) } ?? String(uid)
        userCache[uid] = name
        return name
    }
}

/// Details fetched on demand for the inspector.
enum ProcessDetails {
    static func arguments(pid: Int32) -> [String] {
        guard let bytes = Sysctl.data([CTL_KERN, KERN_PROCARGS2, pid]), bytes.count > 4 else { return [] }
        let argc = bytes.withUnsafeBytes { $0.load(as: Int32.self) }
        // Layout: argc, exec path, NULs, argv..., envp...
        var parts = bytes[4...].split(separator: 0, omittingEmptySubsequences: true).map { String(decoding: $0, as: UTF8.self) }
        parts.removeFirst(min(1, parts.count)) // exec path
        return Array(parts.prefix(Int(argc)))
    }
}
