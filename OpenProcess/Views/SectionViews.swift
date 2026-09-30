import Charts
import SwiftUI

struct CPUView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let cpu = monitor.snapshot.cpu
        SectionPage {
            Card(title: "Uso de CPU") {
                HStack(spacing: 32) {
                    Stat(label: "Usuario", value: Format.percent(cpu.user), color: .blue)
                    Stat(label: "Sistema", value: Format.percent(cpu.system), color: .red)
                    Stat(label: "Inactivo", value: Format.percent(max(0, 1 - cpu.total)))
                    Stat(label: "Carga promedio (1, 5, 15 min)", value: cpu.loadAverage.map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: "  "))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "Sistema"), color: .red) { $0.cpuSystem },
                    .init(label: String(localized: "Usuario"), color: .blue) { $0.cpuUser },
                ], yDomain: 0...1, format: Format.percent, stacked: true)
                .frame(height: 160)
            }

            ForEach(clusters(cpu.cores), id: \.name) { cluster in
                Card(title: "Núcleos \(cluster.name) · \(cluster.cores.count)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(cluster.cores) { CoreTile(core: $0) }
                    }
                }
            }

            TopProcesses(title: "Procesos con más CPU", value: \.cpu) { "\(Format.cpu($0)) %" }
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
                Text("Núcleo \(core.id)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Format.percent(core.total)).font(.caption).monospacedDigit()
            }
            Chart(points) { p in
                AreaMark(x: .value("Hora", p.date), y: .value("Uso", core.id < p.value.cores.count ? p.value.cores[core.id] : 0))
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
        .accessibilityLabel("Núcleo \(core.id), \(core.clusterName)")
        .accessibilityValue(Format.percent(core.total))
    }
}

/// Explains "Purgar memoria" next to the button and in its tooltips.
enum PurgeHelp {
    static var enabled: LocalizedStringKey { "Vaciar la caché de disco y la memoria purgable (ejecuta purge como administrador)" }
    static var disabled: LocalizedStringKey { "Requiere el asistente privilegiado. Instálalo en Ajustes" }
    static var detail: LocalizedStringKey { "“Purgar memoria” vacía la caché de archivos y la memoria purgable, igual que el comando purge. No cierra apps ni borra datos, pero lo que estaba en caché se volverá a leer del disco, así que el Mac puede ir algo más lento durante unos segundos. macOS ya libera esta memoria solo cuando hace falta; úsalo para medir o diagnosticar, no como mantenimiento." }
}

struct MemoryView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(UIState.self) private var ui

    var body: some View {
        let m = monitor.snapshot.memory
        SectionPage {
            Card(title: "Presión de memoria") {
                HStack {
                    PressureLabel(pressure: m.pressure).font(.title3)
                    Spacer()
                    Button("Purgar memoria") {
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
                    AreaMark(x: .value("Hora", p.date), y: .value("Presión", p.value.memoryPressure))
                        .foregroundStyle(m.pressure.color.gradient)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .frame(height: 120)
                .accessibilityLabel("Historial de presión de memoria")
                .accessibilityValue("\(Int(m.pressurePercent)) %")
            }

            Card(title: "Distribución") {
                let parts: [(String, UInt64, Color)] = [
                    (String(localized: "Apps"), m.app, .blue),
                    (String(localized: "Residente"), m.wired, .orange),
                    (String(localized: "Comprimida"), m.compressed, .purple),
                    (String(localized: "En caché"), m.cached - min(m.cached, m.purgeable), .gray),
                    (String(localized: "Purgable"), m.purgeable, .mint),
                    (String(localized: "Libre"), m.free, .secondary.opacity(0.3)),
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
                        Stat(label: "Memoria física", value: Format.bytes(m.total))
                        Stat(label: "Memoria usada", value: Format.bytes(m.used))
                        Stat(label: "Swap usado", value: "\(Format.bytes(m.swapUsed)) de \(Format.bytes(m.swapTotal))")
                    }
                    GridRow {
                        Stat(label: "Apps", value: Format.bytes(m.app), color: .blue)
                        Stat(label: "Residente", value: Format.bytes(m.wired), color: .orange)
                        Stat(label: "Comprimida", value: Format.bytes(m.compressed), color: .purple)
                    }
                    GridRow {
                        Stat(label: "Archivos en caché", value: Format.bytes(m.cached), color: .gray)
                        Stat(label: "Purgable", value: Format.bytes(m.purgeable), color: .mint)
                        Stat(label: "Libre", value: Format.bytes(m.free))
                    }
                }
            }

            Card(title: "Memoria usada") {
                HistoryChart(series: [
                    .init(label: String(localized: "Usada"), color: .blue) { $0.memoryUsed },
                    .init(label: String(localized: "Swap"), color: .orange) { $0.swapUsed },
                ], yDomain: 0...Double(max(m.total, 1)), format: Format.bytes)
                .frame(height: 120)
            }

            TopProcesses(title: "Procesos con más memoria", value: { Double($0.memory) }, format: Format.bytes)
        }
    }
}

