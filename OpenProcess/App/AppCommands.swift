import SwiftUI

struct AppCommands: Commands {
    let monitor: SystemMonitor
    let ui: UIState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()
        InspectorCommands()

        CommandGroup(after: .textEditing) {
            Button("Find…") {
                ui.section = .processes
                ui.searchFocused = true
            }
            .keyboardShortcut("f")
        }

        CommandGroup(before: .sidebar) {
            ForEach(AppSection.allCases) { section in
                Button(section.title) { ui.section = section }
                    .keyboardShortcut(section.shortcut)
            }
            Divider()
            Picker("Show", selection: Binding { ui.scope } set: { ui.scope = $0 }) {
                ForEach(ProcessScope.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Show as Tree", isOn: Binding { ui.treeMode } set: { ui.treeMode = $0 })
            Menu("Columns") {
                ForEach(ProcessColumn.all.dropFirst(), id: \.id) { column in
                    Toggle(column.title, isOn: Binding {
                        !ui.hiddenColumns.contains(column.id)
                    } set: { visible in
                        if visible { ui.hiddenColumns.remove(column.id) } else { ui.hiddenColumns.insert(column.id) }
                    })
                }
            }
            Picker("Sort By", selection: Binding { ui.sortKey } set: { ui.sortKey = $0 }) {
                ForEach(ProcessColumn.all, id: \.id) { Text($0.title).tag($0.id) }
            }
            Toggle("Ascending Order", isOn: Binding { ui.sortAscending } set: { ui.sortAscending = $0 })
            Picker("Update Frequency", selection: Binding { monitor.interval } set: { monitor.interval = $0 }) {
                Text("Very Often (1 s)").tag(1.0)
                Text("Often (2 s)").tag(2.0)
                Text("Normally (5 s)").tag(5.0)
            }
            Divider()
        }

        CommandMenu("Process") {
            let pids = ui.selection
            let one = ui.selectedPID
            Button("Quit Process…") { ui.request(SIGTERM, pids) }
                .keyboardShortcut("q", modifiers: [.command, .option])
                .disabled(pids.isEmpty)
            Button("Force Quit…") { ui.request(SIGKILL, pids) }
                .disabled(pids.isEmpty)
            SignalMenu(pids: pids, ui: ui)
            Divider()
            Button("Get Info") {
                ui.section = .processes
                ui.showInspector = true
            }
            .keyboardShortcut("i")
            .disabled(one == nil)
            Button("Sample Process") { if let one { ui.sample(one, monitor: monitor) } }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(one == nil || ui.samplingPID != nil)
            Button("Show in Finder") { ui.revealInFinder(pids, monitor: monitor) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(pids.isEmpty)
            Button("Copy Process Info") { ui.copyInfo(pids, monitor: monitor) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(pids.isEmpty)
        }

        CommandMenu("Utilities") {
            Button("Purge Memory") {
                Task { if let error = await monitor.purgeMemory() { ui.errorMessage = error } }
            }
            .disabled(!monitor.helper.isEnabled)
            .help(monitor.helper.isEnabled ? PurgeHelp.enabled : PurgeHelp.disabled)
            Divider()
            Button("Open Console") { openApp("com.apple.Console") }
            Button("Open System Information") { openApp("com.apple.SystemProfiler") }
            Button("Open Disk Utility") { openApp("com.apple.DiskUtility") }
        }
    }

    private func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

/// "Send Signal" submenu, shared by the menu bar and context menus.
struct SignalMenu: View {
    let pids: Set<Int32>
    let ui: UIState

    static let signals: [(title: LocalizedStringResource, name: String, signal: Int32)] = [
        ("Interrupt", "SIGINT", SIGINT), ("Hang Up", "SIGHUP", SIGHUP), ("Terminate", "SIGTERM", SIGTERM),
        ("Quit", "SIGQUIT", SIGQUIT), ("Stop", "SIGSTOP", SIGSTOP), ("Continue", "SIGCONT", SIGCONT),
        ("User 1", "SIGUSR1", SIGUSR1), ("User 2", "SIGUSR2", SIGUSR2), ("Kill", "SIGKILL", SIGKILL),
    ]

    static func name(of signal: Int32) -> String {
        signals.first { $0.signal == signal }?.name ?? String(signal)
    }

    var body: some View {
        Menu("Send Signal") {
            ForEach(Self.signals, id: \.signal) { entry in
                Button("\(String(localized: entry.title)) (\(entry.name))…") { ui.request(entry.signal, pids) }
            }
        }
        .disabled(pids.isEmpty)
    }
}
