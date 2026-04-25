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
    private var isApplyingReload = false
    private var isSynchronizingExpansionState = false
    private var selectionResolver: FontListSelectionResolver!

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

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FontListColumn"))
        column.title = "Fonts"
        column.minWidth = LayoutMetrics.minimumColumnWidth
        column.resizingMask = .autoresizingMask

        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        selectionResolver = FontListSelectionResolver(outlineView: outlineView)

        outlineView.onSectionCommandClick = { [weak self] section in
            self?.onFamilySelectionIntent?(section.id, .toggleAdditive)
        }
        outlineView.onBackgroundClickWithoutSelectionChange = { [weak self] in
            self?.handleBackgroundClickWithoutSelectionChange()
        }

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

        isApplyingReload = true
        defer { isApplyingReload = false }

        self.snapshot = snapshot
        self.collapsedFamilyIDs = collapsedFamilyIDs
        self.currentSelectedTypefaceIDs = selectedTypefaceIDs
        // Row indices may have shifted; any cached proposal is stale.
        selectionResolver.updateSnapshot(snapshot)

        outlineView.reloadData()
        synchronizeExpansionState()
        restoreSelection(with: selectedTypefaceIDs)
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

        // Re-tint the affected section cells so `.partial` shows the accent color.
        let sections = familyIDs.compactMap { snapshot.familyByID[$0] }
        applySelectionTints(forFamilies: sections, using: selectedTypefaceIDs)
    }

    /// Re-tints the visible section header cells for the given families based
    /// on the supplied typeface selection. Does not mutate
    /// `currentSelectedTypefaceIDs`; callers that represent a committed
    /// selection are responsible for updating that baseline themselves.
    private func applySelectionTints(
        forFamilies sections: [FontFamilySection],
        using selectedTypefaceIDs: Set<FontTypefaceID>
    ) {
        for section in sections {
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
        // Programmatic selection bypasses the delegate's proposal callback, so
        // any cached drag-derived proposal must be discarded.
        selectionResolver.resetCache()
        let rows = selectionResolver.rowIndexes(forTypefaces: typefaceIDs)
        outlineView.selectRowIndexes(rows, byExtendingSelection: false)
    }

    private func typefacesForCurrentSelection() -> [FontTypefaceItem] {
        var selectedTypefaces: [FontTypefaceItem] = []
        var seenTypefaceIDs: Set<FontTypefaceID> = []

        for row in outlineView.selectedRowIndexes {
            switch outlineView.item(atRow: row) {
            case let typeface as FontTypefaceItem:
                guard seenTypefaceIDs.insert(typeface.id).inserted else { continue }
                selectedTypefaces.append(typeface)

            case let section as FontFamilySection:
                for typeface in section.typefaces {
                    guard seenTypefaceIDs.insert(typeface.id).inserted else { continue }
                    selectedTypefaces.append(typeface)
                }

            default:
                continue
            }
        }

        return selectedTypefaces
    }

    private func preservesHiddenSelectionForCurrentEvent() -> Bool {
        let modifierFlags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        return modifierFlags.contains(.command) || modifierFlags.contains(.shift)
    }

    /// Handles a plain click on list background when AppKit emits no
    /// row-selection transition (for example, when selected typeface rows
    /// are currently hidden by collapsed families).
    private func handleBackgroundClickWithoutSelectionChange() {
        guard !isApplyingReload else { return }
        guard !currentSelectedTypefaceIDs.isEmpty else { return }

        outlineView.deselectAll(nil)
        selectionResolver.resetCache()
        currentSelectedTypefaceIDs = []
        applySelectionTints(forFamilies: snapshot.families, using: [])
        onSelectionChanged?([], false)
    }
}

// MARK: - FontListOutlineView

private final class FontListOutlineView: NSOutlineView {

    /// Invoked when the user Command-clicks a section row. Lets the host
    /// route the gesture through the unified `.toggleAdditive` intent so a
    /// fully-selected family flips to `.none` (which AppKit's selection
    /// pipeline alone won't do — the typeface rows would remain in the
    /// proposed selection and `FontListSelectionResolver` would re-inject
    /// the section row).
    var onSectionCommandClick: ((FontFamilySection) -> Void)?
    var onBackgroundClickWithoutSelectionChange: (() -> Void)?

