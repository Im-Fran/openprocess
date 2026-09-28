import Darwin
import XCTest
@testable import OpenProcess

final class SamplingTests: XCTestCase {
    func testRateHandlesMissingAndBackwardsCounters() {
        XCTAssert(ProcessSampler.rate(nil, 100, seconds: 1) == 0)
        XCTAssert(ProcessSampler.rate(200, 100, seconds: 1) == 0)
        XCTAssert(ProcessSampler.rate(100, 300, seconds: 2) == 100)
        XCTAssert(ProcessSampler.rate(100, 300, seconds: 0) == 0)
    }

    func testCpuPercentFromCumulativeTime() {
        let sampler = ProcessSampler()
        let proc = BSDProcess(pid: 42, ppid: 1, uid: 501, comm: "x", start: .distantPast, translated: false)
        func stats(_ ns: UInt64) -> RawProcStats {
            RawProcStats(pid: 42, cpuTimeNs: ns, pCoreTimeNs: ns / 2, footprint: 1, diskRead: 0, diskWrite: 0, energyNJ: ns, wakeups: 0, threads: 3)
        }
        _ = sampler.build(processes: [proc], stats: [42: stats(0)], gpuTime: [42: 0], network: [:], seconds: 1)
        let row = sampler.build(processes: [proc], stats: [42: stats(1_500_000_000)], gpuTime: [42: 500_000_000], network: [:], seconds: 1)[0]
        XCTAssert(abs(row.cpu - 150) < 0.001)       // 1.5 cores busy
        XCTAssert(abs(row.gpu - 50) < 0.001)
        XCTAssert(abs(row.power - 1.5) < 0.001)     // 1.5 J over 1 s
        XCTAssert(row.pCoreShare == 0.5)
        XCTAssert(row.threads == 3)
    }

    func testPidReuseResetsDeltas() {
        let sampler = ProcessSampler()
        let old = BSDProcess(pid: 7, ppid: 1, uid: 501, comm: "a", start: Date(timeIntervalSince1970: 1), translated: false)
        let new = BSDProcess(pid: 7, ppid: 1, uid: 501, comm: "b", start: Date(timeIntervalSince1970: 2), translated: false)
        let s = RawProcStats(pid: 7, cpuTimeNs: 0, pCoreTimeNs: 0, footprint: 0, diskRead: 0, diskWrite: 0, energyNJ: 0, wakeups: 0, threads: 1)
        var t = s; t.cpuTimeNs = 9_000_000_000
        _ = sampler.build(processes: [old], stats: [7: s], gpuTime: [:], network: [:], seconds: 1)
        let row = sampler.build(processes: [new], stats: [7: t], gpuTime: [:], network: [:], seconds: 1)[0]
        XCTAssert(row.cpu == 0)
    }

    func testMemoryBreakdown() {
        var vm = vm_statistics64_data_t()
        vm.internal_page_count = 100
        vm.purgeable_count = 10
        vm.external_page_count = 20
        vm.wire_count = 5
        vm.compressor_page_count = 7
        vm.free_count = 30
        vm.speculative_count = 4
        var snap = MemorySnapshot()
        MemorySampler.apply(vm, pageSize: 2, to: &snap)
        XCTAssert(snap.app == 180)
        XCTAssert(snap.cached == 60)
        XCTAssert(snap.purgeable == 20)
        XCTAssert(snap.wired == 10)
        XCTAssert(snap.compressed == 14)
        XCTAssert(snap.free == 52)
        XCTAssert(snap.used == 204)
    }

    func testParsesGPUClientCreator() {
        XCTAssert(GPUSampler.parsePID("pid 410, WindowServer") == 410)
        XCTAssert(GPUSampler.parsePID("garbage") == nil)
    }

    func testParsesNettopLines() {
        XCTAssert(Nettop.parse(line: "com.apple.WebKi.99399,189176065,84968252,")! == (99399, 189176065, 84968252))
        XCTAssert(Nettop.parse(line: "Discord Helper .31289,3,4,")! == (31289, 3, 4))
        XCTAssert(Nettop.parse(line: ",bytes_in,bytes_out,") == nil)
    }

    func testParsesLsof() {
        let out = """
        COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        zsh     123 fran  cwd    DIR   1,17      640  2 /Users/fran/My Folder
        zsh     123 fran    3u  IPv4 0xabc      0t0  TCP 127.0.0.1:5000 (LISTEN)
        """
        let files = OpenFile.parse(lsof: out)
        XCTAssert(files.count == 2)
        XCTAssert(files[0].name == "/Users/fran/My Folder")
        XCTAssert(files[1].type == "IPv4")
        XCTAssert(files[1].name == "TCP 127.0.0.1:5000 (LISTEN)")
    }

    func testTopologyMatchesLogicalCPUCount() {
        XCTAssert(CPUSampler.readTopology().count == Sysctl.integer("hw.logicalcpu"))
    }

    func testListsAllProcessesIncludingRoot() {
        let all = BSDProcess.all()
        XCTAssert(all.contains { $0.pid == 1 && $0.uid == 0 })
        XCTAssert(all.contains { $0.pid == getpid() })
    }

    @MainActor func testMenuBarGlyphBucketsCoresIntoFive() {
        let cores = (0..<10).map { CoreLoad(id: $0, clusterKind: "E", clusterName: "", user: Double($0) / 10, system: 0) }
        let buckets = MenuBarGlyph.buckets(cores)
        XCTAssert(buckets.count == 5)
        XCTAssert(abs(buckets[0] - 0.05) < 1e-9) // cores 0 and 1
        XCTAssert(abs(buckets[4] - 0.85) < 1e-9) // cores 8 and 9
        XCTAssert(MenuBarGlyph.buckets(Array(cores.prefix(3))).isEmpty)
    }
}
