//
//  FontListViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreData

// MARK: - FontListViewController

class FontListViewController: NSViewController, FontBrowserChildViewControlling {

    private enum LayoutMetrics {
        static let minimumColumnWidth: CGFloat = 220
        static let indentationPerLevel: CGFloat = 0
    }

    var onSelectionChanged: (([FontTypefaceItem], Bool) -> Void)?
    var onSectionToggled: ((FontFamilyID) -> Void)?
    var onFamilySelectionIntent: ((FontFamilyID, FontFamilySelectionIntent) -> Void)?

    private var outlineView: FontListOutlineView!
    private var snapshot: FontBrowserSnapshot = .empty
    private var collapsedFamilyIDs: Set<FontFamilyID> = []
    private var currentSelectedTypefaceIDs: Set<FontTypefaceID> = []
    /// Sections whose row is selected in the outline view *and* should be
    /// treated as fully-expanded (i.e. their typefaces all belong to the
    /// synthesized selection). Section rows that the user has effectively
    /// "broken" by Cmd-deselecting one of their children are removed from this
    /// set, so a later read of the selection no longer expands them.
    private var fullySelectedSectionIDs: Set<FontFamilyID> = []
    private var isApplyingReload = false
    private var isSynchronizingExpansionState = false
    private var isReconcilingSelection = false

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        outlineView = FontListOutlineView()
        outlineView.headerView = nil
        outlineView.style = .inset
        outlineView.rowSizeStyle = .default
        outlineView.backgroundColor = .clear
        outlineView.focusRingType = .none
        outlineView.allowsMultipleSelection = true
        outlineView.allowsEmptySelection = true
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.indentationPerLevel = LayoutMetrics.indentationPerLevel
        outlineView.usesAutomaticRowHeights = true
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.onSectionRowClicked = { [weak self] familyID, intent in
            self?.onFamilySelectionIntent?(familyID, intent)
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FontListColumn"))
        column.title = "Fonts"
        column.minWidth = LayoutMetrics.minimumColumnWidth
        column.resizingMask = .autoresizingMask

        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        view = scrollView
    }

    // MARK: - FontBrowserChildViewControlling

    func reloadData(
        snapshot: FontBrowserSnapshot,
        selectedTypefaceIDs: Set<FontTypefaceID>,
        collapsedFamilyIDs: Set<FontFamilyID>,
        animatingDifferences: Bool,
        reloadingFamilyIDs: Set<FontFamilyID>
    ) {
        loadViewIfNeeded()

        self.snapshot = snapshot
        self.collapsedFamilyIDs = collapsedFamilyIDs
        self.currentSelectedTypefaceIDs = selectedTypefaceIDs
        self.fullySelectedSectionIDs = []

        isApplyingReload = true
        outlineView.reloadData()
        synchronizeExpansionState()
        restoreSelection(with: selectedTypefaceIDs)
        isApplyingReload = false
    }

    func visibleTypefaceIDs() -> Set<FontTypefaceID> {
        Set(
            snapshot.families
                .filter { !collapsedFamilyIDs.contains($0.id) }
                .flatMap { $0.typefaces.map { $0.id } }
        )
    }

    func isPrimaryViewFirstResponder() -> Bool {
        let responder = view.window?.firstResponder
        guard let responder else { return false }
        if responder === outlineView {
            return true
        }

        guard let view = responder as? NSView else { return false }
        return view.isDescendant(of: outlineView)
    }

    func focusPrimaryView() {
        loadViewIfNeeded()
        view.window?.makeFirstResponder(outlineView)
    }

