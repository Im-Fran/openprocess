import Darwin
import Foundation

final class NetworkSampler {
    private var previous: (ib: UInt64, ob: UInt64, ip: UInt64, op: UInt64)?

    /// System-wide counters from `NET_RT_IFLIST2` (64-bit, no wraparound), excluding loopback.
    func sample(seconds: Double) -> NetworkSnapshot {
        var ib: UInt64 = 0, ob: UInt64 = 0, ip: UInt64 = 0, op: UInt64 = 0
        if let bytes = Sysctl.data([CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]) {
            bytes.withUnsafeBytes { raw in
                var offset = 0
                while offset + MemoryLayout<if_msghdr>.size <= raw.count {
                    let hdr = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                    guard hdr.ifm_msglen > 0 else { break }
                    if Int32(hdr.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= raw.count {
                        let msg = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                        if msg.ifm_flags & IFF_LOOPBACK == 0 {
                            ib += msg.ifm_data.ifi_ibytes; ob += msg.ifm_data.ifi_obytes
                            ip += msg.ifm_data.ifi_ipackets; op += msg.ifm_data.ifi_opackets
                        }
                    }
                    offset += Int(hdr.ifm_msglen)
                }
            }
        }
        defer { previous = (ib, ob, ip, op) }
        return NetworkSnapshot(
            inRate: ProcessSampler.rate(previous?.ib, ib, seconds: seconds),
            outRate: ProcessSampler.rate(previous?.ob, ob, seconds: seconds),
            packetsIn: ProcessSampler.rate(previous?.ip, ip, seconds: seconds),
            packetsOut: ProcessSampler.rate(previous?.op, op, seconds: seconds),
            totalIn: ib, totalOut: ob
        )
    }
}

/// Per-process cumulative bytes of live flows from `nettop` (the only non-private source for them).
enum Nettop {
    // ponytail: one ~30 ms `nettop -L 1` run per tick; streaming mode (`-L 0`) spins at >100 % CPU.
    static func sample() -> [Int32: (in: UInt64, out: UInt64)] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        p.arguments = ["-P", "-L", "1", "-n", "-x", "-J", "bytes_in,bytes_out"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [:] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        var result: [Int32: (in: UInt64, out: UInt64)] = [:]
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            if let (pid, i, o) = parse(line: String(line)) { result[pid] = (i, o) }
        }
        return result
    }

    /// Parses `"name.with.dots.123,456,789,"`.
    static func parse(line: String) -> (Int32, UInt64, UInt64)? {
        let cols = line.split(separator: ",", omittingEmptySubsequences: false)
        guard cols.count >= 3, let dot = cols[0].lastIndex(of: "."),
              let pid = Int32(cols[0][cols[0].index(after: dot)...]),
              let i = UInt64(cols[1]), let o = UInt64(cols[2]) else { return nil }
        return (pid, i, o)
    }
}
