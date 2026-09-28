import AppKit
import SwiftUI

/// Column definition for the native process table.
@MainActor
struct ProcessColumn {
    let id: String
    let title: String
    let width: CGFloat
    var numeric = true
    var hiddenByDefault = false
    /// Shows "—" when the row has no readable stats.
    var needsStats = true
    let text: (ProcessRow) -> String
    let ascending: (ProcessRow, ProcessRow) -> Bool

    static func by<V: Comparable>(_ key: KeyPath<ProcessRow, V>) -> (ProcessRow, ProcessRow) -> Bool {
        { $0[keyPath: key] < $1[keyPath: key] }
    }

    static let all: [ProcessColumn] = [
        .init(id: "name", title: String(localized: "Nombre del proceso"), width: 240, numeric: false, needsStats: false,
              text: \.name, ascending: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }),
        .init(id: "cpu", title: String(localized: "% CPU"), width: 60, text: { Format.cpu($0.cpu) }, ascending: by(\.cpu)),
        .init(id: "cpuTime", title: String(localized: "Tiempo CPU"), width: 85, text: { Format.duration($0.cpuTime) }, ascending: by(\.cpuTime)),
        .init(id: "pshare", title: String(localized: "% núcleos P"), width: 75, hiddenByDefault: true,
              text: { $0.pCoreShare.map(Format.percent) ?? "—" }, ascending: by(\.sortablePShare)),
        .init(id: "threads", title: String(localized: "Hilos"), width: 50, text: { $0.threads.formatted() }, ascending: by(\.threads)),
        .init(id: "memory", title: String(localized: "Memoria"), width: 80, text: { Format.bytes($0.memory) }, ascending: by(\.memory)),
        .init(id: "gpu", title: String(localized: "% GPU"), width: 55, needsStats: false, text: { Format.cpu($0.gpu) }, ascending: by(\.gpu)),
        .init(id: "power", title: String(localized: "Energía"), width: 65, text: { Format.watts($0.power) }, ascending: by(\.power)),
        .init(id: "wakeups", title: String(localized: "Activaciones"), width: 80, hiddenByDefault: true,
              text: { $0.wakeups.formatted(.number.precision(.fractionLength(0))) }, ascending: by(\.wakeups)),
        .init(id: "diskRead", title: String(localized: "Lectura disco"), width: 90, hiddenByDefault: true,
              text: { Format.rate($0.diskRead) }, ascending: by(\.diskRead)),
        .init(id: "diskWrite", title: String(localized: "Escritura disco"), width: 90, hiddenByDefault: true,
              text: { Format.rate($0.diskWrite) }, ascending: by(\.diskWrite)),
        .init(id: "netIn", title: String(localized: "Red recibida"), width: 90, hiddenByDefault: true, needsStats: false,
              text: { Format.rate($0.netIn) }, ascending: by(\.netIn)),
        .init(id: "netOut", title: String(localized: "Red enviada"), width: 90, hiddenByDefault: true, needsStats: false,
              text: { Format.rate($0.netOut) }, ascending: by(\.netOut)),
        .init(id: "pid", title: "PID", width: 60, needsStats: false, text: { String($0.pid) }, ascending: by(\.pid)),
        .init(id: "user", title: String(localized: "Usuario"), width: 90, numeric: false, needsStats: false,
              text: \.user, ascending: { $0.user < $1.user }),
    ]
}

extension ProcessRow {
    var sortablePShare: Double { pCoreShare ?? -1 }
}

