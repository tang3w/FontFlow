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
    private var isSynchronizingExpansionState = false

    /// Caches the most recent `(proposed, resolved)` pair returned from
    /// `outlineView(_:selectionIndexesForProposedSelection:)`.
    ///
    /// AppKit re-emits the same `proposed` IndexSet during a drag (mouse move,
    /// autoscroll tick, internal validation) regardless of what the delegate
    /// previously returned. Without this cache, the second callback compares
    /// the raw drag rectangle against our augmented `selectedRowIndexes` and
    /// the section-row heuristic incorrectly drops it. Returning the cached
    /// answer keeps repeated identical proposals idempotent.
    private var lastProposalCache: (proposed: IndexSet, resolved: IndexSet)?

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
        // Row indices may have shifted; any cached proposal is stale.
        lastProposalCache = nil

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
        // Programmatic selection bypasses the delegate's proposal callback, so
        // any cached drag-derived proposal must be discarded.
        lastProposalCache = nil
        let rows = resolveSelectedRowIndexes(for: typefaceIDs)
        outlineView.selectRowIndexes(rows, byExtendingSelection: false)
    }

    /// Computes the set of outline-view rows that should be selected for a given
    /// typeface selection: every selected typeface row, plus the section row of
    /// every family that resolves to `.full`.
    private func resolveSelectedRowIndexes(for typefaceIDs: Set<FontTypefaceID>) -> IndexSet {
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
}

// MARK: - FontListOutlineView

private final class FontListOutlineView: NSOutlineView {

    /// Suppresses the built-in disclosure triangle.
    /// Expansion/collapse is driven manually via the custom disclosure button on `FontListSectionCellView`.
    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        .zero
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
        // Idempotency guard: AppKit may re-issue the same `proposed` IndexSet
        // multiple times for a single user gesture (e.g. while the cursor sits
        // on a row mid-drag). Returning the cached answer for an identical
        // proposal keeps the gesture stable and avoids re-running the
        // section-row heuristic against contaminated state.
        if let cache = lastProposalCache, cache.proposed == proposedSelectionIndexes {
            return cache.resolved
        }

        // Diff against the *previous resolved selection* — i.e. what we last
        // returned and AppKit actually applied. We can't use AppKit's prior
        // raw `proposed` IndexSet because it omits the section-row
        // expansions we add ourselves; that would make a section row appear
        // "newly arriving" on a subsequent click and incorrectly skip the
        // hole-punch path. We can't use `selectedRowIndexes` either, as it
        // can lag mid-gesture. The cached `resolved` is the source of truth.
        // The original drag-contamination concern (proposal shrinks during
        // a drag would look like a member deselect) is handled separately
        // by `isDragGesture` below. On the very first callback there is no
        // cache yet, so fall back to `selectedRowIndexes`, which is correct
        // at that moment.
        let previous = lastProposalCache?.resolved ?? outlineView.selectedRowIndexes
        // During a drag, the proposal is a geometric rectangle that can grow
        // *or shrink* from tick to tick — shrinking removes rows from
        // `proposed` that were in `previous`, which looks identical to a
        // Cmd+click hole-punch if judged by set diff alone. The event type
        // disambiguates: `.leftMouseDragged` means "drag in progress", in
        // which case the section row's presence in `proposed` is
        // authoritative and we must not treat row removals as hole punches.
        let isDragGesture = NSApp.currentEvent?.type == .leftMouseDragged
        let derivedTypefaceIDs = derivedTypefaceIDs(
            fromProposed: proposedSelectionIndexes,
            previous: previous,
            isDragGesture: isDragGesture
        )
        let resolved = resolveSelectedRowIndexes(for: derivedTypefaceIDs)
        lastProposalCache = (proposedSelectionIndexes, resolved)
        return resolved
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        // TODO: Rebuild selection handling from scratch.
    }

    /// Translates the proposed outline-view rows into the underlying typeface
    /// ID set.
    ///
    /// Selected typeface rows always contribute their own id. A selected
    /// section row expands to the whole family *unless* the user just punched
    /// a hole in it with a click — i.e. some typeface of that family was
    /// present in the previous proposal but is now missing from the current
    /// one, AND the triggering event is not a drag. That signature is what
    /// distinguishes:
    ///
    /// - Cmd+click an individual typeface inside a fully-selected family
    ///   (`isDragGesture == false`): exactly one family member drops out of
    ///   `proposed` → don't expand, so the family row deselects and the hole
    ///   is preserved.
    /// - Drag extension or *shrinkage* across the family's typefaces
    ///   (`isDragGesture == true`): rows may be added OR removed as the drag
    ///   rectangle grows and shrinks, but a drag never means "punch a hole".
    ///   Keep the section sticky and expand so the family row stays lit for
    ///   the duration of the drag.
    ///
    /// `previous` must be the prior *proposal*, not the applied selection:
    /// the applied selection contains this method's own section-row
    /// augmentation and would make the diff lie.
    private func derivedTypefaceIDs(
        fromProposed proposed: IndexSet,
        previous: IndexSet,
        isDragGesture: Bool
    ) -> Set<FontTypefaceID> {
        var ids: Set<FontTypefaceID> = []

        for row in proposed {
            switch outlineView.item(atRow: row) {
            case let typeface as FontTypefaceItem:
                ids.insert(typeface.id)

            case let section as FontFamilySection:
                // Hole-punch is a very narrow case: the section row was
                // already "owning" the family in the previous proposal, and
                // a click (not a drag) removed one of its typefaces. All
                // three conditions must hold:
                //
                //   1. The section row was in `previous` — without that,
                //      there was no prior full-family state to punch a hole
                //      in. Newly-arriving section rows (arrow navigation,
                //      plain click on the section, drag onto the section)
                //      always expand.
                //   2. Not all family typefaces are still in `proposed` —
                //      something dropped. When the section was owning the
                //      family, every typeface was effectively selected even
                //      if their individual rows weren't in the prior
                //      `proposed` IndexSet, so the absence of any typeface
                //      row from `proposed` now is the hole signal.
                //   3. The gesture is not a drag — drag rectangles shrink
                //      naturally as the user moves back toward the anchor;
                //      that's not a deselect.
                let sectionRow = outlineView.row(forItem: section)
                let sectionWasOwning = sectionRow >= 0 && previous.contains(sectionRow)
                let someTypefaceMissing = section.typefaces.contains { typeface in
                    let typefaceRow = outlineView.row(forItem: typeface)
                    return typefaceRow >= 0 && !proposed.contains(typefaceRow)
                }
                let familyMemberDeselected = sectionWasOwning
                    && !isDragGesture
                    && someTypefaceMissing
                if !familyMemberDeselected {
                    for typeface in section.typefaces {
                        ids.insert(typeface.id)
                    }
                }

            default:
                continue
            }
        }

        return ids
    }
}