    func refreshFamilyHeaders(for familyIDs: Set<FontFamilyID>, selectedTypefaceIDs: Set<FontTypefaceID>) {
        loadViewIfNeeded()
        currentSelectedTypefaceIDs = selectedTypefaceIDs

        // Reconcile the outline view's selection so that `.full` family rows
        // are selected (and natively highlighted) while `.partial` / `.none`
        // family rows are deselected.
        let desiredRows = desiredSelectedRowIndexes(for: selectedTypefaceIDs)
        if desiredRows != outlineView.selectedRowIndexes {
            isReconcilingSelection = true
            outlineView.selectRowIndexes(desiredRows, byExtendingSelection: false)
            isReconcilingSelection = false
        }
        rebuildFullySelectedSectionIDsFromCanonicalSelection()

        // Re-tint the affected section cells so `.partial` shows the accent color.
        for familyID in familyIDs {
            guard let section = snapshot.familyByID[familyID] else { continue }
            let row = outlineView.row(forItem: section)
            guard row >= 0 else { continue }
            guard let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false)
                as? FontListSectionCellView else { continue }
            let state = FontFamilySelectionState.resolve(
                typefaceIDs: section.typefaces.map { $0.id },
                selected: selectedTypefaceIDs
            )
            cell.updateSelectionState(state)
        }
    }

    // MARK: - Helpers

    private func synchronizeExpansionState() {
        isSynchronizingExpansionState = true
        defer { isSynchronizingExpansionState = false }

        for section in snapshot.families {
            if collapsedFamilyIDs.contains(section.id) {
                if outlineView.isItemExpanded(section) {
                    outlineView.collapseItem(section, collapseChildren: true)
                }
            } else if !outlineView.isItemExpanded(section) {
                outlineView.expandItem(section, expandChildren: false)
            }
        }
    }

    private func restoreSelection(with typefaceIDs: Set<FontTypefaceID>) {
        let rows = desiredSelectedRowIndexes(for: typefaceIDs)
        outlineView.selectRowIndexes(rows, byExtendingSelection: false)
        rebuildFullySelectedSectionIDsFromCanonicalSelection()
    }

    /// Resets `fullySelectedSectionIDs` to match the outline view's current
    /// selection. Called after we programmatically install a selection from the
    /// canonical typeface set, where every selected section row is by
    /// definition `.full` (and therefore fully-expanded for synthesis).
    private func rebuildFullySelectedSectionIDsFromCanonicalSelection() {
        var ids = Set<FontFamilyID>()
        for row in outlineView.selectedRowIndexes {
            if let section = outlineView.item(atRow: row) as? FontFamilySection,
               !collapsedFamilyIDs.contains(section.id) {
                ids.insert(section.id)
            }
        }
        fullySelectedSectionIDs = ids
    }

    /// Computes the set of outline-view rows that should be selected for a given
    /// typeface selection: every selected typeface row, plus the section row of
    /// every family that resolves to `.full`.
    private func desiredSelectedRowIndexes(for typefaceIDs: Set<FontTypefaceID>) -> IndexSet {
        var rows = IndexSet()

        for typefaceID in typefaceIDs {
            guard let item = snapshot.typefaceByID[typefaceID] else { continue }
            let row = outlineView.row(forItem: item)
            if row >= 0 {
                rows.insert(row)
            }
        }

        for section in snapshot.families {
            let state = FontFamilySelectionState.resolve(
                typefaceIDs: section.typefaces.map { $0.id },
                selected: typefaceIDs
            )
            guard state == .full else { continue }
            let row = outlineView.row(forItem: section)
            if row >= 0 {
                rows.insert(row)
            }
        }

        return rows
    }

    /// Translates the outline view's current selection into a stable, deduplicated
    /// list of typefaces.
    ///
    /// Selected `FontFamilySection` rows expand into their child typefaces when
    /// they belong to `fullySelectedSectionIDs` — which is true for sections the
    /// user just brought into the selection (e.g. via plain click, range
    /// selection, or because the family already resolved to `.full`). When the
    /// user Cmd+clicks a child to deselect it, we drop the section from that
    /// set so the section's lingering visual selection no longer overrides the
    /// user's intent. Collapsed sections always expand to all typefaces because
    /// their child rows are not present in the outline.
    private func selectedTypefaceItems() -> [FontTypefaceItem] {
        reconcileFullySelectedSectionIDs()

        let selectedRows = outlineView.selectedRowIndexes
        var includedTypefaces = Set<FontTypefaceID>()

        for row in selectedRows {
            switch outlineView.item(atRow: row) {
            case let typeface as FontTypefaceItem:
                includedTypefaces.insert(typeface.id)
            case let section as FontFamilySection:
                let isCollapsed = collapsedFamilyIDs.contains(section.id)
                if isCollapsed || fullySelectedSectionIDs.contains(section.id) {
                    for typeface in section.typefaces {
                        includedTypefaces.insert(typeface.id)
                    }
                }
                // Otherwise the section's selection is "broken" — its child
                // rows that are individually selected will be picked up by the
                // FontTypefaceItem branch above.
            default:
                continue
            }
        }

        // Preserve snapshot order for stability.
        var ordered: [FontTypefaceItem] = []
        ordered.reserveCapacity(includedTypefaces.count)
        for section in snapshot.families {
            for typeface in section.typefaces where includedTypefaces.contains(typeface.id) {
                ordered.append(typeface)
            }
        }
        return ordered
    }

    /// Updates `fullySelectedSectionIDs` to reflect the outline view's current
    /// selection. A section enters the set when its row becomes selected (and
    /// stays there as long as no child row is explicitly deselected). A section
    /// leaves the set when (a) its row is deselected, (b) it is now collapsed
    /// (collapsed sections are handled separately, but we keep the set tidy),
    /// or (c) any of its visible child rows is *not* selected.
    private func reconcileFullySelectedSectionIDs() {
        let selectedRows = outlineView.selectedRowIndexes
        var nextSelectedSectionIDs = Set<FontFamilyID>()

        for row in selectedRows {
            guard let section = outlineView.item(atRow: row) as? FontFamilySection else { continue }
            nextSelectedSectionIDs.insert(section.id)
        }

        // Drop sections whose row is no longer selected.
        fullySelectedSectionIDs.formIntersection(nextSelectedSectionIDs)

        for familyID in nextSelectedSectionIDs {
            guard let section = snapshot.familyByID[familyID] else { continue }

            if collapsedFamilyIDs.contains(familyID) {
                // Collapsed sections are handled implicitly by selectedTypefaceItems
                // (no child rows to honor); keep them out of the set so they
                // don't carry stale "fully-selected" status across an expand.
                fullySelectedSectionIDs.remove(familyID)
                continue
            }

            if fullySelectedSectionIDs.contains(familyID) {
                // Already fully selected: revoke if the user has Cmd-deselected
                // any of its visible child rows.
                let allChildrenStillSelected = section.typefaces.allSatisfy { typeface in
                    let childRow = outlineView.row(forItem: typeface)
                    return childRow >= 0 && selectedRows.contains(childRow)
                }
                if !allChildrenStillSelected {
                    fullySelectedSectionIDs.remove(familyID)
                }
            } else {
                // Newly selected section row (e.g. via range selection) →
                // promote to fully-selected so its typefaces join the result.
                fullySelectedSectionIDs.insert(familyID)
            }
        }
    }

    private func notifySelectionChanged() {
        onSelectionChanged?(selectedTypefaceItems(), preservesHiddenSelectionForCurrentEvent())
    }

    private func preservesHiddenSelectionForCurrentEvent() -> Bool {
        let modifierFlags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        return modifierFlags.contains(.command) || modifierFlags.contains(.shift)
    }
}

