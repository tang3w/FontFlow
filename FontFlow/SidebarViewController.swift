//
//  SidebarViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreData

// MARK: - Data Model

/// Static library filter items shown in the sidebar.
enum LibraryFilter {
    case allFonts
    case favorites
    case recentlyAdded
}

/// The content a sidebar row represents.
enum SidebarItem {
    case header(String)
    case libraryItem(LibraryFilter)
    case collection(FontCollection)
    case projectSet(ProjectSet)
    case tag(Tag)
}

/// Reference-type wrapper for outline view items (NSOutlineView requires pointer identity).
class SidebarNode {
    let item: SidebarItem
    var children: [SidebarNode]

    init(_ item: SidebarItem, children: [SidebarNode] = []) {
        self.item = item
        self.children = children
    }
}

// MARK: - Delegate

protocol SidebarSelectionDelegate: AnyObject {
    func sidebarDidSelectItem(_ sidebar: SidebarViewController, item: SidebarItem)
}

// MARK: - SidebarViewController

class SidebarViewController: NSViewController {

    weak var delegate: SidebarSelectionDelegate?
    var managedObjectContext: NSManagedObjectContext!

    private var scrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var rootNodes: [SidebarNode] = []
    private var hasSelectedInitialItem = false

    // MARK: - Lifecycle

    override func loadView() {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView = scrollView

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.dataSource = self
        outlineView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView

        containerView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSidebarTree()
        outlineView.reloadData()
        expandAllSections()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !hasSelectedInitialItem {
            hasSelectedInitialItem = true
            selectAllFonts()
        }
    }

    // MARK: - Public

    /// Re-fetches dynamic sections (Collections, Project Sets, Tags) from Core Data and reloads.
    func reloadSidebar() {
        buildSidebarTree()
        outlineView.reloadData()
        expandAllSections()
    }

    // MARK: - Tree Building

    private func buildSidebarTree() {
        rootNodes = [
            buildLibrarySection(),
            buildCollectionsSection(),
            buildProjectSetsSection(),
            buildTagsSection(),
        ]
    }

    private func buildLibrarySection() -> SidebarNode {
        SidebarNode(.header("Fonts"), children: [
            SidebarNode(.libraryItem(.allFonts)),
            SidebarNode(.libraryItem(.favorites)),
            SidebarNode(.libraryItem(.recentlyAdded)),
        ])
    }

    private func buildCollectionsSection() -> SidebarNode {
        let request = FontCollection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        let collections = (try? managedObjectContext.fetch(request)) ?? []
        let children = collections.map { SidebarNode(.collection($0)) }
        return SidebarNode(.header("Collections"), children: children)
    }

    private func buildProjectSetsSection() -> SidebarNode {
        let request = ProjectSet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        let sets = (try? managedObjectContext.fetch(request)) ?? []
        let children = sets.map { SidebarNode(.projectSet($0)) }
        return SidebarNode(.header("Project Sets"), children: children)
    }

    private func buildTagsSection() -> SidebarNode {
        let request = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let tags = (try? managedObjectContext.fetch(request)) ?? []
        let children = tags.map { SidebarNode(.tag($0)) }
        return SidebarNode(.header("Tags"), children: children)
    }

    // MARK: - Helpers

    private func expandAllSections() {
        for node in rootNodes {
            outlineView.expandItem(node)
        }
    }

    private func selectAllFonts() {
        guard let libraryNode = rootNodes.first,
              let allFontsNode = libraryNode.children.first else { return }
        let row = outlineView.row(forItem: allFontsNode)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }
}

// MARK: - NSOutlineViewDataSource

extension SidebarViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return rootNodes.count }
        guard let node = item as? SidebarNode else { return 0 }
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return rootNodes[index] }
        guard let node = item as? SidebarNode else { fatalError("Unexpected outline item") }
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        return !node.children.isEmpty
    }
}

// MARK: - NSOutlineViewDelegate

extension SidebarViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }

        switch node.item {
        case .header(let title):
            return makeHeaderCell(title: title)
        case .libraryItem(let filter):
            return makeItemCell(title: filter.title, symbolName: filter.symbolName)
        case .collection(let collection):
            return makeItemCell(title: collection.name ?? "Untitled", symbolName: "folder")
        case .projectSet(let projectSet):
            return makeItemCell(title: projectSet.name ?? "Untitled", symbolName: "briefcase")
        case .tag(let tag):
            return makeItemCell(title: tag.name ?? "Untitled", symbolName: "tag")
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        if case .header = node.item { return true }
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        if case .header = node.item { return false }
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? SidebarNode else { return }
        delegate?.sidebarDidSelectItem(self, item: node.item)
    }

    // MARK: - Cell Factories

    private func makeHeaderCell(title: String) -> NSTableCellView {
        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: title.capitalized)
        textField.font = .systemFont(ofSize: 11, weight: .semibold)
        textField.textColor = .secondaryLabelColor
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)
        cell.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    private func makeItemCell(title: String, symbolName: String) -> NSTableCellView {
        let cell = NSTableCellView()

        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let textField = NSTextField(labelWithString: title)
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

// MARK: - LibraryFilter Helpers

extension LibraryFilter {
    var title: String {
        switch self {
        case .allFonts: return "All Fonts"
        case .favorites: return "Favorites"
        case .recentlyAdded: return "Recently Added"
        }
    }

    var symbolName: String {
        switch self {
        case .allFonts: return "textformat"
        case .favorites: return "star"
        case .recentlyAdded: return "clock"
        }
    }
}
