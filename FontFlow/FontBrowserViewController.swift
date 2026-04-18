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

// MARK: - View Mode

enum FontViewMode: Int {
    case grid = 0
    case list = 1
}

// MARK: - Child View Controller Protocol

protocol FontBrowserChildViewControlling: AnyObject {
    var onSelectionChanged: (([FontTypefaceItem], Bool) -> Void)? { get set }
    var onSectionToggled: ((FontFamilyID) -> Void)? { get set }
    func reloadData(
        snapshot: FontBrowserSnapshot,
        selectedTypefaceIDs: Set<FontTypefaceID>,
        collapsedFamilyIDs: Set<FontFamilyID>,
        animatingDifferences: Bool,
        reloadingFamilyIDs: Set<FontFamilyID>
    )
    func visibleTypefaceIDs() -> Set<FontTypefaceID>
    func isPrimaryViewFirstResponder() -> Bool
    func focusPrimaryView()
}

enum FontBrowserSelectionState {
    static func updatedSelection(
        existingTypefaceIDs: Set<FontTypefaceID>,
        visibleTypefaceIDs: Set<FontTypefaceID>,
        selectedVisibleTypefaceIDs: Set<FontTypefaceID>,
        preservesHiddenSelection: Bool
    ) -> Set<FontTypefaceID> {
        guard preservesHiddenSelection else {
            return selectedVisibleTypefaceIDs
        }

        var updated = existingTypefaceIDs
        updated.subtract(visibleTypefaceIDs)
        updated.formUnion(selectedVisibleTypefaceIDs)
        return updated
    }
}

// MARK: - FontBrowserViewController

class FontBrowserViewController: NSViewController {

    private enum LayoutMetrics {
        static let headerContentHeight: CGFloat = 44
        static let headerHorizontalInset: CGFloat = 12
    }

    weak var delegate: FontBrowserSelectionDelegate?
    var managedObjectContext: NSManagedObjectContext!

    private let snapshotBuilder = FontBrowserSnapshotBuilder()
    private var snapshot: FontBrowserSnapshot = .empty
    private var currentViewMode: FontViewMode = .grid
    private var collapsedFamilyIDs: Set<FontFamilyID> = []
    private var selectedTypefaceIDs: Set<FontTypefaceID> = []

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

    private let separatorView: NSBox = {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.fillColor = .separatorColor
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }()

    private let browserCountView = FontBrowserCountView()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        childHostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childHostingView)
        view.addSubview(headerView)
        view.addSubview(separatorView)
        headerView.addSubview(browserCountView)

        NSLayoutConstraint.activate([
            childHostingView.topAnchor.constraint(equalTo: view.topAnchor),
            childHostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childHostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childHostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: LayoutMetrics.headerContentHeight),
            browserCountView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: LayoutMetrics.headerHorizontalInset),
            browserCountView.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -LayoutMetrics.headerHorizontalInset),
            browserCountView.centerYAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -(LayoutMetrics.headerContentHeight / 2)),
            separatorView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])

        browserCountView.update(familyCount: 0, typefaceCount: 0)

        wireChild(gridViewController)
        wireChild(listViewController)

        showChild(gridViewController)
    }

    private func wireChild(_ child: NSViewController & FontBrowserChildViewControlling) {
        child.onSelectionChanged = { [weak self, weak child] typefaces, preservesHiddenSelection in
            guard let self = self, let child = child, self.activeChild === child else { return }
            self.updateSelection(from: child, selectedTypefaces: typefaces, preservesHiddenSelection: preservesHiddenSelection)
        }
        child.onSectionToggled = { [weak self] familyID in
            self?.toggleSection(familyID)
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

    /// Updates the fetch predicate, rebuilds the snapshot, and reloads the active child.
    func updatePredicate(_ predicate: NSPredicate?) {
        snapshot = snapshotBuilder.build(in: managedObjectContext, predicate: predicate)
        browserCountView.update(
            familyCount: snapshot.familyCount,
            typefaceCount: snapshot.totalTypefaceCount
        )

        // Drop any selected/collapsed identifiers that are no longer in the snapshot.
        selectedTypefaceIDs.formIntersection(Set(snapshot.typefaceByID.keys))
        collapsedFamilyIDs.formIntersection(Set(snapshot.familyByID.keys))

        activeChild?.reloadData(
            snapshot: snapshot,
            selectedTypefaceIDs: selectedTypefaceIDs,
            collapsedFamilyIDs: collapsedFamilyIDs,
            animatingDifferences: false,
            reloadingFamilyIDs: []
        )
        delegate?.fontBrowserDidSelectFonts(self, fonts: selectedFontRecords())
    }

    /// Switches between list and grid view modes.
    func setViewMode(_ mode: FontViewMode) {
        guard mode != currentViewMode else { return }
        let shouldRestorePrimaryFocus = activeChild?.isPrimaryViewFirstResponder() ?? false
        currentViewMode = mode

        let child: NSViewController & FontBrowserChildViewControlling = mode == .list ? listViewController : gridViewController
        showChild(child)

        child.reloadData(
            snapshot: snapshot,
            selectedTypefaceIDs: selectedTypefaceIDs,
            collapsedFamilyIDs: collapsedFamilyIDs,
            animatingDifferences: false,
            reloadingFamilyIDs: []
        )

        if shouldRestorePrimaryFocus {
            child.focusPrimaryView()
        }
    }

    // MARK: - Section Toggle

    private func toggleSection(_ familyID: FontFamilyID) {
        if collapsedFamilyIDs.contains(familyID) {
            collapsedFamilyIDs.remove(familyID)
        } else {
            collapsedFamilyIDs.insert(familyID)
        }

        activeChild?.reloadData(
            snapshot: snapshot,
            selectedTypefaceIDs: selectedTypefaceIDs,
            collapsedFamilyIDs: collapsedFamilyIDs,
            // Keep section toggles non-animated so pinned headers resize immediately
            // when the scroll view autohides its vertical scroller.
            animatingDifferences: false,
            reloadingFamilyIDs: [familyID]
        )
    }

    private func updateSelection(
        from child: NSViewController & FontBrowserChildViewControlling,
        selectedTypefaces: [FontTypefaceItem],
        preservesHiddenSelection: Bool
    ) {
        let selectedVisibleIDs = Set(selectedTypefaces.map { $0.id })
        selectedTypefaceIDs = FontBrowserSelectionState.updatedSelection(
            existingTypefaceIDs: selectedTypefaceIDs,
            visibleTypefaceIDs: child.visibleTypefaceIDs(),
            selectedVisibleTypefaceIDs: selectedVisibleIDs,
            preservesHiddenSelection: preservesHiddenSelection
        )

        delegate?.fontBrowserDidSelectFonts(self, fonts: selectedFontRecords())
    }

    private func selectedFontRecords() -> [FontRecord] {
        snapshot.families.flatMap { section in
            section.typefaces
                .filter { selectedTypefaceIDs.contains($0.id) }
                .map { $0.record }
        }
    }
}
