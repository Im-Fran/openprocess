import Foundation

struct ProcessRow: Identifiable, Hashable, Sendable {
    var id: Int32 { pid }
    let pid: Int32
    let ppid: Int32
    let uid: UInt32
    var name: String
    var path: String?
    var user: String
    var startTime: Date
    var isTranslated: Bool
    /// False when the process belongs to another user and the helper isn't available.
    var hasStats = false
    /// Percent of one core (can exceed 100).
    var cpu: Double = 0
    /// Share of CPU time spent on performance cores (0...1).
    var pCoreShare: Double?
    var cpuTime: TimeInterval = 0
    var threads: Int = 0
    var memory: UInt64 = 0
    var diskRead: Double = 0
    var diskWrite: Double = 0
    /// Watts.
    var power: Double = 0
    var wakeups: Double = 0
    var gpu: Double = 0
    var netIn: Double = 0
    var netOut: Double = 0

    var isSystem: Bool { uid == 0 || uid < 500 }
}

struct CoreLoad: Identifiable, Hashable, Sendable {
    let id: Int
    let clusterKind: String   // "P" / "E"
    let clusterName: String   // e.g. "Super", "Efficiency"
    var user: Double
    var system: Double
    var total: Double { user + system }
}

struct CPUSnapshot: Sendable {
    var user = 0.0
    var system = 0.0
    var total: Double { user + system }
    var cores: [CoreLoad] = []
    var loadAverage: [Double] = [0, 0, 0]
}

enum MemoryPressure: Int, Sendable {
    case normal = 1, warning = 2, critical = 4
}

struct MemorySnapshot: Sendable {
    var total: UInt64 = 0
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var purgeable: UInt64 = 0
    var free: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    var pressure: MemoryPressure = .normal
    /// 0...100, derived from `kern.memorystatus_level`.
    var pressurePercent: Double = 0
    var used: UInt64 { app + wired + compressed }
}

struct GPUSnapshot: Sendable {
    var device = 0.0
    var renderer = 0.0
    var tiler = 0.0
    var memoryInUse: UInt64 = 0
}

struct IOSnapshot: Sendable {
    var readRate = 0.0
    var writeRate = 0.0
    var readOps = 0.0
    var writeOps = 0.0
    var totalRead: UInt64 = 0
    var totalWritten: UInt64 = 0
}

struct NetworkSnapshot: Sendable {
    var inRate = 0.0
    var outRate = 0.0
    var packetsIn = 0.0
    var packetsOut = 0.0
    var totalIn: UInt64 = 0
    var totalOut: UInt64 = 0
}

struct TemperatureSensor: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let celsius: Double
}

struct BatteryInfo: Sendable {
    var percent: Int
    var isCharging: Bool
    var onAC: Bool
    var minutesRemaining: Int?
    var cycleCount: Int?
    var health: Int?
}

struct PowerSnapshot: Sendable {
    var system: Double?
    var gpu: Double?
    /// Sum of per-process CPU energy (only processes we can read).
    var cpuFromProcesses = 0.0
    var battery: BatteryInfo?
    var sensors: [TemperatureSensor] = []
    var socTemperature: Double? {
        let dies = sensors.filter { $0.name.contains("tdie") }
        return dies.isEmpty ? nil : dies.map(\.celsius).reduce(0, +) / Double(dies.count)
    }
}

struct SystemSnapshot: Sendable {
    var date = Date()
    var cpu = CPUSnapshot()
    var memory = MemorySnapshot()
    var gpu = GPUSnapshot()
    var disk = IOSnapshot()
    var network = NetworkSnapshot()
    var power = PowerSnapshot()
    var processes: [ProcessRow] = []
    var uptime: TimeInterval = 0
}
