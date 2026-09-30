import SwiftUI

struct MenuBarLabel: View {
    let monitor: SystemMonitor
    var body: some View {
        let s = monitor.snapshot
        HStack(spacing: 4) {
            Image(nsImage: MenuBarGlyph.image(loads: MenuBarGlyph.buckets(s.cpu.cores)))
            Text("\(Int((s.cpu.total * 100).rounded())) %").monospacedDigit()
        }
        .accessibilityLabel("OpenProcess, CPU \(Int(s.cpu.total * 100)) percent")
    }
}

/// Live version of the brand's menu bar template (assets/brand/assets/menubar):
/// five bars, each the mean load of a group of cores.
enum MenuBarGlyph {
    private static let xs: [CGFloat] = [1, 4.4, 7.8, 11.2, 14.6]
    /// Heights of the static template, used before the first sample.
    private static let idle: [Double] = [6, 12, 3, 10, 7].map { $0 / 12 }

    // ponytail: redrawn per tick without the 0.3 s ease the brand spec suggests; an NSImage
    // label can't animate. Add a custom NSStatusItem view if the motion matters.
    static func image(loads: [Double]) -> NSImage {
        let loads = loads.count == xs.count ? loads : idle
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setFill()
            for (x, load) in zip(xs, loads) {
                let height = 2 + min(1, max(0, load)) * 12 // never shorter than 2 pt
                NSBezierPath(roundedRect: NSRect(x: x, y: 17 - height, width: 2.4, height: height), xRadius: 1.2, yRadius: 1.2).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Splits the cores (in system order) into five contiguous groups and averages each.
    static func buckets(_ cores: [CoreLoad]) -> [Double] {
        guard cores.count >= 5 else { return [] }
        var sums = [Double](repeating: 0, count: 5), counts = [Double](repeating: 0, count: 5)
        for (i, core) in cores.enumerated() {
            let bucket = i * 5 / cores.count
            sums[bucket] += core.total
            counts[bucket] += 1
        }
        return zip(sums, counts).map { $0 / $1 }
    }
}

struct MenuBarView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = monitor.snapshot
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("CPU").foregroundStyle(.secondary)
                    ProgressView(value: min(1, s.cpu.total)).accessibilityHidden(true)
                    Text(Format.percent(s.cpu.total)).monospacedDigit()
                }
                GridRow {
                    Text("GPU").foregroundStyle(.secondary)
                    ProgressView(value: min(1, s.gpu.device)).accessibilityHidden(true)
                    Text(Format.percent(s.gpu.device)).monospacedDigit()
                }
                GridRow {
                    Text("Memory").foregroundStyle(.secondary)
                    ProgressView(value: Double(s.memory.used), total: Double(max(1, s.memory.total))).accessibilityHidden(true)
                    Text(Format.bytes(s.memory.used)).monospacedDigit()
                }
                GridRow {
                    Text("Pressure").foregroundStyle(.secondary)
                    PressureLabel(pressure: s.memory.pressure).gridCellColumns(2)
                }
                GridRow {
                    Text("Network").foregroundStyle(.secondary)
                    Text("↓ \(Format.rate(s.network.inRate))  ↑ \(Format.rate(s.network.outRate))").monospacedDigit().gridCellColumns(2)
                }
                GridRow {
                    Text("Energy").foregroundStyle(.secondary)
                    Text("\(Format.watts(s.power.system ?? s.power.cpuFromProcesses)) · \(Format.celsius(s.power.socTemperature))").monospacedDigit().gridCellColumns(2)
                }
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(s.cpu.cores) { core in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(core.clusterKind == "P" ? Color.accentColor : .teal)
                        .frame(height: max(2, 36 * core.total))
                        .frame(maxHeight: 36, alignment: .bottom)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Usage per Core")
            .accessibilityValue(coreSummary(s.cpu.cores))

            Divider()
            Text("Top CPU Processes").font(.caption).foregroundStyle(.secondary)
            ForEach(s.processes.sorted { $0.cpu > $1.cpu }.prefix(5)) { p in
                HStack {
                    Image(nsImage: ProcessIcon.image(for: p.path)).resizable().frame(width: 16, height: 16).accessibilityHidden(true)
                    Text(p.name).lineLimit(1)
                    Spacer()
                    Text("\(Format.cpu(p.cpu)) %").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Button("Open OpenProcess") {
                    NSApp.setActivationPolicy(.regular)
                    if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        openWindow(id: "main")
                    }
                    NSApp.activate()
                }
                .help("Show the main OpenProcess window")
                Spacer()
                SettingsLink { Text("Settings…") }
                    .help("Open OpenProcess settings")
                Button("Quit") { NSApp.terminate(nil) }
                    .help("Quit OpenProcess completely, including the menu bar icon")
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func coreSummary(_ cores: [CoreLoad]) -> String {
        let loads = cores.map(\.total)
        guard let peak = loads.max() else { return "" }
        let mean = loads.reduce(0, +) / Double(loads.count)
        return String(localized: "\(cores.count) cores, average \(Format.percent(mean)), peak \(Format.percent(peak))")
    }
}