struct GPUView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let g = monitor.snapshot.gpu
        SectionPage {
            Card(title: "Uso de GPU") {
                HStack(spacing: 32) {
                    Stat(label: "Dispositivo", value: Format.percent(g.device), color: .accentColor)
                    Stat(label: "Renderizador", value: Format.percent(g.renderer))
                    Stat(label: "Tiler", value: Format.percent(g.tiler))
                    Stat(label: "Memoria en uso", value: Format.bytes(g.memoryInUse))
                }
                HistoryChart(series: [
                    .init(label: "GPU", color: .accentColor) { $0.gpu },
                ], yDomain: 0...1, format: Format.percent, stacked: true)
                .frame(height: 180)
            }
            TopProcesses(title: "Procesos con más GPU", value: \.gpu) { "\(Format.cpu($0)) %" }
        }
    }
}

struct EnergyView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let p = monitor.snapshot.power
        SectionPage {
            Card(title: "Consumo") {
                HStack(spacing: 32) {
                    Stat(label: "Sistema", value: Format.watts(p.system), color: .orange)
                    Stat(label: "CPU (estimado)", value: Format.watts(p.cpuFromProcesses), color: .blue)
                    Stat(label: "GPU", value: Format.watts(p.gpu), color: .cyan)
                    Stat(label: "Temperatura SoC", value: Format.celsius(p.socTemperature))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "Sistema"), color: .orange) { $0.powerSystem },
                    .init(label: "CPU", color: .blue) { $0.powerCPU },
                    .init(label: "GPU", color: .cyan) { $0.powerGPU },
                ], format: { Format.watts($0) })
                .frame(height: 180)
                Text("La energía de CPU es la suma del consumo informado por cada proceso legible\(monitor.helper.isEnabled ? "" : String(localized: " (instala el asistente para incluir procesos del sistema)")).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let b = p.battery {
                Card(title: "Batería") {
                    HStack(spacing: 32) {
                        Stat(label: "Carga", value: "\(b.percent) %")
                        Stat(label: "Estado", value: b.isCharging ? String(localized: "Cargando") : b.onAC ? String(localized: "Conectado") : String(localized: "Batería"))
                        Stat(label: "Tiempo restante", value: b.minutesRemaining.map { Format.uptime(Double($0 * 60)) } ?? "—")
                        Stat(label: "Ciclos", value: b.cycleCount.map { $0.formatted() } ?? "—")
                        Stat(label: "Capacidad máxima", value: b.health.map { "\($0) %" } ?? "—")
                    }
                }
            }

            TopProcesses(title: "Procesos con más consumo", value: \.power) { Format.watts($0) }

            Card(title: "Sensores de temperatura") {
                if p.sensors.isEmpty {
                    Text("No hay sensores disponibles en este Mac.").foregroundStyle(.secondary)
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
            Card(title: "Actividad de disco") {
                HStack(spacing: 32) {
                    Stat(label: "Lectura", value: Format.rate(d.readRate), color: .blue)
                    Stat(label: "Escritura", value: Format.rate(d.writeRate), color: .red)
                    Stat(label: "Operaciones/s", value: "\(Int(d.readOps)) / \(Int(d.writeOps))")
                    Stat(label: "Leído desde el arranque", value: Format.bytes(d.totalRead))
                    Stat(label: "Escrito desde el arranque", value: Format.bytes(d.totalWritten))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "Lectura"), color: .blue) { $0.diskRead },
                    .init(label: String(localized: "Escritura"), color: .red) { $0.diskWrite },
                ], format: Format.rate)
                .frame(height: 180)
            }
            TopProcesses(title: "Procesos con más escritura", value: \.diskWrite, format: Format.rate)
            TopProcesses(title: "Procesos con más lectura", value: \.diskRead, format: Format.rate)
        }
    }
}

struct NetworkView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let n = monitor.snapshot.network
        SectionPage {
            Card(title: "Actividad de red") {
                HStack(spacing: 32) {
                    Stat(label: "Recibido", value: Format.rate(n.inRate), color: .blue)
                    Stat(label: "Enviado", value: Format.rate(n.outRate), color: .purple)
                    Stat(label: "Paquetes/s", value: "\(Int(n.packetsIn)) / \(Int(n.packetsOut))")
                    Stat(label: "Recibido total", value: Format.bytes(n.totalIn))
                    Stat(label: "Enviado total", value: Format.bytes(n.totalOut))
                }
                HistoryChart(series: [
                    .init(label: String(localized: "Recibido"), color: .blue) { $0.netIn },
                    .init(label: String(localized: "Enviado"), color: .purple) { $0.netOut },
                ], format: Format.rate)
                .frame(height: 180)
            }
            TopProcesses(title: "Procesos con más descarga", value: \.netIn, format: Format.rate)
            TopProcesses(title: "Procesos con más subida", value: \.netOut, format: Format.rate)
        }
    }
}
