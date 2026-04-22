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

    func outlineViewSelectionDidChange(_ notification: Notification) {
        // TODO: Rebuild selection handling from scratch.
    }
}
