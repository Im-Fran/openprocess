import Charts
import SwiftUI

struct OverviewView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(UIState.self) private var ui

    var body: some View {
        let s = monitor.snapshot
        SectionPage {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                tile(.cpu, value: Format.percent(s.cpu.total), detail: "Carga \(s.cpu.loadAverage[0].formatted(.number.precision(.fractionLength(2))))") {
                    HistoryChart(series: [.init(label: "CPU", color: .blue) { $0.cpuUser + $0.cpuSystem }], yDomain: 0...1, format: Format.percent, stacked: true)
                }
                tile(.memory, value: Format.bytes(s.memory.used), detail: "de \(Format.bytes(s.memory.total)) · presión \(Int(s.memory.pressurePercent)) %") {
                    Chart(monitor.history.points) { p in
                        AreaMark(x: .value("Hora", p.date), y: .value("Presión", p.value.memoryPressure))
                            .foregroundStyle(s.memory.pressure.color.gradient)
                    }
                    .chartYScale(domain: 0...100).chartXAxis(.hidden)
                }
                tile(.gpu, value: Format.percent(s.gpu.device), detail: Format.bytes(s.gpu.memoryInUse)) {
                    HistoryChart(series: [.init(label: "GPU", color: .green) { $0.gpu }], yDomain: 0...1, format: Format.percent, stacked: true)
                }
                tile(.energy, value: Format.watts(s.power.system ?? s.power.cpuFromProcesses), detail: "SoC \(Format.celsius(s.power.socTemperature))") {
                    HistoryChart(series: [.init(label: String(localized: "Sistema"), color: .orange) { $0.powerSystem ?? $0.powerCPU }], format: { Format.watts($0) })
                }
                tile(.disk, value: Format.rate(s.disk.readRate + s.disk.writeRate), detail: "↓ \(Format.rate(s.disk.readRate)) ↑ \(Format.rate(s.disk.writeRate))") {
                    HistoryChart(series: [
                        .init(label: String(localized: "Lectura"), color: .blue) { $0.diskRead },
                        .init(label: String(localized: "Escritura"), color: .red) { $0.diskWrite },
                    ], format: Format.rate)
                }
                tile(.network, value: Format.rate(s.network.inRate + s.network.outRate), detail: "↓ \(Format.rate(s.network.inRate)) ↑ \(Format.rate(s.network.outRate))") {
                    HistoryChart(series: [
                        .init(label: String(localized: "Recibido"), color: .blue) { $0.netIn },
                        .init(label: String(localized: "Enviado"), color: .purple) { $0.netOut },
                    ], format: Format.rate)
                }
            }
            HStack(spacing: 32) {
                Stat(label: "Procesos", value: s.processes.count.formatted())
                Stat(label: "Hilos", value: s.processes.reduce(0) { $0 + $1.threads }.formatted())
                Stat(label: "Tiempo encendido", value: Format.uptime(s.uptime))
                Stat(label: "Chip", value: Sysctl.string("machdep.cpu.brand_string") ?? "—")
            }
            .padding(.horizontal, 4)
        }
    }

    private func tile(_ section: AppSection, value: String, detail: String, @ViewBuilder chart: () -> some View) -> some View {
        Button { ui.section = section } label: {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(value).font(.title2).monospacedDigit()
                        Spacer()
                        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    chart().frame(height: 70).chartLegend(.hidden).chartYAxis(.hidden)
                }
            } label: {
                Label(section.title, systemImage: section.symbol).font(.headline)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre la sección")
    }
}
