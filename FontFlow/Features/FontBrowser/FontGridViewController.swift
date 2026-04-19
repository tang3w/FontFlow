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

    /// Bundles the bookkeeping needed to detect when the compositional
    /// layout's `effectiveContentSize.width` changes between section provider
    /// invocations (e.g. because a data source apply caused the legacy
    /// vertical scroller to appear or disappear).
    private struct EffectiveWidthTracker {
        /// Last width observed by the section provider.
        var lastWidth: CGFloat = 0
        /// `false` until the first observation, so the initial pass is not
        /// misread as a width change.
        var hasObserved = false
        /// `true` while a deferred `invalidateLayout` is queued, preventing
        /// duplicate scheduling when the section provider runs once per
        /// section in the same pass.
        var hasPendingInvalidation = false

        /// Returns `true` when the new width is materially different from the
        /// last observed width and no invalidation is already queued.
        func shouldScheduleInvalidation(for width: CGFloat) -> Bool {
            guard hasObserved, !hasPendingInvalidation else { return false }
            return width != lastWidth
        }

        /// Records the width seen during the current pass.
        mutating func record(_ width: CGFloat) {
            lastWidth = width
            hasObserved = true
        }
    }

    var onSelectionChanged: (([FontTypefaceItem], Bool) -> Void)?
    var onSectionToggled: ((FontFamilyID) -> Void)?
    var onFamilySelectionIntent: ((FontFamilyID, FontFamilySelectionIntent) -> Void)?

    private var collectionView: FontGridCollectionView!
    private var dataSource: NSCollectionViewDiffableDataSource<FontFamilyID, FontTypefaceID>!
    private var snapshot: FontBrowserSnapshot = .empty
    private var collapsedFamilyIDs: Set<FontFamilyID> = []
    private var currentSelectedTypefaceIDs: Set<FontTypefaceID> = []
    private var currentColumnCount = 0
    private var lastLayoutWidth: CGFloat = 0
    /// Tracks the effective content width observed by the compositional
    /// layout's section provider so a mid-apply scroller toggle can be
    /// detected and corrected with a deferred `invalidateLayout`.
    private var effectiveWidthTracker = EffectiveWidthTracker()
    /// True while a diffable data source apply is in flight, used to suppress
    /// delegate-driven selection notifications that would otherwise feed stale
    /// state back to the parent controller.
    private var isApplyingReload = false
    /// Monotonically increasing counter that lets the `apply` completion handler
    /// detect whether a newer reload has been issued. If the completion fires
    /// for a stale generation it is discarded, preventing it from restoring
    /// outdated selection or prematurely clearing `isApplyingReload`.
    private var reloadGeneration = 0
    private var shouldFocusPrimaryViewAfterReload = false

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        collectionView = FontGridCollectionView()
        collectionView.collectionViewLayout = makeLayout()
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.delegate = self
        collectionView.onBackgroundClick = { [weak self] in
            self?.handleBackgroundClick()
        }

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
        snapshot: FontBrowserSnapshot,
        selectedTypefaceIDs: Set<FontTypefaceID>,
        collapsedFamilyIDs: Set<FontFamilyID>,
        animatingDifferences: Bool,
        reloadingFamilyIDs: Set<FontFamilyID>
    ) {
        loadViewIfNeeded()

        self.snapshot = snapshot
        self.collapsedFamilyIDs = collapsedFamilyIDs
        self.currentSelectedTypefaceIDs = selectedTypefaceIDs

        var diffSnapshot = NSDiffableDataSourceSnapshot<FontFamilyID, FontTypefaceID>()

        for section in snapshot.families {
            diffSnapshot.appendSections([section.id])
            if !collapsedFamilyIDs.contains(section.id) {
                let items = section.typefaces.map { $0.id }
                diffSnapshot.appendItems(items, toSection: section.id)
            }
        }

        if !reloadingFamilyIDs.isEmpty {
            let sectionsToReload = diffSnapshot.sectionIdentifiers.filter { reloadingFamilyIDs.contains($0) }
            diffSnapshot.reloadSections(sectionsToReload)
        }

        reloadGeneration += 1
        let generation = reloadGeneration
        isApplyingReload = true
        dataSource.apply(diffSnapshot, animatingDifferences: animatingDifferences) { [weak self] in
            guard let self = self, self.reloadGeneration == generation else { return }
            self.restoreSelection(with: selectedTypefaceIDs)
            self.isApplyingReload = false
            if self.shouldFocusPrimaryViewAfterReload {
                self.shouldFocusPrimaryViewAfterReload = false
                self.focusPrimaryViewIfPossible()
            }
        }
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
        if responder === collectionView {
            return true
        }

        guard let view = responder as? NSView else { return false }
        return view.isDescendant(of: collectionView)
    }

    func focusPrimaryView() {
        loadViewIfNeeded()
        guard !isApplyingReload else {
            shouldFocusPrimaryViewAfterReload = true
            return
        }

        focusPrimaryViewIfPossible()
    }

    func refreshFamilyHeaders(for familyIDs: Set<FontFamilyID>, selectedTypefaceIDs: Set<FontTypefaceID>) {
        loadViewIfNeeded()
        currentSelectedTypefaceIDs = selectedTypefaceIDs
        guard !familyIDs.isEmpty else { return }

        let currentSectionIdentifiers = dataSource.snapshot().sectionIdentifiers
        for familyID in familyIDs {
            guard let sectionIndex = currentSectionIdentifiers.firstIndex(of: familyID) else { continue }
            let indexPath = IndexPath(item: 0, section: sectionIndex)
            guard let headerView = collectionView.supplementaryView(
                forElementKind: FontSectionHeaderView.elementKind,
                at: indexPath
            ) as? FontSectionHeaderView else { continue }

            let section = snapshot.familyByID[familyID]
            let typefaceIDs = section?.typefaces.map { $0.id } ?? []
            let newState = FontFamilySelectionState.resolve(
                typefaceIDs: typefaceIDs,
                selected: selectedTypefaceIDs
            )
            headerView.updateSelectionState(newState)
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        dataSource = NSCollectionViewDiffableDataSource<FontFamilyID, FontTypefaceID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, typefaceID in
            let item = collectionView.makeItem(
                withIdentifier: FontGridItem.identifier,
                for: indexPath
            ) as! FontGridItem

            if let typefaceItem = self?.snapshot.typefaceByID[typefaceID] {
                item.configure(with: typefaceItem)
            }
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

            let familyID = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            let isCollapsed = self.collapsedFamilyIDs.contains(familyID)
            let section = self.snapshot.familyByID[familyID]
            let displayName = section?.displayName ?? ""
            let totalCount = section?.typefaceCount ?? 0
            let typefaceIDs = section?.typefaces.map { $0.id } ?? []
            let selectionState = FontFamilySelectionState.resolve(
                typefaceIDs: typefaceIDs,
                selected: self.currentSelectedTypefaceIDs
            )
            headerView.configure(
                familyName: displayName,
                count: totalCount,
                isCollapsed: isCollapsed,
                selectionState: selectionState,
                onToggle: { [weak self] in
                    self?.onSectionToggled?(familyID)
                },
                onSelect: { [weak self] intent in
                    self?.onFamilySelectionIntent?(familyID, intent)
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
        let effectiveWidth = environment.container.effectiveContentSize.width
        invalidateLayoutIfEffectiveWidthChanged(effectiveWidth)

        let contentWidth = max(
            effectiveWidth - (LayoutMetrics.horizontalEdgeInset * 2),
            LayoutMetrics.minimumItemWidth
        )
        let columnCount = resolvedColumnCount(for: contentWidth)
        // Only the final section gets extra bottom space so the last visible row
        // sits above the scroll view's adjusted bottom edge. Earlier sections
        // keep a zero bottom inset to avoid introducing gaps between families.
        let bottomInset = sectionIndex == snapshot.families.indices.last
            ? LayoutMetrics.lastSectionBottomInset
            : LayoutMetrics.sectionBottomInset
        return Self.makeSection(
            contentWidth: contentWidth,
            columnCount: columnCount,
            bottomInset: bottomInset
        )
    }

    /// Detects when `effectiveContentSize.width` differs from the previous
    /// pass and queues a single deferred `invalidateLayout` so the next pass
    /// recomputes item widths against the post-scroller-toggle width.
    ///
    /// The legacy vertical scroller can appear or disappear partway through a
    /// data source apply when the new content height crosses the viewport
    /// boundary. Without this re-invalidation the sections built during the
    /// current pass keep the pre-toggle item width and render at the wrong
    /// size until something else (window resize, split view drag) triggers
    /// another layout pass.
    ///
    /// On systems using overlay scrollers (or when the content fits without
    /// toggling) `effectiveContentSize.width` does not change, so this check
    /// is a no-op.
    private func invalidateLayoutIfEffectiveWidthChanged(_ effectiveWidth: CGFloat) {
        defer { effectiveWidthTracker.record(effectiveWidth) }

        guard effectiveWidthTracker.shouldScheduleInvalidation(for: effectiveWidth) else { return }

        effectiveWidthTracker.hasPendingInvalidation = true
        // Reset the cached column count so `resolvedColumnCount` recomputes
        // from scratch on the next pass; otherwise it would prefer the column
        // count chosen against the stale width.
        currentColumnCount = 0

        RunLoop.main.perform { [weak self] in
            guard let self = self else { return }
            // Clear the flag before invoking `invalidateLayout` so that if
            // the resulting pass observes yet another width change it can
            // schedule a follow-up invalidation.
            self.effectiveWidthTracker.hasPendingInvalidation = false
            self.collectionView.collectionViewLayout?.invalidateLayout()
        }
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

    private func restoreSelection(with typefaceIDs: Set<FontTypefaceID>) {
        let indexPaths = Set(typefaceIDs.compactMap { id in
            dataSource.indexPath(for: id)
        })
        collectionView.deselectAll(nil)
        if !indexPaths.isEmpty {
            collectionView.selectItems(at: indexPaths, scrollPosition: [])
        }
    }

    private func focusPrimaryViewIfPossible() {
        view.window?.makeFirstResponder(collectionView)
    }

    /// Invoked by `FontGridCollectionView` when a `mouseDown` reaches the
    /// collection view itself, meaning the click missed every item and every
    /// supplementary view. Notifies the parent to clear the entire selection.
    ///
    /// The parent owns the authoritative selection (family-header clicks can
    /// add typefaces that are not represented in `selectionIndexPaths`), so
    /// it is not sufficient to inspect the local collection view's selection
    /// here. Always notify with an empty visible selection and
    /// `preservesHiddenSelection: false` so the parent collapses to nothing.
    private func handleBackgroundClick() {
        guard !isApplyingReload else { return }
        collectionView.deselectAll(nil)
        onSelectionChanged?([], false)
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
        // Disabling the pinToVisibleBounds,
        // when this is enabled, the header view will be flickering while live-scrolling.
        // header.pinToVisibleBounds = true
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
        let selectedTypefaces = collectionView.selectionIndexPaths.compactMap { indexPath -> FontTypefaceItem? in
            guard let typefaceID = dataSource.itemIdentifier(for: indexPath) else { return nil }
            return snapshot.typefaceByID[typefaceID]
        }
        onSelectionChanged?(selectedTypefaces, preservesHiddenSelectionForCurrentEvent())
    }

    private func preservesHiddenSelectionForCurrentEvent() -> Bool {
        let modifierFlags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        return modifierFlags.contains(.command) || modifierFlags.contains(.shift)
    }
}

// MARK: - FontGridCollectionView

/// `NSCollectionView` subclass that reports clicks landing on its background.
///
/// `NSCollectionViewItem.view` and supplementary views consume their own
/// `mouseDown(with:)` and are descendants of the collection view, so a click
/// whose hit-test resolves back to the collection view itself is, by
/// definition, on empty space between cells.
final class FontGridCollectionView: NSCollectionView {

    var onBackgroundClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        if let superview, hitTest(superview.convert(event.locationInWindow, from: nil)) === self {
            onBackgroundClick?()
        }
    }
}
