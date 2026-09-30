import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Keep sampling for the menu bar extra after the main window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// "Menu bar only": drop the Dock icon once the last regular window closes.
    /// ContentView and the menu bar's "Open OpenProcess" bring it back.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
    }

    @objc private func windowWillClose(_ note: Notification) {
        let defaults = UserDefaults.standard
        // Without the menu bar extra there would be no way back to the app.
        guard defaults.bool(forKey: "menuBarOnly"), defaults.object(forKey: "showMenuBarExtra") as? Bool ?? true,
              let closing = note.object as? NSWindow, closing.canBecomeMain,
              !NSApp.windows.contains(where: { $0 !== closing && $0.isVisible && $0.canBecomeMain })
        else { return }
        NSApp.setActivationPolicy(.accessory)
    }
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
            CommandGroup(replacing: .help) {
                Button("Welcome to OpenProcess") { UserDefaults.standard.set(false, forKey: "hasSeenOnboarding") }
            }
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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

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
        .alert("The action couldn’t be completed", isPresented: Binding { ui.errorMessage != nil } set: { if !$0 { ui.errorMessage = nil } }) {
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
                Button("Quit") { ui.signal(SIGTERM, request.pids, monitor: monitor) }
                    .keyboardShortcut(.defaultAction)
                Button("Force Quit", role: .destructive) { ui.signal(SIGKILL, request.pids, monitor: monitor) }
            case SIGKILL:
                Button("Force Quit", role: .destructive) { ui.signal(SIGKILL, request.pids, monitor: monitor) }
            default:
                Button("Send \(SignalMenu.name(of: request.signal))", role: .destructive) {
                    ui.signal(request.signal, request.pids, monitor: monitor)
                }
            }
        } message: { request in
            switch request.signal {
            case SIGTERM: Text("If the process doesn’t respond, you can force it to quit.")
            case SIGKILL: Text("Unsaved changes will be lost. The process won’t be able to clean up its resources.")
            case SIGSTOP: Text("The process will be suspended until it receives SIGCONT.")
            default: Text("Processes may quit or change their behavior when they receive this signal.")
            }
        }
        .sheet(item: $ui.sampleReport) { SampleReportView(report: $0) }
        .sheet(isPresented: Binding { !hasSeenOnboarding } set: { hasSeenOnboarding = !$0 }) { OnboardingView() }
        .onAppear { NSApp.setActivationPolicy(.regular) } // undo "menu bar only"
    }

    private var signalTitle: String {
        guard let request = ui.pendingSignal else { return "" }
        let names = request.pids.compactMap { monitor.process($0)?.name }
        let target = names.count == 1 ? "“\(names[0])”" : String(localized: "\(request.pids.count) processes")
        return switch request.signal {
        case SIGTERM: String(localized: "Are you sure you want to quit \(target)?")
        case SIGKILL: String(localized: "Force \(target) to quit?")
        default: String(localized: "Send \(SignalMenu.name(of: request.signal)) to \(target)?")
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
                Text("Sample of \(report.name)").foregroundStyle(.secondary)
                Spacer()
                Button("Save…", action: save)
                    .help("Save the sample as a text file")
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
                    .help("Close the sample without saving it")
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = String(localized: "Sample of \(report.name)") + ".txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try report.text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
