//
//  FontPreviewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreData

/// Pure preview controller: renders font previews in an NSCollectionView.
/// Receives fonts and display parameters externally, renders them.
class FontPreviewController: NSViewController, FontPreviewCellDelegate {

    // MARK: - State

    private(set) var currentFonts: [FontRecord] = []
    private var currentSampleText: String = ScriptSamples.default.sampleText
    private var currentFontSize: CGFloat = 48
    private var currentTextStyle = FontPreviewTextStyle.default
    private var currentVariationValues: [UInt32: Double] = [:]
    private var isSampleEditable = false

    // MARK: - Views

    private var collectionView: NSCollectionView!
    private var dataSource: NSCollectionViewDiffableDataSource<Int, NSManagedObjectID>!

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = makeLayout()
        collectionView.isSelectable = false
        collectionView.backgroundColors = [.clear]

        collectionView.register(
            FontPreviewCell.self,
            forItemWithIdentifier: FontPreviewCell.identifier
        )

        scrollView.documentView = collectionView
        view = scrollView

        configureDataSource()
    }

    // MARK: - Public API

    func configure(fonts: [FontRecord]) {
        currentFonts = fonts
        applySnapshot()
    }

    func setSampleText(_ text: String) {
        currentSampleText = text
        refreshVisibleCellsAndLayout()
    }

    func setFontSize(_ size: CGFloat) {
        currentFontSize = size
        refreshVisibleCellsAndLayout()
    }

    func setLineSpacing(_ spacing: CGFloat) {
        var nextStyle = currentTextStyle
        nextStyle.lineSpacingMultiplier = spacing
        setTextStyle(nextStyle)
    }

    func setTextStyle(_ style: FontPreviewTextStyle) {
        let shouldInvalidateLayout = style.lineSpacingMultiplier != currentTextStyle.lineSpacingMultiplier
        currentTextStyle = style
        refreshVisibleCellsAndLayout(invalidateLayout: shouldInvalidateLayout)
    }

    func setVariationValues(_ values: [UInt32: Double]) {
        currentVariationValues = values
        refreshVisibleCellsAndLayout()
    }

    // MARK: - Data Source

    private func configureDataSource() {
        dataSource = NSCollectionViewDiffableDataSource<Int, NSManagedObjectID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, objectID in
            guard let self = self else {
                return collectionView.makeItem(withIdentifier: FontPreviewCell.identifier, for: indexPath)
            }

            let item = collectionView.makeItem(
                withIdentifier: FontPreviewCell.identifier,
                for: indexPath
            ) as! FontPreviewCell
            self.configure(item, at: indexPath)
            return item
        }
    }

    // MARK: - Snapshot

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>()
        snapshot.appendSections([0])
        snapshot.appendItems(currentFonts.map { $0.objectID }, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func refreshVisibleCellsAndLayout(invalidateLayout: Bool = true) {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems()

        for indexPath in visibleIndexPaths {
            guard let item = collectionView.item(at: indexPath) as? FontPreviewCell,
                  indexPath.item < currentFonts.count else { continue }
            configure(item, at: indexPath)
        }

        if invalidateLayout {
            collectionView.collectionViewLayout?.invalidateLayout()
        }

        guard !visibleIndexPaths.isEmpty else { return }
        collectionView.reloadItems(at: Set(visibleIndexPaths))
    }

    private func configure(_ item: FontPreviewCell, at indexPath: IndexPath) {
        item.delegate = self

        guard indexPath.item < currentFonts.count else { return }

        let record = currentFonts[indexPath.item]
        let variations = currentFonts.count == 1 ? currentVariationValues : nil
        item.configure(
            record: record,
            sampleText: currentSampleText,
            fontSize: currentFontSize,
            textStyle: currentTextStyle,
            variationValues: variations,
            isEditable: isSampleEditable
        )
    }

    func fontPreviewCell(_ cell: FontPreviewCell, didChangeSampleText text: String) {
        guard text != currentSampleText else { return }
        setSampleText(text)
    }

    // MARK: - Layout

    private func makeLayout() -> NSCollectionViewCompositionalLayout {
        NSCollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(200)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(200)
            )
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 16
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            return section
        }
    }
}
