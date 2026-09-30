import SwiftUI

struct ProcessesView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        let rows = filtered
        // Searching or narrowed scopes show a flat list.
        ProcessTable(
            rows: rows,
            tree: ui.treeMode && ui.search.isEmpty && ui.scope == .all,
            selection: $ui.selection,
            hiddenColumns: ui.hiddenColumns,
            sortKey: ui.sortKey,
            sortAscending: ui.sortAscending,
            onSort: { key, ascending in
                ui.sortKey = key
                ui.sortAscending = ascending
            },
            onToggleColumn: { id in
                if ui.hiddenColumns.contains(id) { ui.hiddenColumns.remove(id) } else { ui.hiddenColumns.insert(id) }
            },
            onOpen: { pid in
                ui.selection = [pid]
                ui.showInspector = true
            },
            menu: contextMenu
        )
        .searchable(text: $ui.search, isPresented: $ui.searchFocused, placement: .toolbar, prompt: "Name, PID, user, or path")
        .toolbar { toolbar }
        .inspector(isPresented: $ui.showInspector) {
            Group {
                if let pid = ui.selectedPID {
                    ProcessInspector(pid: pid)
                } else {
                    ContentUnavailableView("No Selection", systemImage: "info.circle", description: Text("Select a process to see its details."))
                }
            }
            .inspectorColumnWidth(min: 280, ideal: 320, max: 460)
        }
        .overlay {
            if !monitor.hasSampled {
                ProgressView("Reading processes…")
            } else if rows.isEmpty && !ui.search.isEmpty {
                ContentUnavailableView.search(text: ui.search)
            } else if rows.isEmpty {
                ContentUnavailableView {
                    Label("No Processes in This View", systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button("Show All Processes") { ui.scope = .all }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    /// Same actions as the Process menu.
    private func contextMenu(_ pids: Set<Int32>) -> NSMenu {
        let menu = NSMenu()
        let single = pids.count == 1 ? pids.first : nil
        menu.addItem(ClosureMenuItem(String(localized: "Quit Process…")) { ui.request(SIGTERM, pids) })
        menu.addItem(ClosureMenuItem(String(localized: "Force Quit…")) { ui.request(SIGKILL, pids) })
        let signals = NSMenuItem(title: String(localized: "Send Signal"), action: nil, keyEquivalent: "")
        signals.submenu = NSMenu()
        for entry in SignalMenu.signals {
            let title = "\(String(localized: entry.title)) (\(entry.name))…"
            signals.submenu?.addItem(ClosureMenuItem(title) { ui.request(entry.signal, pids) })
        }
        menu.addItem(signals)
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(String(localized: "Get Info"), enabled: single != nil) {
            ui.selection = pids
            ui.showInspector = true
        })
        menu.addItem(ClosureMenuItem(String(localized: "Sample Process"), enabled: single != nil && ui.samplingPID == nil) {
            if let single { ui.sample(single, monitor: monitor) }
        })
        menu.addItem(ClosureMenuItem(String(localized: "Show in Finder")) { ui.revealInFinder(pids, monitor: monitor) })
        menu.addItem(ClosureMenuItem(String(localized: "Copy Process Info")) { ui.copyInfo(pids, monitor: monitor) })
        return menu
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        @Bindable var ui = ui
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Quit Process", systemImage: "xmark.octagon") { ui.request(SIGTERM, ui.selection) }
            .help("Ask the selected processes to quit; you’re asked to confirm first (⌥⌘Q)")
            .disabled(ui.selection.isEmpty)
            // A Menu, not a menu-style Picker: the toolbar draws the picker's current value blank.
            Menu {
                Picker("Show", selection: $ui.scope) {
                    ForEach(ProcessScope.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Label(ui.scope.title, systemImage: "line.3.horizontal.decrease")
                    .labelStyle(.titleAndIcon)
            }
            .help("Choose which processes are shown: all, yours, system, other users’, or only windowed apps")
            Toggle("Tree", systemImage: "list.bullet.indent", isOn: $ui.treeMode)
                .help("Group each process under the process that started it. Only with “All Processes” and no search")
            Button("Info", systemImage: "info.circle") { ui.showInspector.toggle() }
                .help("Show or hide the panel with the selected process’s details (⌘I)")
        }
    }

    private var footer: some View {
        let procs = monitor.snapshot.processes
        return HStack(spacing: 16) {
            Text("\(procs.count) processes")
            Text("\(procs.reduce(0) { $0 + $1.threads }) threads")
            if !monitor.helper.isEnabled && procs.contains(where: { !$0.hasStats }) {
                Label("Metrics for other users’ processes are unavailable. Install the helper in Settings.", systemImage: "lock")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .font(.callout)
        .monospacedDigit()
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var filtered: [ProcessRow] {
        let me = getuid()
        let apps = ui.scope == .apps
            ? Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))
            : []
        let query = ui.search.trimmingCharacters(in: .whitespaces)
        return monitor.snapshot.processes.filter { p in
            let inScope = switch ui.scope {
            case .all: true
            case .mine: p.uid == me
            case .system: p.isSystem
            case .others: p.uid != me && !p.isSystem
            case .apps: apps.contains(p.pid)
            }
            guard inScope else { return false }
            guard !query.isEmpty else { return true }
            return p.name.localizedCaseInsensitiveContains(query)
                || String(p.pid) == query
                || p.user.localizedCaseInsensitiveContains(query)
                || (p.path?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

}
