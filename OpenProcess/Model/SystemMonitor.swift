import AppKit
import Foundation

/// Scalar metrics kept over time for charts.
struct Metrics: Sendable {
    var cpuUser = 0.0
    var cpuSystem = 0.0
    var cores: [Double] = []
    var memoryPressure = 0.0
    var memoryUsed = 0.0
    var swapUsed = 0.0
    var gpu = 0.0
    var diskRead = 0.0
    var diskWrite = 0.0
    var netIn = 0.0
    var netOut = 0.0
    var powerSystem: Double?
    var powerGPU: Double?
    var powerCPU = 0.0
    var temperature: Double?
}

/// Samples the whole system off the main thread.
actor Sampler {
    private let processes = ProcessSampler()
    private let cpu = CPUSampler()
    private let disk = DiskSampler()
    private let network = NetworkSampler()
    private let power = PowerSampler()
    private var last: ContinuousClock.Instant?

    nonisolated var topology: [(kind: String, name: String)] { CPUSampler.readTopology() }

    func sample(helper: HelperClient) async -> SystemSnapshot {
        let now = ContinuousClock.now
        let seconds = last.map { (now - $0) / .seconds(1) } ?? 0
        last = now

        let list = BSDProcess.all()
        var stats: [Int32: RawProcStats] = [:]
        var missing: [Int32] = []
        for p in list {
            if let s = RawProcStats.read(pid: p.pid) { stats[p.pid] = s } else { missing.append(p.pid) }
        }
        for s in await helper.stats(for: missing) { stats[s.pid] = s }

        async let perProcessNetwork = Task.detached { Nettop.sample() }.value
        let (gpu, gpuPerPID) = GPUSampler.sample()
        var snap = SystemSnapshot()
        snap.cpu = cpu.sample()
        snap.memory = MemorySampler.sample()
        snap.gpu = gpu
        snap.disk = disk.sample(seconds: seconds)
        snap.network = network.sample(seconds: seconds)
        snap.power = power.sample(seconds: seconds)
        snap.processes = processes.build(
            processes: list, stats: stats, gpuTime: gpuPerPID, network: await perProcessNetwork, seconds: seconds
        )
        snap.power.cpuFromProcesses = snap.processes.reduce(0) { $0 + $1.power }
        if let boot = Sysctl.value("kern.boottime", as: timeval.self) {
            snap.uptime = Date().timeIntervalSince1970 - Double(boot.tv_sec)
        }
        return snap
    }
}

@MainActor @Observable
final class SystemMonitor {
    private(set) var snapshot = SystemSnapshot()
    private(set) var history = History<Metrics>()
    /// CPU % and memory of the inspected process.
    private(set) var processHistory = History<(cpu: Double, memory: Double)>(capacity: 60)
    var inspectedPID: Int32? {
        didSet { if inspectedPID != oldValue { processHistory = .init(capacity: 60) } }
    }
    private(set) var hasSampled = false

    var interval: Double {
        didSet {
            UserDefaults.standard.set(interval, forKey: "interval")
        }
    }

    let helper = HelperClient()
    private let sampler = Sampler()
    @ObservationIgnored private var task: Task<Void, Never>?

    init() {
        let saved = UserDefaults.standard.double(forKey: "interval")
        interval = saved > 0 ? saved : 2
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let snap = await self.sampler.sample(helper: self.helper)
                self.apply(snap)
                try? await Task.sleep(for: .seconds(self.interval))
            }
        }
    }

    private func apply(_ snap: SystemSnapshot) {
        let first = !hasSampled
        snapshot = snap
        hasSampled = true
        guard !first else { return } // first sample has no deltas
        history.append(Metrics(
            cpuUser: snap.cpu.user, cpuSystem: snap.cpu.system,
            cores: snap.cpu.cores.map(\.total),
            memoryPressure: snap.memory.pressurePercent,
            memoryUsed: Double(snap.memory.used), swapUsed: Double(snap.memory.swapUsed),
            gpu: snap.gpu.device,
            diskRead: snap.disk.readRate, diskWrite: snap.disk.writeRate,
            netIn: snap.network.inRate, netOut: snap.network.outRate,
            powerSystem: snap.power.system, powerGPU: snap.power.gpu, powerCPU: snap.power.cpuFromProcesses,
            temperature: snap.power.socTemperature
        ), at: snap.date)
        if let pid = inspectedPID, let row = snap.processes.first(where: { $0.pid == pid }) {
            processHistory.append((row.cpu, Double(row.memory)), at: snap.date)
        }
    }

    func process(_ pid: Int32) -> ProcessRow? { snapshot.processes.first { $0.pid == pid } }

    /// Sends a signal directly, falling back to the privileged helper on EPERM.
    /// Returns an error message, or nil on success.
    func send(_ signal: Int32, to pid: Int32) async -> String? {
        if kill(pid, signal) == 0 { return nil }
        var code = errno
        if code == EPERM, let result = await helper.sendSignal(signal, to: pid) {
            code = result
            if code == 0 { return nil }
        }
        if code == EPERM && !helper.isEnabled {
            return String(localized: "Permiso denegado. Instala el asistente en Ajustes para gestionar procesos de otros usuarios.")
        }
        return String(cString: strerror(code))
    }

    func purgeMemory() async -> String? {
        guard let status = await helper.purgeMemory() else {
            return String(localized: "Purgar la memoria requiere el asistente privilegiado. Instálalo en Ajustes.")
        }
        return status == 0 ? nil : String(localized: "purge terminó con el código \(status).")
    }
}
