import Charts
import SwiftUI

/// Line/area chart over the metrics history.
struct HistoryChart: View {
    struct Series {
        let label: String
        let color: Color
        let value: (Metrics) -> Double?
    }

    let series: [Series]
    var yDomain: ClosedRange<Double>?
    var format: (Double) -> String = { $0.formatted() }
    var stacked = false
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    private static let dashes: [[CGFloat]] = [[], [6, 3], [2, 2], [8, 3, 2, 3]]

    var body: some View {
        let points = monitor.history.points
        Chart {
            ForEach(series.indices, id: \.self) { i in
                let s = series[i]
                ForEach(points) { point in
                    if let v = s.value(point.value) {
                        if stacked {
                            AreaMark(x: .value("Time", point.date), y: .value(s.label, v), stacking: .standard)
                                .foregroundStyle(by: .value("Series", s.label))
                        } else {
                            LineMark(x: .value("Time", point.date), y: .value(s.label, v))
                                .foregroundStyle(by: .value("Series", s.label))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: differentiateWithoutColor ? Self.dashes[i % Self.dashes.count] : []))
                                .interpolationMethod(.monotone)
                        }
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: series.map(\.label), range: series.map(\.color))
        .chartYScale(domain: yDomain ?? 0...max(1, maxValue(points)))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { if let v = value.as(Double.self) { Text(format(v)) } }
            }
        }
        .chartXAxis(.hidden)
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .accessibilityLabel(Text(series.map(\.label).joined(separator: ", ")))
        .accessibilityValue(Text(series.map { s in "\(s.label): \(points.last.flatMap { s.value($0.value) }.map(format) ?? "—")" }.joined(separator: ", ")))
    }

    private func maxValue(_ points: [History<Metrics>.Point]) -> Double {
        if stacked { return points.map { p in series.compactMap { $0.value(p.value) }.reduce(0, +) }.max() ?? 0 }
        return points.flatMap { p in series.compactMap { $0.value(p.value) } }.max() ?? 0
    }
}

/// Titled container used by every section.
struct Card<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox {
            content.frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title).font(.headline)
        }
    }
}

/// Large number with caption, used in stat grids.
struct Stat: View {
    let label: LocalizedStringKey
    let value: String
    var color: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let color {
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
                }
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(value).font(.title3).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Top N processes ranked by a metric.
struct TopProcesses: View {
    let title: LocalizedStringKey
    let value: (ProcessRow) -> Double
    let format: (Double) -> String
    var count = 8
    @Environment(SystemMonitor.self) private var monitor
    @Environment(UIState.self) private var ui

    var body: some View {
        let top = monitor.snapshot.processes.filter { value($0) > 0 }.sorted { value($0) > value($1) }.prefix(count)
        Card(title: title) {
            if top.isEmpty {
                Text("No Activity").foregroundStyle(.secondary)
            }
            ForEach(Array(top)) { p in
                Button {
                    ui.section = .processes
                    ui.selection = [p.pid]
                    ui.showInspector = true
                } label: {
                    HStack {
                        Image(nsImage: ProcessIcon.image(for: p.path)).resizable().frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                        Text(p.name).lineLimit(1)
                        Spacer()
                        Text(format(value(p))).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Show in Processes")
            }
        }
    }
}

/// Scrollable section page.
struct SectionPage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(20)
        }
    }
}

/// Status text stays `.primary` for contrast; only the icon carries the color.
struct StatusLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: Color

    init(_ title: LocalizedStringKey, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(color) }
    }
}

struct PressureLabel: View {
    let pressure: MemoryPressure
    var body: some View {
        StatusLabel(pressure.title, symbol: pressure.symbol, color: pressure.color)
    }
}

extension MemoryPressure {
    var color: Color {
        switch self {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }

    var symbol: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }
}
