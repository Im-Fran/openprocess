import AppKit
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview, processes, cpu, gpu, memory, energy, disk, network
    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "Overview"
        case .processes: "Processes"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .energy: "Energy"
        case .disk: "Disk"
        case .network: "Network"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .processes: "list.bullet.rectangle"
        case .cpu: "cpu"
        case .gpu: "display"
        case .memory: "memorychip"
        case .energy: "bolt"
        case .disk: "internaldrive"
        case .network: "network"
        }
    }

    var shortcut: KeyEquivalent { KeyEquivalent(Character(String((Self.allCases.firstIndex(of: self) ?? 0) + 1))) }
}

enum ProcessScope: String, CaseIterable, Identifiable {
    case all, mine, system, others, apps
    var id: Self { self }
    var title: LocalizedStringKey {
        switch self {
        case .all: "All Processes"
        case .mine: "My Processes"
        case .system: "System Processes"
        case .others: "Other Users"
        case .apps: "Windowed Apps"
        }
    }
}

struct SignalRequest: Identifiable {
    let id = UUID()
    let pids: [Int32]
    let signal: Int32
}

struct SampleReport: Identifiable {
    let id = UUID()
    let name: String
    let text: String
}

/// Window-level UI state shared with menu commands.
@MainActor @Observable
final class UIState {
    var section: AppSection = .processes
    var selection: Set<Int32> = []
    var scope: ProcessScope = .all
    var treeMode = false
    var showInspector = false
    var search = ""
    var searchFocused = false
    /// Signal awaiting confirmation; every signal is confirmed, like Activity Monitor.
    var pendingSignal: SignalRequest?
    var errorMessage: String?
    var sampleReport: SampleReport?
    var samplingPID: Int32?

    var selectedPID: Int32? { selection.count == 1 ? selection.first : nil }

    var hiddenColumns: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenColumns), forKey: "hiddenColumns") }
    }
    var sortKey: String {
        didSet { UserDefaults.standard.set(sortKey, forKey: "sortKey") }
    }
    var sortAscending: Bool {
        didSet { UserDefaults.standard.set(sortAscending, forKey: "sortAscending") }
    }

    init() {
        let defaults = UserDefaults.standard
        hiddenColumns = (defaults.array(forKey: "hiddenColumns") as? [String]).map(Set.init)
            ?? Set(ProcessColumn.all.filter(\.hiddenByDefault).map(\.id))
        sortKey = defaults.string(forKey: "sortKey") ?? "cpu"
        sortAscending = defaults.bool(forKey: "sortAscending")
    }

    /// Asks for confirmation before sending a signal.
    func request(_ signal: Int32, _ pids: some Collection<Int32>) {
        guard !pids.isEmpty else { return }
        pendingSignal = SignalRequest(pids: Array(pids), signal: signal)
    }

    func signal(_ signal: Int32, _ pids: some Collection<Int32>, monitor: SystemMonitor) {
        let pids = Array(pids)
        Task {
            var errors: [String] = []
            for pid in pids {
                if let error = await monitor.send(signal, to: pid) {
                    errors.append("\(monitor.process(pid)?.name ?? String(pid)): \(error)")
                }
            }
            if !errors.isEmpty { errorMessage = errors.joined(separator: "\n") }
        }
    }

    func revealInFinder(_ pids: some Collection<Int32>, monitor: SystemMonitor) {
        let urls = pids.compactMap { monitor.process($0)?.path }.map(URL.init(fileURLWithPath:))
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func copyInfo(_ pids: some Collection<Int32>, monitor: SystemMonitor) {
        let text = pids.compactMap(monitor.process).map { p in
            "\(p.name)\tPID \(p.pid)\t\(p.user)\tCPU \(Format.cpu(p.cpu))%\t\(Format.bytes(p.memory))\t\(p.path ?? "")"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Runs `/usr/bin/sample` for 3 seconds and shows the report.
    func sample(_ pid: Int32, monitor: SystemMonitor) {
        guard samplingPID == nil else { return }
        samplingPID = pid
        let name = monitor.process(pid)?.name ?? String(pid)
        Task {
            let result = await Task.detached { () -> Result<String, Error> in
                Result {
                    let out = FileManager.default.temporaryDirectory.appending(path: "openprocess-sample-\(pid).txt")
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
                    p.arguments = [String(pid), "3", "-mayDie", "-file", out.path]
                    p.standardOutput = FileHandle.nullDevice
                    p.standardError = FileHandle.nullDevice
                    try p.run()
                    p.waitUntilExit()
                    defer { try? FileManager.default.removeItem(at: out) }
                    return try String(contentsOf: out, encoding: .utf8)
                }
            }.value
            samplingPID = nil
            switch result {
            case .success(let text): sampleReport = SampleReport(name: name, text: text)
            case .failure: errorMessage = String(localized: "Couldn’t sample \(name). Other users’ processes require privileges.")
            }
        }
    }
}
