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
        static let sectionRowHeight: CGFloat = 28
        static let fontRowHeight: CGFloat = 24
    }

    var onSelectionChanged: (([FontTypefaceItem], Bool) -> Void)?
    var onSectionToggled: ((FontFamilyID) -> Void)?

    private var outlineView: NSOutlineView!
    private var snapshot: FontBrowserSnapshot = .empty
    private var collapsedFamilyIDs: Set<FontFamilyID> = []
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
        let rows = typefaceIDs.reduce(into: IndexSet()) { result, typefaceID in
            guard let item = snapshot.typefaceByID[typefaceID] else { return }

            let row = outlineView.row(forItem: item)
            if row >= 0 {
                result.insert(row)
            }
        }

        outlineView.selectRowIndexes(rows, byExtendingSelection: false)
    }

    private func selectedTypefaceItems() -> [FontTypefaceItem] {
        outlineView.selectedRowIndexes.compactMap { row in
            outlineView.item(atRow: row) as? FontTypefaceItem
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

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        item is FontFamilySection ? LayoutMetrics.sectionRowHeight : LayoutMetrics.fontRowHeight
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        item is FontTypefaceItem
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let section = item as? FontFamilySection {
            let cell = outlineView.makeView(
                withIdentifier: FontListSectionCellView.identifier,
                owner: self
            ) as? FontListSectionCellView ?? FontListSectionCellView()
            cell.identifier = FontListSectionCellView.identifier
            cell.configure(
                familyName: section.displayName,
                count: section.typefaceCount,
                isCollapsed: collapsedFamilyIDs.contains(section.id),
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
        guard !isApplyingReload else { return }
        notifySelectionChanged()
    }
}
