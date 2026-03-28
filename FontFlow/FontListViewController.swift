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
        static let indentationPerLevel: CGFloat = 14
        static let sectionRowHeight: CGFloat = 28
        static let fontRowHeight: CGFloat = 24
    }

    var onSelectionChanged: (([FontRecord]) -> Void)?
    var onSectionToggled: ((String) -> Void)?

    private var outlineView: NSOutlineView!
    private var familyNodes: [FontFamilyNode] = []
    private var fontsByObjectID: [NSManagedObjectID: FontRecord] = [:]
    private var collapsedSections: Set<String> = []
    private var isApplyingReload = false
    private var isSynchronizingExpansionState = false

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.style = .fullWidth
        outlineView.rowSizeStyle = .default
        outlineView.backgroundColor = .clear
        outlineView.focusRingType = .none
        outlineView.allowsMultipleSelection = true
        outlineView.allowsEmptySelection = true
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
        familyNodes: [FontFamilyNode],
        fontsByObjectID: [NSManagedObjectID: FontRecord],
        collapsedSections: Set<String>,
        animatingDifferences: Bool,
        reloadingSections: Set<String>
    ) {
        loadViewIfNeeded()

        let previouslySelectedObjectIDs = selectedFontObjectIDs()

        self.familyNodes = familyNodes
        self.fontsByObjectID = fontsByObjectID
        self.collapsedSections = collapsedSections

        isApplyingReload = true
        outlineView.reloadData()
        synchronizeExpansionState()
        restoreSelection(with: previouslySelectedObjectIDs)
        isApplyingReload = false

        if selectedFontObjectIDs() != previouslySelectedObjectIDs {
            notifySelectionChanged()
        }
    }

    // MARK: - Helpers

    private func synchronizeExpansionState() {
        isSynchronizingExpansionState = true
        defer { isSynchronizingExpansionState = false }

        for familyNode in familyNodes {
            if collapsedSections.contains(familyNode.familyName) {
                if outlineView.isItemExpanded(familyNode) {
                    outlineView.collapseItem(familyNode, collapseChildren: true)
                }
            } else if !outlineView.isItemExpanded(familyNode) {
                outlineView.expandItem(familyNode, expandChildren: false)
            }
        }
    }

    private func restoreSelection(with objectIDs: Set<NSManagedObjectID>) {
        let rows = objectIDs.reduce(into: IndexSet()) { result, objectID in
            guard let record = fontsByObjectID[objectID] else { return }

            let row = outlineView.row(forItem: record)
            if row >= 0 {
                result.insert(row)
            }
        }

        outlineView.selectRowIndexes(rows, byExtendingSelection: false)
    }

    private func selectedFontObjectIDs() -> Set<NSManagedObjectID> {
        Set(selectedFontRecords().map { $0.objectID })
    }

    private func selectedFontRecords() -> [FontRecord] {
        outlineView.selectedRowIndexes.compactMap { row in
            outlineView.item(atRow: row) as? FontRecord
        }
    }

    private func notifySelectionChanged() {
        onSelectionChanged?(selectedFontRecords())
    }
}

// MARK: - NSOutlineViewDataSource

extension FontListViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        switch item {
        case nil:
            return familyNodes.count
        case let familyNode as FontFamilyNode:
            return familyNode.fonts.count
        default:
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        switch item {
        case nil:
            return familyNodes[index]
        case let familyNode as FontFamilyNode:
            return familyNode.fonts[index]
        default:
            fatalError("Unexpected outline item")
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let familyNode = item as? FontFamilyNode else { return false }
        return !familyNode.fonts.isEmpty
    }
}

// MARK: - NSOutlineViewDelegate

extension FontListViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        item is FontFamilyNode ? LayoutMetrics.sectionRowHeight : LayoutMetrics.fontRowHeight
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        item is FontRecord
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let familyNode = item as? FontFamilyNode {
            let cell = outlineView.makeView(
                withIdentifier: FontListSectionCellView.identifier,
                owner: self
            ) as? FontListSectionCellView ?? FontListSectionCellView()
            cell.identifier = FontListSectionCellView.identifier
            cell.configure(
                familyName: familyNode.familyName,
                count: familyNode.fonts.count,
                onToggle: { [weak self] in
                    self?.onSectionToggled?(familyNode.familyName)
                }
            )
            return cell
        }

        guard let record = item as? FontRecord else { return nil }

        let cell = outlineView.makeView(
            withIdentifier: FontListRowCellView.identifier,
            owner: self
        ) as? FontListRowCellView ?? FontListRowCellView()
        cell.identifier = FontListRowCellView.identifier
        cell.configure(with: record)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingReload else { return }
        notifySelectionChanged()
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !isSynchronizingExpansionState,
              let familyNode = notification.userInfo?["NSObject"] as? FontFamilyNode else {
            return
        }

        onSectionToggled?(familyNode.familyName)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !isSynchronizingExpansionState,
              let familyNode = notification.userInfo?["NSObject"] as? FontFamilyNode else {
            return
        }

        onSectionToggled?(familyNode.familyName)
    }
}
