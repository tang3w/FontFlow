//
//  FontGridViewController.swift
//  FontFlow
//
//  Created on 2026/3/22.
//

import Cocoa
import CoreData

// MARK: - FontGridViewController

class FontGridViewController: NSViewController, FontBrowserChildViewControlling {

    private enum LayoutMetrics {
        static let horizontalEdgeInset: CGFloat = 5
        static let headerHorizontalInset: CGFloat = 0
        static let minimumItemWidth: CGFloat = 110
        static let preferredItemWidth: CGFloat = 125
        static let maximumItemWidth: CGFloat = 160
        static let itemHeightPadding: CGFloat = 32
        static let itemInsets = NSEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        static let sectionTopInset: CGFloat = 0
        static let verticalGroupSpacing: CGFloat = 0
        static let sectionBottomInset: CGFloat = 0
        static let lastSectionBottomInset: CGFloat = 16
    }

    var onSelectionChanged: (([FontRecord], Bool) -> Void)?
    var onSectionToggled: ((String) -> Void)?

    private var collectionView: NSCollectionView!
    private var dataSource: NSCollectionViewDiffableDataSource<FontSectionIdentifier, FontItemIdentifier>!
    private var familyNodes: [FontFamilyNode] = []
    private var fontsByObjectID: [NSManagedObjectID: FontRecord] = [:]
    private var collapsedSections: Set<String> = []
    private var currentColumnCount = 0
    private var lastLayoutWidth: CGFloat = 0
    /// True while a diffable data source apply is in flight, used to suppress
    /// delegate-driven selection notifications that would otherwise feed stale
    /// state back to the parent controller.
    private var isApplyingReload = false
    /// Monotonically increasing counter that lets the `apply` completion handler
    /// detect whether a newer reload has been issued. If the completion fires
    /// for a stale generation it is discarded, preventing it from restoring
    /// outdated selection or prematurely clearing `isApplyingReload`.
    private var reloadGeneration = 0

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = makeLayout()
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.delegate = self

        collectionView.register(
            FontGridItem.self,
            forItemWithIdentifier: FontGridItem.identifier
        )
        collectionView.register(
            FontSectionHeaderView.self,
            forSupplementaryViewOfKind: FontSectionHeaderView.elementKind,
            withIdentifier: FontSectionHeaderView.identifier
        )

        scrollView.documentView = collectionView
        view = scrollView