    /// Suppresses the built-in disclosure triangle.
    /// Expansion/collapse is driven manually via the custom disclosure button on `FontListSectionCellView`.
    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        .zero
    }

    override func mouseDown(with event: NSEvent) {
        let selectionBeforeClick = selectedRowIndexes
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) {
            let pointInView = convert(event.locationInWindow, from: nil)
            let row = row(at: pointInView)
            if row >= 0, let section = item(atRow: row) as? FontFamilySection {
                onSectionCommandClick?(section)
                return
            }
        }
        super.mouseDown(with: event)

        // Match grid semantics for background clicks.
        if modifiers.contains(.command) || modifiers.contains(.shift) {
            return
        }

        let pointInView = convert(event.locationInWindow, from: nil)
        guard row(at: pointInView) < 0 else { return }
        // Only fire the callback if AppKit did not already emit a row selection
        // change during super.mouseDown. This guards against duplicate updates
        // when clicking on a visible row (which already fires selectionDidChange).
        // The callback is only needed for the edge case where selected typeface
        // rows are hidden by collapse and clicking the background produces no
        // selection transition from AppKit.
        guard selectedRowIndexes == selectionBeforeClick else { return }
        onBackgroundClickWithoutSelectionChange?()
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
        true
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        switch item {
        case let section as FontFamilySection:
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

        case let typeface as FontTypefaceItem:
            let cell = outlineView.makeView(
                withIdentifier: FontListRowCellView.identifier,
                owner: self
            ) as? FontListRowCellView ?? FontListRowCellView()
            cell.identifier = FontListRowCellView.identifier
            cell.configure(with: typeface)
            return cell

        default:
            return nil
        }
    }

    /// Normalizes the user's proposed selection so the outline view never
    /// settles on an inconsistent state — e.g. selecting all of a family's
    /// typefaces should also light up the section row, and selecting a section
    /// row should pull in all of its typefaces.
    ///
    /// AppKit only invokes this method for user-initiated changes (mouse,
    /// keyboard); programmatic `selectRowIndexes(_:byExtendingSelection:)`
    /// calls and selection side effects from `reloadData()` /
    /// `expandItem` / `collapseItem` bypass it, so no re-entrancy guard is
    /// needed.
    func outlineView(
        _ outlineView: NSOutlineView,
        selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet
    ) -> IndexSet {
        // During a drag, the proposal is a geometric rectangle that can grow
        // *or shrink* from tick to tick — shrinking removes rows from
        // `proposed` that were in `previous`, which looks identical to a
        // Cmd+click hole-punch if judged by set diff alone. The event type
        // disambiguates: `.leftMouseDragged` means "drag in progress", in
        // which case the section row's presence in `proposed` is
        // authoritative and we must not treat row removals as hole punches.
        let isDragGesture = NSApp.currentEvent?.type == .leftMouseDragged
        let hasCommandModifier = NSApp.currentEvent?.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.command) ?? false
        return selectionResolver.resolve(
            proposed: proposedSelectionIndexes,
            isDragGesture: isDragGesture,
            hasCommandModifier: hasCommandModifier
        )
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingReload else { return }
        // The current gesture has committed. Drop the resolver's per-gesture
        // proposal cache so a later gesture that happens to produce the
        // same `proposed` IndexSet (e.g. Cmd+click on the only typeface of
        // a single-typeface family, after a plain click selected the
        // family) is not short-circuited to the stale cached resolution.
        selectionResolver.resetCache()
        onSelectionChanged?(
            typefacesForCurrentSelection(),
            preservesHiddenSelectionForCurrentEvent()
        )
    }

    /// AppKit posts `selectionIsChanging` continuously during the mouse
    /// tracking loop but defers `selectionDidChange` until mouse-up. We use
    /// the in-progress notification to refresh section header tints live so
    /// a previously `.partial` family loses its accent color as soon as the
    /// user mouses down on a row in another family. The committed selection
    /// — and the upstream `onSelectionChanged` notification that drives the
    /// detail panel — is intentionally still posted only from
    /// `outlineViewSelectionDidChange`.
    func outlineViewSelectionIsChanging(_ notification: Notification) {
        guard !isApplyingReload else { return }
        let inProgressTypefaceIDs = Set(typefacesForCurrentSelection().map { $0.id })
        applySelectionTints(forFamilies: snapshot.families, using: inProgressTypefaceIDs)
    }
}
