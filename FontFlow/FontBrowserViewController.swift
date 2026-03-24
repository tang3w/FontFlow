//
//  FontBrowserViewController.swift
//  FontFlow
//
//  Created on 2026/3/22.
//

import Cocoa
import CoreData

// MARK: - Delegate

protocol FontBrowserSelectionDelegate: AnyObject {
    func fontBrowserDidSelectFonts(_ browser: FontBrowserViewController, fonts: [FontRecord])
}

// MARK: - Data Model

/// A family group in the font list.
class FontFamilyNode {
    let familyName: String
    let fonts: [FontRecord]

    init(familyName: String, fonts: [FontRecord]) {
        self.familyName = familyName
        self.fonts = fonts
    }
}

// MARK: - View Mode

enum FontViewMode: Int {
    case grid = 0
    case list = 1
}

// MARK: - Diffable Data Source Identifiers

struct FontSectionIdentifier: Hashable {
    let familyName: String
}

struct FontItemIdentifier: Hashable {
    let objectID: NSManagedObjectID
}

// MARK: - Child View Controller Protocol

protocol FontBrowserChildViewControlling: AnyObject {
    var onSelectionChanged: (([FontRecord]) -> Void)? { get set }
    var onSectionToggled: ((String) -> Void)? { get set }
    func reloadData(
        familyNodes: [FontFamilyNode],
        fontsByObjectID: [NSManagedObjectID: FontRecord],
        collapsedSections: Set<String>,
        animatingDifferences: Bool,
        reloadingSections: Set<String>
    )
}

// MARK: - FontBrowserViewController

class FontBrowserViewController: NSViewController {

    private enum LayoutMetrics {
        static let headerContentHeight: CGFloat = 44
    }

    weak var delegate: FontBrowserSelectionDelegate?
    var managedObjectContext: NSManagedObjectContext!

    private var familyNodes: [FontFamilyNode] = []
    private var fontsByObjectID: [NSManagedObjectID: FontRecord] = [:]
    private var currentViewMode: FontViewMode = .grid
    private var collapsedSections: Set<String> = []

    private let childHostingView = AdditionalSafeAreaHostingView(
        additionalInsets: NSEdgeInsets(top: LayoutMetrics.headerContentHeight, left: 0, bottom: 0, right: 0)
    )
    private let gridViewController = FontGridViewController()
    private let listViewController = FontListViewController()
    private var activeChild: (NSViewController & FontBrowserChildViewControlling)?

    private let headerView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.material = .headerView
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        childHostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childHostingView)
        view.addSubview(headerView)

        NSLayoutConstraint.activate([
            childHostingView.topAnchor.constraint(equalTo: view.topAnchor),
            childHostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childHostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childHostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: LayoutMetrics.headerContentHeight)
        ])

        wireChild(gridViewController)
        wireChild(listViewController)

        showChild(gridViewController)
    }

    private func wireChild(_ child: NSViewController & FontBrowserChildViewControlling) {
        child.onSelectionChanged = { [weak self] fonts in
            guard let self = self else { return }
            self.delegate?.fontBrowserDidSelectFonts(self, fonts: fonts)
        }
        child.onSectionToggled = { [weak self] familyName in
            self?.toggleSection(familyName)
        }
    }

    private func showChild(_ child: NSViewController & FontBrowserChildViewControlling) {
        if let current = activeChild {
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        childHostingView.addSubview(child.view)

        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: childHostingView.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: childHostingView.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: childHostingView.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: childHostingView.bottomAnchor)
        ])

        activeChild = child
    }

    // MARK: - Public

    /// Updates the fetch predicate, re-fetches font records, groups by family, and reloads the active child.
    func updatePredicate(_ predicate: NSPredicate?) {
        let request = FontRecord.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: "familyName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
            NSSortDescriptor(key: "styleName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
        ]
        let records = (try? managedObjectContext.fetch(request)) ?? []
        familyNodes = buildFamilyNodes(from: records)

        fontsByObjectID = [:]
        for record in records {
            fontsByObjectID[record.objectID] = record
        }

        activeChild?.reloadData(
            familyNodes: familyNodes,
            fontsByObjectID: fontsByObjectID,
            collapsedSections: collapsedSections,
            animatingDifferences: false,
            reloadingSections: []
        )
        delegate?.fontBrowserDidSelectFonts(self, fonts: [])
    }

    /// Switches between list and grid view modes.
    func setViewMode(_ mode: FontViewMode) {
        guard mode != currentViewMode else { return }
        currentViewMode = mode

        let child: NSViewController & FontBrowserChildViewControlling = mode == .list ? listViewController : gridViewController
        showChild(child)

        activeChild?.reloadData(
            familyNodes: familyNodes,
            fontsByObjectID: fontsByObjectID,
            collapsedSections: collapsedSections,
            animatingDifferences: false,
            reloadingSections: []
        )
    }

    // MARK: - Section Toggle

    private func toggleSection(_ familyName: String) {
        if collapsedSections.contains(familyName) {
            collapsedSections.remove(familyName)
        } else {
            collapsedSections.insert(familyName)
        }

        activeChild?.reloadData(
            familyNodes: familyNodes,
            fontsByObjectID: fontsByObjectID,
            collapsedSections: collapsedSections,
            // Keep section toggles non-animated so pinned headers resize immediately
            // when the scroll view autohides its vertical scroller.
            animatingDifferences: false,
            reloadingSections: [familyName]
        )
    }

    // MARK: - Grouping

    private func buildFamilyNodes(from records: [FontRecord]) -> [FontFamilyNode] {
        var grouped: [(String, [FontRecord])] = []
        var currentFamily: String?
        var currentRecords: [FontRecord] = []

        for record in records {
            let family = record.familyName ?? "Unknown"
            if family == currentFamily {
                currentRecords.append(record)
            } else {
                if let name = currentFamily {
                    grouped.append((name, currentRecords))
                }
                currentFamily = family
                currentRecords = [record]
            }
        }
        if let name = currentFamily {
            grouped.append((name, currentRecords))
        }

        return grouped.map { FontFamilyNode(familyName: $0.0, fonts: $0.1) }
    }
}
