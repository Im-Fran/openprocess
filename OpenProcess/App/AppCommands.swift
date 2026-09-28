import SwiftUI

struct AppCommands: Commands {
    let monitor: SystemMonitor
    let ui: UIState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()
        InspectorCommands()

        CommandGroup(after: .textEditing) {
            Button("Buscar…") {
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
            Picker("Mostrar", selection: Binding { ui.scope } set: { ui.scope = $0 }) {
                ForEach(ProcessScope.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Mostrar como árbol", isOn: Binding { ui.treeMode } set: { ui.treeMode = $0 })
            Menu("Columnas") {
                ForEach(ProcessColumn.all.dropFirst(), id: \.id) { column in
                    Toggle(column.title, isOn: Binding {
                        !ui.hiddenColumns.contains(column.id)
                    } set: { visible in
                        if visible { ui.hiddenColumns.remove(column.id) } else { ui.hiddenColumns.insert(column.id) }
                    })
                }
            }
            Picker("Ordenar por", selection: Binding { ui.sortKey } set: { ui.sortKey = $0 }) {
                ForEach(ProcessColumn.all, id: \.id) { Text($0.title).tag($0.id) }
            }
            Toggle("Orden ascendente", isOn: Binding { ui.sortAscending } set: { ui.sortAscending = $0 })
            Picker("Frecuencia de actualización", selection: Binding { monitor.interval } set: { monitor.interval = $0 }) {
                Text("Muy frecuente (1 s)").tag(1.0)
                Text("Frecuente (2 s)").tag(2.0)
                Text("Normal (5 s)").tag(5.0)
            }
            Divider()
        }

        CommandMenu("Proceso") {
            let pids = ui.selection
            let one = ui.selectedPID
            Button("Salir del proceso…") { ui.request(SIGTERM, pids) }
                .keyboardShortcut("q", modifiers: [.command, .option])
                .disabled(pids.isEmpty)
            Button("Forzar salida…") { ui.request(SIGKILL, pids) }
                .disabled(pids.isEmpty)
            SignalMenu(pids: pids, ui: ui)
            Divider()
            Button("Mostrar información") {
                ui.section = .processes
                ui.showInspector = true
            }
            .keyboardShortcut("i")
            .disabled(one == nil)
            Button("Muestrear proceso") { if let one { ui.sample(one, monitor: monitor) } }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(one == nil || ui.samplingPID != nil)
            Button("Mostrar en Finder") { ui.revealInFinder(pids, monitor: monitor) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(pids.isEmpty)
            Button("Copiar información del proceso") { ui.copyInfo(pids, monitor: monitor) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(pids.isEmpty)
        }

        CommandMenu("Utilidades") {
            Button("Purgar memoria") {
                Task { if let error = await monitor.purgeMemory() { ui.errorMessage = error } }
            }
            .disabled(!monitor.helper.isEnabled)
            Divider()
            Button("Abrir Consola") { openApp("com.apple.Console") }
            Button("Abrir Información del Sistema") { openApp("com.apple.SystemProfiler") }
            Button("Abrir Utilidad de Discos") { openApp("com.apple.DiskUtility") }
        }
    }

    private func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

/// "Enviar señal" submenu, shared by the menu bar and context menus.
struct SignalMenu: View {
    let pids: Set<Int32>
    let ui: UIState

    static let signals: [(title: String, name: String, signal: Int32)] = [
        ("Interrumpir", "SIGINT", SIGINT), ("Colgar", "SIGHUP", SIGHUP), ("Terminar", "SIGTERM", SIGTERM),
        ("Salir", "SIGQUIT", SIGQUIT), ("Pausar", "SIGSTOP", SIGSTOP), ("Continuar", "SIGCONT", SIGCONT),
        ("Usuario 1", "SIGUSR1", SIGUSR1), ("Usuario 2", "SIGUSR2", SIGUSR2), ("Matar", "SIGKILL", SIGKILL),
    ]

    static func name(of signal: Int32) -> String {
        signals.first { $0.signal == signal }?.name ?? String(signal)
    }

    var body: some View {
        Menu("Enviar señal") {
            ForEach(Self.signals, id: \.signal) { entry in
                Button("\(String(localized: String.LocalizationValue(entry.title))) (\(entry.name))…") { ui.request(entry.signal, pids) }
            }
        }
        .disabled(pids.isEmpty)
    }
}
