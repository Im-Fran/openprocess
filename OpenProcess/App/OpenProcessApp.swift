import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Keep sampling for the menu bar extra after the main window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct OpenProcessApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var monitor: SystemMonitor
    @State private var ui = UIState()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    init() {
        let monitor = SystemMonitor()
        monitor.start() // also feeds the menu bar extra when no window is open
        _monitor = State(initialValue: monitor)
    }

    var body: some Scene {
        // WindowGroup (not Window) so a Dock click recreates the window after it was closed.
        WindowGroup("OpenProcess", id: "main") {
            ContentView()
                .environment(monitor)
                .environment(ui)
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {} // single-window app
            AppCommands(monitor: monitor, ui: ui)
        }

        Settings {
            SettingsView()
                .environment(monitor)
        }

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarView()
                .environment(monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        NavigationSplitView {
            List(AppSection.allCases, selection: Binding($ui.section)) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            Group {
                switch ui.section {
                case .overview: OverviewView()
                case .processes: ProcessesView()
                case .cpu: CPUView()
                case .gpu: GPUView()
                case .memory: MemoryView()
                case .energy: EnergyView()
                case .disk: DiskView()
                case .network: NetworkView()
                }
            }
            .navigationTitle(ui.section.title)
        }
        .frame(minWidth: 820, minHeight: 520)
        .alert("No se pudo completar la acción", isPresented: Binding { ui.errorMessage != nil } set: { if !$0 { ui.errorMessage = nil } }) {
            Button("OK") {}
        } message: {
            Text(ui.errorMessage ?? "")
        }
        .confirmationDialog(
            signalTitle,
            isPresented: Binding { ui.pendingSignal != nil } set: { if !$0 { ui.pendingSignal = nil } },
            presenting: ui.pendingSignal
        ) { request in
            switch request.signal {
            case SIGTERM:
                Button("Salir") { ui.signal(SIGTERM, request.pids, monitor: monitor) }
                    .keyboardShortcut(.defaultAction)
                Button("Forzar salida", role: .destructive) { ui.signal(SIGKILL, request.pids, monitor: monitor) }
            case SIGKILL:
                Button("Forzar salida", role: .destructive) { ui.signal(SIGKILL, request.pids, monitor: monitor) }
            default:
                Button("Enviar \(SignalMenu.name(of: request.signal))", role: .destructive) {
                    ui.signal(request.signal, request.pids, monitor: monitor)
                }
            }
        } message: { request in
            switch request.signal {
            case SIGTERM: Text("Si el proceso no responde, puedes forzar su salida.")
            case SIGKILL: Text("Se perderán los cambios sin guardar. El proceso no podrá limpiar sus recursos.")
            case SIGSTOP: Text("El proceso quedará suspendido hasta recibir SIGCONT.")
            default: Text("Los procesos pueden terminar o cambiar de comportamiento al recibir esta señal.")
            }
        }
        .sheet(item: $ui.sampleReport) { SampleReportView(report: $0) }
    }

    private var signalTitle: String {
        guard let request = ui.pendingSignal else { return "" }
        let names = request.pids.compactMap { monitor.process($0)?.name }
        let target = names.count == 1 ? "“\(names[0])”" : String(localized: "\(request.pids.count) procesos")
        return switch request.signal {
        case SIGTERM: String(localized: "¿Seguro que quieres salir de \(target)?")
        case SIGKILL: String(localized: "¿Forzar la salida de \(target)?")
        default: String(localized: "¿Enviar \(SignalMenu.name(of: request.signal)) a \(target)?")
        }
    }
}

struct SampleReportView: View {
    let report: SampleReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView([.vertical, .horizontal]) {
                Text(report.text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Text("Muestra de \(report.name)").foregroundStyle(.secondary)
                Spacer()
                Button("Guardar…", action: save)
                Button("Cerrar") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Muestra de \(report.name).txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try report.text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
