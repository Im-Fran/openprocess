import Charts
import SwiftUI

struct OpenFile: Identifiable, Hashable {
    let id: Int
    let fd: String
    let type: String
    let name: String

    /// Parses `lsof -nP -p <pid>` output.
    static func parse(lsof output: String) -> [OpenFile] {
        output.split(separator: "\n").dropFirst().enumerated().compactMap { i, line in
            // COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME — NAME may contain spaces.
            let cols = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
            guard cols.count >= 9 else { return nil }
            let type = String(cols[4])
            // Sockets carry the protocol (TCP/UDP) in NODE.
            let name = type.hasPrefix("IPv") ? "\(cols[7]) \(cols[8])" : String(cols[8])
            return OpenFile(id: i, fd: String(cols[3]), type: type, name: name)
        }
    }
}

struct ProcessInspector: View {
    let pid: Int32
    @Environment(SystemMonitor.self) private var monitor
    @Environment(UIState.self) private var ui
    @State private var arguments: [String] = []
    @State private var openFiles: [OpenFile]?
    @State private var loadingFiles = false

    var body: some View {
        if let p = monitor.process(pid) {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(nsImage: ProcessIcon.image(for: p.path))
                            .resizable().frame(width: 40, height: 40)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(p.name).font(.headline)
                            Text("PID \(String(p.pid)) · \(p.user)").foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Button("Quit…") { ui.request(SIGTERM, [pid]) }
                            .help("Ask the process to quit (SIGTERM); it can save its data first")
                        Button("Force Quit…") { ui.request(SIGKILL, [pid]) }
                            .help("End the process immediately (SIGKILL); unsaved changes are lost")
                        Spacer()
                        Button {
                            ui.sample(pid, monitor: monitor)
                        } label: {
                            if ui.samplingPID == pid { ProgressView().controlSize(.small) } else { Text("Sample") }
                        }
                        .disabled(ui.samplingPID != nil)
                    }
                }

                Section("Activity") {
                    Chart(monitor.processHistory.points) { point in
                        LineMark(x: .value("Time", point.date), y: .value("% CPU", point.value.cpu))
                            .foregroundStyle(Color.accentColor)
                    }
                    .chartYScale(domain: 0...max(100, monitor.processHistory.points.map(\.value.cpu).max() ?? 0))
                    .chartXAxis(.hidden)
                    .frame(height: 80)
                    .overlay {
                        if monitor.processHistory.points.count < 2 {
                            Text("Collecting data…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Process CPU history")
                    .accessibilityValue("\(Format.cpu(p.cpu)) %")
                    LabeledContent("% CPU", value: p.hasStats ? Format.cpu(p.cpu) : "—")
                    LabeledContent("CPU Time", value: p.hasStats ? Format.duration(p.cpuTime) : "—")
                    LabeledContent("On Performance Cores", value: p.pCoreShare.map(Format.percent) ?? "—")
                    LabeledContent("Threads", value: p.hasStats ? p.threads.formatted() : "—")
                    LabeledContent("Memory", value: p.hasStats ? Format.bytes(p.memory) : "—")
                    LabeledContent("% GPU", value: Format.cpu(p.gpu))
                    LabeledContent("Energy", value: p.hasStats ? Format.watts(p.power) : "—")
                    LabeledContent("Wakeups/s", value: p.hasStats ? p.wakeups.formatted(.number.precision(.fractionLength(0))) : "—")
                    LabeledContent("Disk", value: "↓ \(Format.rate(p.diskRead))  ↑ \(Format.rate(p.diskWrite))")
                    LabeledContent("Network", value: "↓ \(Format.rate(p.netIn))  ↑ \(Format.rate(p.netOut))")
                }

                Section("Details") {
                    LabeledContent("Parent Process") {
                        if let parent = monitor.process(p.ppid) {
                            Button("\(parent.name) (\(String(parent.pid)))") { ui.selection = [parent.pid] }
                                .help("Select the parent process")
                                .buttonStyle(.link)
                        } else {
                            Text(String(p.ppid))
                        }
                    }
                    LabeledContent("Kind", value: p.isTranslated ? String(localized: "Intel (Rosetta)") : String(localized: "Apple"))
                    LabeledContent("Started", value: p.startTime.formatted(date: .abbreviated, time: .standard))
                    if let path = p.path {
                        LabeledContent("Path") {
                            Text(path).textSelection(.enabled).lineLimit(3).truncationMode(.middle)
                        }
                    }
                    if !arguments.isEmpty {
                        LabeledContent("Arguments") {
                            Text(arguments.joined(separator: " ")).textSelection(.enabled).lineLimit(6)
                        }
                    }
                }

                Section("Open Files and Ports") {
                    if let openFiles {
                        if openFiles.isEmpty {
                            Text("Not available for this process.").foregroundStyle(.secondary)
                        }
                        ForEach(openFiles.prefix(300)) { file in
                            LabeledContent {
                                Text(file.name).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
                            } label: {
                                Text("\(file.fd) · \(file.type)").monospaced()
                            }
                        }
                    } else {
                        if loadingFiles {
                            ProgressView("Reading open files…").controlSize(.small)
                        } else {
                            Button("Show Files and Ports") { loadOpenFiles() }
                                .help("List the process’s open files and network connections")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .task(id: pid) {
                monitor.inspectedPID = pid
                openFiles = nil
                arguments = await Task.detached { ProcessDetails.arguments(pid: pid) }.value
            }
        } else {
            ContentUnavailableView("The Process Has Quit", systemImage: "xmark.circle")
        }
    }

    private func loadOpenFiles() {
        loadingFiles = true
        Task {
            let output = await Task.detached { () -> String in
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                p.arguments = ["-nP", "-p", String(pid)]
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = FileHandle.nullDevice
                guard (try? p.run()) != nil else { return "" }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                return String(decoding: data, as: UTF8.self)
            }.value
            openFiles = OpenFile.parse(lsof: output)
            loadingFiles = false
        }
    }
}