// MARK: - FontListOutlineView

private final class FontListOutlineView: NSOutlineView {

    /// Invoked when a plain or Cmd-clicked section row is intercepted. Shift-clicks
    /// on section rows are forwarded to `super` so that NSOutlineView's native
    /// range-extend works across families (the parent then synthesizes the final
    /// typeface selection from the resulting selected rows).
    var onSectionRowClicked: ((FontFamilyID, FontFamilySelectionIntent) -> Void)?

    /// Suppresses the built-in disclosure triangle.
    /// Expansion/collapse is driven manually via the custom disclosure button on `FontListSectionCellView`.
    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        .zero
    }

    override func mouseDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let location = convert(event.locationInWindow, from: nil)
        let row = self.row(at: location)

        if row >= 0,
           let section = item(atRow: row) as? FontFamilySection,
           !modifiers.contains(.shift) {
            // Hit-test to ensure the click did not land on the disclosure button
            // (NSButton normally consumes its own click before reaching us, but
            // we double-check so chevron presses never get reinterpreted as a
            // family-selection intent).
            if let hit = hitTest(event.locationInWindow),
               hit !== self,
               !(hit is NSTableRowView),
               hit is NSButton {
                super.mouseDown(with: event)
                return
            }

            let intent: FontFamilySelectionIntent = modifiers.contains(.command)
                ? .toggleAdditive
                : .selectReplace
            onSectionRowClicked?(section.id, intent)
            return
        }

        super.mouseDown(with: event)
    }
}

// MARK: - NSOutlineViewDataSource

extension FontListViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        switch item {
        case nil:
            return snapshot.families.count
        case let section as FontFamilySection:
            return section.typefaces.count
        default:
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        switch item {
        case nil:
            return snapshot.families[index]
        case let section as FontFamilySection:
            return section.typefaces[index]
        default:
            fatalError("Unexpected outline item")
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let section = item as? FontFamilySection else { return false }
        return !section.typefaces.isEmpty
    }
}

// MARK: - NSOutlineViewDelegate

extension FontListViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        // Both `FontTypefaceItem` and `FontFamilySection` rows are selectable.
        //
        // Allowing section rows to be selected lets a `.full` family render via
        // NSOutlineView's native row highlight (so it joins adjacent selected
        // siblings into a single rounded rectangle), and enables range
        // selection (Shift+click) to span across family boundaries — picking up
        // every typeface in the families it crosses.
        //
        // Plain and Cmd+clicks on section rows are intercepted upstream in
        // `FontListOutlineView.mouseDown(with:)` and routed through
        // `onFamilySelectionIntent` so the family-level select / toggle
        // semantics (matching the grid view) take precedence over
        // NSOutlineView's default per-row behavior. The section row's actual
        // selected/unselected state is then driven canonically by
        // `refreshFamilyHeaders(for:selectedTypefaceIDs:)` based on the
        // resolved `FontFamilySelectionState` of the family.
        true
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let section = item as? FontFamilySection {
            let cell = outlineView.makeView(
                withIdentifier: FontListSectionCellView.identifier,
                owner: self
            ) as? FontListSectionCellView ?? FontListSectionCellView()
            cell.identifier = FontListSectionCellView.identifier
            let selectionState = FontFamilySelectionState.resolve(
                typefaceIDs: section.typefaces.map { $0.id },
                selected: currentSelectedTypefaceIDs
            )
            cell.configure(
                familyName: section.displayName,
                count: section.typefaceCount,
                isCollapsed: collapsedFamilyIDs.contains(section.id),
                selectionState: selectionState,
                onToggle: { [weak self] in
                    self?.onSectionToggled?(section.id)
                }
            )
            return cell
        }

        guard let typeface = item as? FontTypefaceItem else { return nil }

        let cell = outlineView.makeView(
            withIdentifier: FontListRowCellView.identifier,
            owner: self
        ) as? FontListRowCellView ?? FontListRowCellView()
        cell.identifier = FontListRowCellView.identifier
        cell.configure(with: typeface)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingReload, !isReconcilingSelection else { return }
        notifySelectionChanged()
    }
}