        configureDataSource()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        invalidateLayoutForWidthChangeIfNeeded()
    }

    // MARK: - FontBrowserChildViewControlling

    func reloadData(
        familyNodes: [FontFamilyNode],
        fontsByObjectID: [NSManagedObjectID: FontRecord],
        selectedObjectIDs: Set<NSManagedObjectID>,
        collapsedSections: Set<String>,
        animatingDifferences: Bool,
        reloadingSections: Set<String>
    ) {
        loadViewIfNeeded()

        self.familyNodes = familyNodes
        self.fontsByObjectID = fontsByObjectID
        self.collapsedSections = collapsedSections

        var snapshot = NSDiffableDataSourceSnapshot<FontSectionIdentifier, FontItemIdentifier>()

        for node in familyNodes {
            let section = FontSectionIdentifier(familyName: node.familyName)
            snapshot.appendSections([section])
            if !collapsedSections.contains(node.familyName) {
                let items = node.fonts.map { FontItemIdentifier(objectID: $0.objectID) }
                snapshot.appendItems(items, toSection: section)
            }
        }

        if !reloadingSections.isEmpty {
            let sectionsToReload = snapshot.sectionIdentifiers.filter { reloadingSections.contains($0.familyName) }
            snapshot.reloadSections(sectionsToReload)
        }

        reloadGeneration += 1
        let generation = reloadGeneration
        isApplyingReload = true
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences) { [weak self] in
            guard let self = self, self.reloadGeneration == generation else { return }
            self.restoreSelection(with: selectedObjectIDs)
            self.isApplyingReload = false
        }
    }

    func visibleFontObjectIDs() -> Set<NSManagedObjectID> {
        Set(
            familyNodes
                .filter { !collapsedSections.contains($0.familyName) }
                .flatMap { $0.fonts.map { $0.objectID } }
        )
    }

    // MARK: - Data Source

    private func configureDataSource() {
        dataSource = NSCollectionViewDiffableDataSource<FontSectionIdentifier, FontItemIdentifier>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, itemIdentifier in
            guard let self = self,
                  let record = self.fontsByObjectID[itemIdentifier.objectID] else {
                return collectionView.makeItem(
                    withIdentifier: FontGridItem.identifier,
                    for: indexPath
                )
            }

            let item = collectionView.makeItem(
                withIdentifier: FontGridItem.identifier,
                for: indexPath
            ) as! FontGridItem
            item.configure(with: record)
            return item
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == FontSectionHeaderView.elementKind,
                  let self = self else { return nil }

            let headerView = collectionView.makeSupplementaryView(
                ofKind: kind,
                withIdentifier: FontSectionHeaderView.identifier,
                for: indexPath
            ) as! FontSectionHeaderView

            let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            let isCollapsed = self.collapsedSections.contains(section.familyName)
            let totalCount = self.familyNodes.first(where: { $0.familyName == section.familyName })?.fonts.count ?? 0
            headerView.configure(
                familyName: section.familyName,
                count: totalCount,
                isCollapsed: isCollapsed,
                onToggle: { [weak self] in
                    self?.onSectionToggled?(section.familyName)
                }
            )
            return headerView
        }
    }

    // MARK: - Layout

    private func makeLayout() -> NSCollectionViewCompositionalLayout {
        NSCollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            self?.makeGridSection(sectionIndex: sectionIndex, for: environment)
                ?? Self.makeFallbackSection(for: environment)
        }
    }

    private func makeGridSection(
        sectionIndex: Int,
        for environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let contentWidth = max(
            environment.container.effectiveContentSize.width - (LayoutMetrics.horizontalEdgeInset * 2),
            LayoutMetrics.minimumItemWidth
        )
        let columnCount = resolvedColumnCount(for: contentWidth)
        // Only the final section gets extra bottom space so the last visible row
        // sits above the scroll view's adjusted bottom edge. Earlier sections
        // keep a zero bottom inset to avoid introducing gaps between families.
        let bottomInset = sectionIndex == familyNodes.indices.last
            ? LayoutMetrics.lastSectionBottomInset
            : LayoutMetrics.sectionBottomInset
        return Self.makeSection(
            contentWidth: contentWidth,
            columnCount: columnCount,
            bottomInset: bottomInset
        )
    }

    private func resolvedColumnCount(for availableWidth: CGFloat) -> Int {
        var columnCount = currentColumnCount > 0
            ? currentColumnCount
            : max(1, Int(availableWidth / LayoutMetrics.preferredItemWidth))
        var itemWidth = availableWidth / CGFloat(columnCount)

        while itemWidth < LayoutMetrics.minimumItemWidth, columnCount > 1 {
            columnCount -= 1
            itemWidth = availableWidth / CGFloat(columnCount)
        }

        while itemWidth > LayoutMetrics.maximumItemWidth {
            let nextColumnCount = columnCount + 1
            let nextItemWidth = availableWidth / CGFloat(nextColumnCount)

            guard nextItemWidth >= LayoutMetrics.minimumItemWidth else {
                break
            }

            columnCount = nextColumnCount
            itemWidth = nextItemWidth
        }

        currentColumnCount = columnCount
        return columnCount
    }

    private func invalidateLayoutForWidthChangeIfNeeded() {
        let width = (view as? NSScrollView)?.contentView.bounds.width ?? view.bounds.width

        guard abs(width - lastLayoutWidth) > 0.5 else {
            return
        }

        lastLayoutWidth = width
        collectionView.collectionViewLayout?.invalidateLayout()
    }

    private func restoreSelection(with objectIDs: Set<NSManagedObjectID>) {
        let indexPaths = Set(objectIDs.compactMap { objectID in
            dataSource.indexPath(for: FontItemIdentifier(objectID: objectID))
        })
        collectionView.deselectAll(nil)
        if !indexPaths.isEmpty {
            collectionView.selectItems(at: indexPaths, scrollPosition: [])
        }
    }

    private static func makeFallbackSection(for environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let contentWidth = max(
            environment.container.effectiveContentSize.width - (LayoutMetrics.horizontalEdgeInset * 2),
            LayoutMetrics.minimumItemWidth
        )
        let columnCount = max(1, Int(contentWidth / LayoutMetrics.preferredItemWidth))
        return makeSection(
            contentWidth: contentWidth,
            columnCount: columnCount,
            bottomInset: LayoutMetrics.sectionBottomInset
        )
    }

    private static func makeSection(
        contentWidth: CGFloat,
        columnCount: Int,
        bottomInset: CGFloat
    ) -> NSCollectionLayoutSection {
        // Keep each item width on a whole-point boundary so item self-sizing stays
        // stable. The grid item measures its preferred height from the resolved
        // width, and fractional widths can make multiline label wrapping flip
        // between line breaks during layout.
        let itemWidth = floor(contentWidth / CGFloat(columnCount))
        let estimatedItemHeight = itemWidth + LayoutMetrics.itemHeightPadding
        let usedWidth = itemWidth * CGFloat(columnCount)
        let leftoverWidth = max(0, contentWidth - usedWidth)
        // Redistribute the width trimmed by `floor` between columns so the grid
        // keeps its fixed outer insets instead of drifting extra space to the
        // trailing edge.
        let interItemSpacing = columnCount > 1
            ? leftoverWidth / CGFloat(columnCount - 1)
            : 0

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth),
            heightDimension: .estimated(estimatedItemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: LayoutMetrics.itemInsets.top,
            leading: LayoutMetrics.itemInsets.left,
            bottom: LayoutMetrics.itemInsets.bottom,
            trailing: LayoutMetrics.itemInsets.right
        )

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(estimatedItemHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: Array(repeating: item, count: columnCount)
        )
        group.interItemSpacing = .fixed(interItemSpacing)
        group.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: LayoutMetrics.horizontalEdgeInset,
            bottom: 0,
            trailing: LayoutMetrics.horizontalEdgeInset
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = LayoutMetrics.verticalGroupSpacing
        // This inset is supplied per section so callers can add trailing space
        // only after the last grid row, without changing every section layout.
        section.contentInsets = NSDirectionalEdgeInsets(
            top: LayoutMetrics.sectionTopInset,
            leading: 0,
            bottom: bottomInset,
            trailing: 0
        )

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(FontSectionHeaderView.estimatedHeight)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: FontSectionHeaderView.elementKind,
            alignment: .top
        )
        header.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: LayoutMetrics.headerHorizontalInset,
            bottom: 0,
            trailing: LayoutMetrics.headerHorizontalInset
        )
        header.pinToVisibleBounds = true
        section.boundarySupplementaryItems = [header]

        return section
    }
}

// MARK: - NSCollectionViewDelegate

extension FontGridViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard !isApplyingReload else { return }
        notifySelectionChanged()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        guard !isApplyingReload else { return }
        notifySelectionChanged()
    }

    private func notifySelectionChanged() {
        let selectedRecords = collectionView.selectionIndexPaths.compactMap { indexPath -> FontRecord? in
            guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else { return nil }
            return fontsByObjectID[itemIdentifier.objectID]
        }
        onSelectionChanged?(selectedRecords, preservesHiddenSelectionForCurrentEvent())
    }

    private func preservesHiddenSelectionForCurrentEvent() -> Bool {
        let modifierFlags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        return modifierFlags.contains(.command) || modifierFlags.contains(.shift)
    }
}
