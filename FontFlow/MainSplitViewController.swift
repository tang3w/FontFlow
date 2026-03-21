//
//  MainSplitViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreData
import UniformTypeIdentifiers

// MARK: - Toolbar Identifiers

extension NSToolbarItem.Identifier {
    static let importFonts = NSToolbarItem.Identifier("importFonts")
    static let viewMode = NSToolbarItem.Identifier("viewMode")
    static let fontSearch = NSToolbarItem.Identifier("fontSearch")
}

// MARK: - MainSplitViewController

class MainSplitViewController: NSSplitViewController {

    private let managedObjectContext: NSManagedObjectContext

    private let sidebarViewController: SidebarViewController
    private let fontListViewController: FontListViewController
    private let fontDetailViewController: FontDetailViewController

    private var currentSidebarPredicate: NSPredicate?
    private var currentSearchPredicate: NSPredicate?

    // MARK: - Init

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext

        sidebarViewController = SidebarViewController()
        sidebarViewController.managedObjectContext = managedObjectContext

        fontListViewController = FontListViewController()
        fontListViewController.managedObjectContext = managedObjectContext

        fontDetailViewController = FontDetailViewController()

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        sidebarViewController.delegate = self
        fontListViewController.delegate = self

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 200
        sidebarItem.canCollapse = true

        let listItem = NSSplitViewItem(contentListWithViewController: fontListViewController)
        listItem.minimumThickness = 250

        let detailItem = NSSplitViewItem(viewController: fontDetailViewController)
        detailItem.minimumThickness = 250

        addSplitViewItem(sidebarItem)
        addSplitViewItem(listItem)
        addSplitViewItem(detailItem)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupToolbar()
    }

    // MARK: - Predicate Composition

    private func updateFontList() {
        let predicates = [currentSidebarPredicate, currentSearchPredicate].compactMap { $0 }
        let combined: NSPredicate? = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fontListViewController.updatePredicate(combined)
    }

    /// Maps a sidebar item to an `NSPredicate` for the font list fetch.
    private func predicate(for item: SidebarItem) -> NSPredicate? {
        switch item {
        case .header:
            return nil
        case .libraryItem(let filter):
            switch filter {
            case .allFonts:
                return nil
            case .favorites:
                return NSPredicate(format: "isFavorite == YES")
            case .recentlyAdded:
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                return NSPredicate(format: "importedDate >= %@", sevenDaysAgo as NSDate)
            }
        case .collection(let collection):
            return NSPredicate(format: "ANY collections == %@", collection)
        case .projectSet(let projectSet):
            return NSPredicate(format: "ANY projectSets == %@", projectSet)
        case .tag(let tag):
            return NSPredicate(format: "ANY tags == %@", tag)
        }
    }

    // MARK: - Toolbar

    private var toolbarConfigured = false

    private func setupToolbar() {
        guard !toolbarConfigured, let window = view.window else { return }
        toolbarConfigured = true

        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
    }

    // MARK: - Actions

    @objc private func importFonts(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "ttf")!,
            UTType(filenameExtension: "otf")!,
            UTType(filenameExtension: "ttc")!,
            UTType(filenameExtension: "otc")!,
            UTType(filenameExtension: "woff")!,
            UTType(filenameExtension: "woff2")!,
        ]

        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let self = self else { return }
            let result = FontImportService.importFonts(
                from: panel.urls,
                context: self.managedObjectContext
            )
            NSLog("Import complete: \(result.importedCount) imported, \(result.duplicateCount) duplicates, \(result.failedCount) failed")
            self.sidebarViewController.reloadSidebar()
            self.updateFontList()
        }
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            currentSearchPredicate = nil
        } else {
            currentSearchPredicate = NSPredicate(
                format: "displayName CONTAINS[cd] %@ OR familyName CONTAINS[cd] %@ OR postScriptName CONTAINS[cd] %@",
                text, text, text
            )
        }
        updateFontList()
    }

    @objc private func viewModeChanged(_ sender: NSToolbarItemGroup) {
        let mode = FontViewMode(rawValue: sender.selectedIndex) ?? .list
        fontListViewController.setViewMode(mode)
    }
}

// MARK: - SidebarSelectionDelegate

extension MainSplitViewController: SidebarSelectionDelegate {

    func sidebarDidSelectItem(_ sidebar: SidebarViewController, item: SidebarItem) {
        currentSidebarPredicate = predicate(for: item)
        updateFontList()
    }
}

// MARK: - FontListSelectionDelegate

extension MainSplitViewController: FontListSelectionDelegate {

    func fontListDidSelectFont(_ fontList: FontListViewController, font: FontRecord?) {
        fontDetailViewController.updateFont(font)
    }
}

// MARK: - NSToolbarDelegate

extension MainSplitViewController: NSToolbarDelegate {

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .importFonts:
            let item = NSToolbarItem(itemIdentifier: .importFonts)
            item.label = "Import"
            item.toolTip = "Import font files or folders"
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Import")
            item.target = self
            item.action = #selector(importFonts(_:))
            return item

        case .fontSearch:
            let item = NSSearchToolbarItem(itemIdentifier: .fontSearch)
            item.searchField.target = self
            item.searchField.action = #selector(searchFieldChanged(_:))
            return item

        case .viewMode:
            let item = NSToolbarItemGroup(itemIdentifier: .viewMode, images: [
                NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "List")!,
                NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Grid")!,
            ], selectionMode: .selectOne, labels: ["List", "Grid"], target: self, action: #selector(viewModeChanged(_:)))
            item.selectedIndex = 0
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.importFonts, .flexibleSpace, .viewMode, .fontSearch]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.importFonts, .viewMode, .fontSearch, .flexibleSpace, .space]
    }
}