/// Native `NSOutlineView` for the process list. SwiftUI's `Table` recreates hosting views whenever
/// rows reorder, which costs >10 % CPU with ~700 processes sorted by a live metric.
struct ProcessTable: NSViewRepresentable {
    let rows: [ProcessRow]
    let tree: Bool
    @Binding var selection: Set<Int32>
    let hiddenColumns: Set<String>
    let sortKey: String
    let sortAscending: Bool
    let onSort: (String, Bool) -> Void
    let onToggleColumn: (String) -> Void
    let onOpen: (Int32) -> Void
    let menu: (Set<Int32>) -> NSMenu

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let outline = NSOutlineView()
        outline.style = .inset
        outline.usesAlternatingRowBackgroundColors = true
        outline.allowsMultipleSelection = true
        outline.allowsColumnReordering = true
        outline.columnAutoresizingStyle = .noColumnAutoresizing
        outline.rowSizeStyle = .default
        outline.indentationPerLevel = 14
        outline.autosaveExpandedItems = false
        for spec in ProcessColumn.all {
            let column = NSTableColumn(identifier: .init(spec.id))
            column.title = spec.title
            column.width = spec.width
            column.minWidth = spec.id == "name" ? 140 : 40
            column.sortDescriptorPrototype = NSSortDescriptor(key: spec.id, ascending: !spec.numeric)
            if spec.numeric { column.headerCell.alignment = .right }
            outline.addTableColumn(column)
            if spec.id == "name" { outline.outlineTableColumn = column }
        }
        // Widths and order are autosaved; visibility and sorting live in UIState so the menu bar can drive them.
        outline.autosaveName = "ProcessTable"
        outline.autosaveTableColumns = true
        let headerMenu = NSMenu()
        headerMenu.delegate = context.coordinator
        outline.headerView?.menu = headerMenu
        outline.menu = NSMenu()
        outline.menu?.delegate = context.coordinator
        outline.menu?.autoenablesItems = false
        outline.dataSource = context.coordinator
        outline.delegate = context.coordinator
        outline.target = context.coordinator
        outline.doubleAction = #selector(Coordinator.doubleClicked(_:))
        outline.setAccessibilityLabel(String(localized: "Procesos"))

        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        context.coordinator.outline = outline
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.occlusionChanged(_:)),
            name: NSWindow.didChangeOcclusionStateNotification, object: nil
        )
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.applyColumnsAndSort()
        if scroll.window == nil {
            DispatchQueue.main.async { c.reload() } // first update happens before the view joins its window
        } else {
            c.reload()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
        /// Stable per-pid object so NSOutlineView keeps expansion state across reloads.
        final class Item {
            var row: ProcessRow
            var children: [Item] = []
            init(_ row: ProcessRow) { self.row = row }
        }

        var parent: ProcessTable?
        weak var outline: NSOutlineView?
        private var roots: [Item] = []
        private var items: [Int32: Item] = [:]
        private var isTree = false
        private var applyingSelection = false
        private var applyingSort = false
        private let digits = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        func applyColumnsAndSort() {
            guard let outline, let parent else { return }
            for column in outline.tableColumns where column.identifier.rawValue != "name" {
                let hidden = parent.hiddenColumns.contains(column.identifier.rawValue)
                if column.isHidden != hidden { column.isHidden = hidden }
            }
            let descriptor = NSSortDescriptor(key: parent.sortKey, ascending: parent.sortAscending)
            if outline.sortDescriptors.first != descriptor {
                applyingSort = true
                outline.sortDescriptors = [descriptor]
                applyingSort = false
            }
        }

        @objc func occlusionChanged(_ note: Notification) {
            guard (note.object as? NSWindow) === outline?.window else { return }
            reload()
        }

        func reload() {
            // Skip work while the window is closed or fully covered; a hidden table lays out every row.
            guard let outline, let parent, let window = outline.window, window.occlusionState.contains(.visible) else { return }
            let rows = parent.rows, tree = parent.tree, selection = parent.selection
            var next: [Int32: Item] = [:]
            for row in rows {
                let item = items[row.pid].flatMap { $0.row.startTime == row.startTime ? $0 : nil } ?? Item(row)
                item.row = row
                item.children = []
                next[row.pid] = item
            }
            items = next
            let treeChanged = tree != isTree
            isTree = tree
            if tree {
                roots = []
                for row in rows {
                    let item = next[row.pid]!
                    if row.pid != row.ppid, let parent = next[row.ppid] { parent.children.append(item) } else { roots.append(item) }
                }
            } else {
                roots = rows.compactMap { next[$0.pid] }
            }
            sort(&roots)

            applyingSelection = true
            outline.reloadData()
            if treeChanged && tree { outline.expandItem(nil, expandChildren: true) }
            let indexes = IndexSet(selection.compactMap { next[$0] }.map { outline.row(forItem: $0) }.filter { $0 >= 0 })
            if indexes != outline.selectedRowIndexes { outline.selectRowIndexes(indexes, byExtendingSelection: false) }
            applyingSelection = false
        }

        private func sort(_ list: inout [Item]) {
            guard let descriptor = outline?.sortDescriptors.first, let key = descriptor.key,
                  let spec = ProcessColumn.all.first(where: { $0.id == key }) else { return }
            let asc = descriptor.ascending
            // Ties broken by pid so the order doesn't jitter between ticks.
            list.sort { a, b in
                if spec.ascending(a.row, b.row) { return asc }
                if spec.ascending(b.row, a.row) { return !asc }
                return a.row.pid < b.row.pid
            }
            for item in list where !item.children.isEmpty { sort(&item.children) }
        }

        // MARK: Data source

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? Item)?.children.count ?? roots.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            (item as? Item)?.children[index] ?? roots[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            !((item as? Item)?.children.isEmpty ?? true)
        }

        func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard !applyingSort, let parent, let descriptor = outlineView.sortDescriptors.first, let key = descriptor.key else { return }
            parent.onSort(key, descriptor.ascending)
        }

        // MARK: Delegate

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let tableColumn, let item = item as? Item,
                  let spec = ProcessColumn.all.first(where: { $0.id == tableColumn.identifier.rawValue }) else { return nil }
            let isName = spec.id == "name"
            let cell = pool[tableColumn.identifier]?.popLast()
                ?? makeCell(identifier: tableColumn.identifier, withImage: isName, numeric: spec.numeric)
            let row = item.row
            let readable = !spec.needsStats || row.hasStats
            var text = readable ? spec.text(row) : "—"
            if isName && row.isTranslated { text += " (Intel)" }
            cell.textField?.stringValue = text
            cell.textField?.textColor = readable ? .labelColor : .secondaryLabelColor
            cell.textField?.setAccessibilityValueDescription(readable ? nil : String(localized: "No disponible"))
            if isName { cell.imageView?.image = ProcessIcon.image(for: row.path) }
            return cell
        }

        // ponytail: NSOutlineView's own reuse queue never returned our programmatic cells after
        // reloadData(), so we recycle them ourselves.
        private var pool: [NSUserInterfaceItemIdentifier: [NSTableCellView]] = [:]

        func outlineView(_ outlineView: NSOutlineView, didRemove rowView: NSTableRowView, forRow row: Int) {
            for case let cell as NSTableCellView in rowView.subviews {
                guard let id = cell.identifier else { continue }
                cell.removeFromSuperview()
                pool[id, default: []].append(cell)
            }
        }

        private func makeCell(identifier: NSUserInterfaceItemIdentifier, withImage: Bool, numeric: Bool) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let field = NSTextField(labelWithString: "")
            field.lineBreakMode = .byTruncatingTail
            field.font = numeric ? digits : .systemFont(ofSize: NSFont.systemFontSize)
            field.alignment = numeric ? .right : .natural
            field.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(field)
            cell.textField = field
            var constraints = [
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            ]
            if withImage {
                let image = NSImageView()
                image.setAccessibilityElement(false)
                image.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(image)
                cell.imageView = image
                constraints += [
                    image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                    image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    image.widthAnchor.constraint(equalToConstant: 16),
                    image.heightAnchor.constraint(equalToConstant: 16),
                    field.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
                ]
            } else {
                constraints.append(field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2))
            }
            NSLayoutConstraint.activate(constraints)
            return cell
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !applyingSelection, let outline, let parent else { return }
            let pids = Set(outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? Item)?.row.pid })
            if pids != parent.selection { parent.selection = pids }
        }

        @objc func doubleClicked(_ sender: NSOutlineView) {
            guard sender.clickedRow >= 0, let item = sender.item(atRow: sender.clickedRow) as? Item else { return }
            parent?.onOpen(item.row.pid)
        }

        // MARK: Menus

        /// Context menu for the clicked row (or the selection when the clicked row is part of it).
        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            if menu === outline?.headerView?.menu { return fillHeaderMenu(menu) }
            guard let outline, let parent, outline.clickedRow >= 0,
                  let clicked = (outline.item(atRow: outline.clickedRow) as? Item)?.row.pid else { return }
            let pids = outline.selectedRowIndexes.contains(outline.clickedRow) ? parent.selection : [clicked]
            for item in parent.menu(pids).items {
                item.menu?.removeItem(item)
                menu.addItem(item)
            }
        }

        private func fillHeaderMenu(_ menu: NSMenu) {
            guard let parent else { return }
            for spec in ProcessColumn.all.dropFirst() {
                let item = ClosureMenuItem(spec.title) { parent.onToggleColumn(spec.id) }
                item.state = parent.hiddenColumns.contains(spec.id) ? .off : .on
                menu.addItem(item)
            }
        }
    }
}

/// NSMenuItem that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, enabled: Bool = true, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        isEnabled = enabled
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
