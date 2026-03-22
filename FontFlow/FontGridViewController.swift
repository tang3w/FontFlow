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

    var onSelectionChanged: (([FontRecord]) -> Void)?
    var onSectionToggled: ((String) -> Void)?

    private var collectionView: NSCollectionView!
    private var dataSource: NSCollectionViewDiffableDataSource<FontSectionIdentifier, FontItemIdentifier>!
    private var familyNodes: [FontFamilyNode] = []
    private var fontsByObjectID: [NSManagedObjectID: FontRecord] = [:]
    private var collapsedSections: Set<String> = []

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

    // MARK: - FontBrowserChildViewControlling

    func reloadData(
        familyNodes: [FontFamilyNode],
        fontsByObjectID: [NSManagedObjectID: FontRecord],
        collapsedSections: Set<String>,
        animatingDifferences: Bool,
        reloadingSections: Set<String>
    ) {
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

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
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
        NSCollectionViewCompositionalLayout { _, environment in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(180),
                heightDimension: .absolute(200)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(200)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(8)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 8
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12)

            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(32)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: FontSectionHeaderView.elementKind,
                alignment: .top
            )
            header.pinToVisibleBounds = true
            section.boundarySupplementaryItems = [header]

            return section
        }
    }
}

// MARK: - NSCollectionViewDelegate

extension FontGridViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        notifySelectionChanged()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        notifySelectionChanged()
    }

    private func notifySelectionChanged() {
        let selectedRecords = collectionView.selectionIndexPaths.compactMap { indexPath -> FontRecord? in
            guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else { return nil }
            return fontsByObjectID[itemIdentifier.objectID]
        }
        onSelectionChanged?(selectedRecords)
    }
}
