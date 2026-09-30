import Charts
import SwiftUI

struct CPUView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let cpu = monitor.snapshot.cpu
        SectionPage {
            Card(title: "CPU Usage") {
                HStack(spacing: 32) {
                    Stat(label: "User", value: Format.percent(cpu.user), color: .blue)
                    Stat(label: "System", value: Format.percent(cpu.system), color: .red)
                    Stat(label: "Idle", value: Format.percent(max(0, 1 - cpu.total)))
                    Stat(label: "Load Average (1, 5, 15 min)", value: cpu.loadAverage.map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: "  "))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "System"), color: .red) { $0.cpuSystem },
                    .init(label: String(localized: "User"), color: .blue) { $0.cpuUser },
                ], yDomain: 0...1, format: Format.percent, stacked: true)
                .frame(height: 160)
            }

            ForEach(clusters(cpu.cores), id: \.name) { cluster in
                Card(title: "\(cluster.name) Cores · \(cluster.cores.count)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(cluster.cores) { CoreTile(core: $0) }
                    }
                }
            }

            TopProcesses(title: "Top CPU Processes", value: \.cpu) { "\(Format.cpu($0)) %" }
        }
    }

    private func clusters(_ cores: [CoreLoad]) -> [(name: String, cores: [CoreLoad])] {
        // Performance clusters first.
        let order = cores.map(\.clusterName).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return order
            .map { name in (name, cores.filter { $0.clusterName == name }) }
            .sorted { ($0.cores.first?.clusterKind == "P" ? 0 : 1) < ($1.cores.first?.clusterKind == "P" ? 0 : 1) }
    }
}

struct CoreTile: View {
    let core: CoreLoad
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let points = monitor.history.points
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Core \(core.id)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Format.percent(core.total)).font(.caption).monospacedDigit()
            }
            Chart(points) { p in
                AreaMark(x: .value("Time", p.date), y: .value("Usage", core.id < p.value.cores.count ? p.value.cores[core.id] : 0))
                    .foregroundStyle(core.clusterKind == "P" ? Color.accentColor.gradient : Color.teal.gradient)
            }
            .chartYScale(domain: 0...1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 44)
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Core \(core.id), \(core.clusterName)")
        .accessibilityValue(Format.percent(core.total))
    }
}

/// Explains "Purge Memory" next to the button and in its tooltips.
enum PurgeHelp {
    static var enabled: LocalizedStringKey { "Flush the disk cache and purgeable memory (runs purge as administrator)" }
    static var disabled: LocalizedStringKey { "Requires the privileged helper. Install it in Settings" }
    static var detail: LocalizedStringKey { "“Purge Memory” flushes the file cache and purgeable memory, just like the purge command. It doesn’t quit apps or delete data, but anything that was cached will be read from disk again, so your Mac may be a bit slower for a few seconds. macOS already frees this memory on its own when needed; use it for measuring or diagnosing, not as maintenance." }
}

struct MemoryView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(UIState.self) private var ui

    var body: some View {
        let m = monitor.snapshot.memory
        SectionPage {
            Card(title: "Memory Pressure") {
                HStack {
                    PressureLabel(pressure: m.pressure).font(.title3)
                    Spacer()
                    Button("Purge Memory") {
                        Task { if let error = await monitor.purgeMemory() { ui.errorMessage = error } }
                    }
                    .disabled(!monitor.helper.isEnabled)
                    .help(monitor.helper.isEnabled ? PurgeHelp.enabled : PurgeHelp.disabled)
                }
                Text(PurgeHelp.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Chart(monitor.history.points) { p in
                    AreaMark(x: .value("Time", p.date), y: .value("Pressure", p.value.memoryPressure))
                        .foregroundStyle(m.pressure.color.gradient)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .frame(height: 120)
                .accessibilityLabel("Memory pressure history")
                .accessibilityValue("\(Int(m.pressurePercent)) %")
            }

            Card(title: "Breakdown") {
                let parts: [(String, UInt64, Color)] = [
                    (String(localized: "Apps"), m.app, .blue),
                    (String(localized: "Wired"), m.wired, .orange),
                    (String(localized: "Compressed"), m.compressed, .purple),
                    (String(localized: "Cached"), m.cached - min(m.cached, m.purgeable), .gray),
                    (String(localized: "Purgeable"), m.purgeable, .mint),
                    (String(localized: "Free"), m.free, .secondary.opacity(0.3)),
                ]
                Chart(parts, id: \.0) { part in
                    BarMark(x: .value("Bytes", Double(part.1)))
                        .foregroundStyle(part.2)
                }
                .chartXScale(domain: 0...Double(max(m.total, 1)))
                .chartXAxis(.hidden)
                .frame(height: 24)
                .accessibilityHidden(true)
                Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 10) {
                    GridRow {
                        Stat(label: "Physical Memory", value: Format.bytes(m.total))
                        Stat(label: "Memory Used", value: Format.bytes(m.used))
                        Stat(label: "Swap Used", value: String(localized: "\(Format.bytes(m.swapUsed)) of \(Format.bytes(m.swapTotal))"))
                    }
                    GridRow {
                        Stat(label: "Apps", value: Format.bytes(m.app), color: .blue)
                        Stat(label: "Wired", value: Format.bytes(m.wired), color: .orange)
                        Stat(label: "Compressed", value: Format.bytes(m.compressed), color: .purple)
                    }
                    GridRow {
                        Stat(label: "Cached Files", value: Format.bytes(m.cached), color: .gray)
                        Stat(label: "Purgeable", value: Format.bytes(m.purgeable), color: .mint)
                        Stat(label: "Free", value: Format.bytes(m.free))
                    }
                }
            }

            Card(title: "Memory Used") {
                HistoryChart(series: [
                    .init(label: String(localized: "Used"), color: .blue) { $0.memoryUsed },
                    .init(label: String(localized: "Swap"), color: .orange) { $0.swapUsed },
                ], yDomain: 0...Double(max(m.total, 1)), format: Format.bytes)
                .frame(height: 120)
            }

            TopProcesses(title: "Top Memory Processes", value: { Double($0.memory) }, format: Format.bytes)
        }
    }
}

