//
//  FontListViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreData

// MARK: - Delegate

protocol FontListSelectionDelegate: AnyObject {
    func fontListDidSelectFont(_ fontList: FontListViewController, font: FontRecord?)
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
    case list = 0
    case grid = 1
}

// MARK: - Diffable Data Source Identifiers

struct FontSectionIdentifier: Hashable {
    let familyName: String
}

struct FontItemIdentifier: Hashable {
    let objectID: NSManagedObjectID
}

// MARK: - FontListViewController

class FontListViewController: NSViewController {

    weak var delegate: FontListSelectionDelegate?
    var managedObjectContext: NSManagedObjectContext!

    private var collectionView: NSCollectionView!
    private var dataSource: NSCollectionViewDiffableDataSource<FontSectionIdentifier, FontItemIdentifier>!
    private var familyNodes: [FontFamilyNode] = []
    private var fontsByObjectID: [NSManagedObjectID: FontRecord] = [:]
    private var currentViewMode: FontViewMode = .list

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = makeListLayout()
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.delegate = self

        collectionView.register(
            FontListItem.self,
            forItemWithIdentifier: FontListItem.identifier
        )
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

    // MARK: - Public

    /// Updates the fetch predicate, re-fetches font records, groups by family, and reloads.
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

        applySnapshot(animatingDifferences: false)
        delegate?.fontListDidSelectFont(self, font: nil)
    }

    /// Switches between list and grid view modes.
    func setViewMode(_ mode: FontViewMode) {
        guard mode != currentViewMode else { return }
        currentViewMode = mode

        collectionView.collectionViewLayout = mode == .list ? makeListLayout() : makeGridLayout()

        // Re-apply snapshot to force item re-creation with the correct item class.
        var snapshot = dataSource.snapshot()
        snapshot.reloadSections(snapshot.sectionIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Data Source

    private func configureDataSource() {
        dataSource = NSCollectionViewDiffableDataSource<FontSectionIdentifier, FontItemIdentifier>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, itemIdentifier in
            guard let self = self,
                  let record = self.fontsByObjectID[itemIdentifier.objectID] else {
                return collectionView.makeItem(
                    withIdentifier: FontListItem.identifier,
                    for: indexPath
                )
            }

            switch self.currentViewMode {
            case .list:
                let item = collectionView.makeItem(
                    withIdentifier: FontListItem.identifier,
                    for: indexPath
                ) as! FontListItem
                item.configure(with: record)
                return item
            case .grid:
                let item = collectionView.makeItem(
                    withIdentifier: FontGridItem.identifier,
                    for: indexPath
                ) as! FontGridItem
                item.configure(with: record)
                return item
            }
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
            let itemCount = self.dataSource.snapshot().numberOfItems(inSection: section)
            headerView.configure(familyName: section.familyName, count: itemCount)
            return headerView
        }
    }

    // MARK: - Snapshot

    private func applySnapshot(animatingDifferences: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<FontSectionIdentifier, FontItemIdentifier>()

        for node in familyNodes {
            let section = FontSectionIdentifier(familyName: node.familyName)
            snapshot.appendSections([section])
            let items = node.fonts.map { FontItemIdentifier(objectID: $0.objectID) }
            snapshot.appendItems(items, toSection: section)
        }

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    // MARK: - Layouts

    private func makeListLayout() -> NSCollectionViewCompositionalLayout {
        NSCollectionViewCompositionalLayout { _, environment in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(44)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(44)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)

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

    private func makeGridLayout() -> NSCollectionViewCompositionalLayout {
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

// MARK: - NSCollectionViewDelegate

extension FontListViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first,
              let itemIdentifier = dataSource.itemIdentifier(for: indexPath),
              let record = fontsByObjectID[itemIdentifier.objectID] else {
            return
        }
        delegate?.fontListDidSelectFont(self, font: record)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        if collectionView.selectionIndexPaths.isEmpty {
            delegate?.fontListDidSelectFont(self, font: nil)
        }
    }
}