struct GPUView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let g = monitor.snapshot.gpu
        SectionPage {
            Card(title: "GPU Usage") {
                HStack(spacing: 32) {
                    Stat(label: "Device", value: Format.percent(g.device), color: .accentColor)
                    Stat(label: "Renderer", value: Format.percent(g.renderer))
                    Stat(label: "Tiler", value: Format.percent(g.tiler))
                    Stat(label: "Memory in Use", value: Format.bytes(g.memoryInUse))
                }
                HistoryChart(series: [
                    .init(label: "GPU", color: .accentColor) { $0.gpu },
                ], yDomain: 0...1, format: Format.percent, stacked: true)
                .frame(height: 180)
            }
            TopProcesses(title: "Top GPU Processes", value: \.gpu) { "\(Format.cpu($0)) %" }
        }
    }
}

struct EnergyView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let p = monitor.snapshot.power
        SectionPage {
            Card(title: "Power") {
                HStack(spacing: 32) {
                    Stat(label: "System", value: Format.watts(p.system), color: .orange)
                    Stat(label: "CPU (Estimated)", value: Format.watts(p.cpuFromProcesses), color: .blue)
                    Stat(label: "GPU", value: Format.watts(p.gpu), color: .cyan)
                    Stat(label: "SoC Temperature", value: Format.celsius(p.socTemperature))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "System"), color: .orange) { $0.powerSystem },
                    .init(label: "CPU", color: .blue) { $0.powerCPU },
                    .init(label: "GPU", color: .cyan) { $0.powerGPU },
                ], format: { Format.watts($0) })
                .frame(height: 180)
                Text(monitor.helper.isEnabled ? "CPU energy is the sum of the power reported by each readable process." as LocalizedStringKey : "CPU energy is the sum of the power reported by each readable process (install the helper to include system processes).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let b = p.battery {
                Card(title: "Battery") {
                    HStack(spacing: 32) {
                        Stat(label: "Charge", value: "\(b.percent) %")
                        Stat(label: "Status", value: b.isCharging ? String(localized: "Charging") : b.onAC ? String(localized: "Plugged In") : String(localized: "Battery"))
                        Stat(label: "Time Remaining", value: b.minutesRemaining.map { Format.uptime(Double($0 * 60)) } ?? "—")
                        Stat(label: "Cycles", value: b.cycleCount.map { $0.formatted() } ?? "—")
                        Stat(label: "Maximum Capacity", value: b.health.map { "\($0) %" } ?? "—")
                    }
                }
            }

            TopProcesses(title: "Top Energy Processes", value: \.power) { Format.watts($0) }

            Card(title: "Temperature Sensors") {
                if p.sensors.isEmpty {
                    Text("No sensors available on this Mac.").foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(p.sensors) { s in
                            LabeledContent(s.name, value: Format.celsius(s.celsius)).monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}

struct DiskView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let d = monitor.snapshot.disk
        SectionPage {
            Card(title: "Disk Activity") {
                HStack(spacing: 32) {
                    Stat(label: "Read", value: Format.rate(d.readRate), color: .blue)
                    Stat(label: "Write", value: Format.rate(d.writeRate), color: .red)
                    Stat(label: "Operations/s", value: "\(Int(d.readOps)) / \(Int(d.writeOps))")
                    Stat(label: "Read Since Boot", value: Format.bytes(d.totalRead))
                    Stat(label: "Written Since Boot", value: Format.bytes(d.totalWritten))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "Read"), color: .blue) { $0.diskRead },
                    .init(label: String(localized: "Write"), color: .red) { $0.diskWrite },
                ], format: Format.rate)
                .frame(height: 180)
            }
            TopProcesses(title: "Top Writing Processes", value: \.diskWrite, format: Format.rate)
            TopProcesses(title: "Top Reading Processes", value: \.diskRead, format: Format.rate)
        }
    }
}

struct NetworkView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let n = monitor.snapshot.network
        SectionPage {
            Card(title: "Network Activity") {
                HStack(spacing: 32) {
                    Stat(label: "Received", value: Format.rate(n.inRate), color: .blue)
                    Stat(label: "Sent", value: Format.rate(n.outRate), color: .purple)
                    Stat(label: "Packets/s", value: "\(Int(n.packetsIn)) / \(Int(n.packetsOut))")
                    Stat(label: "Total Received", value: Format.bytes(n.totalIn))
                    Stat(label: "Total Sent", value: Format.bytes(n.totalOut))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "Received"), color: .blue) { $0.netIn },
                    .init(label: String(localized: "Sent"), color: .purple) { $0.netOut },
                ], format: Format.rate)
                .frame(height: 180)
            }
            TopProcesses(title: "Top Download Processes", value: \.netIn, format: Format.rate)
            TopProcesses(title: "Top Upload Processes", value: \.netOut, format: Format.rate)
        }
    }
}
