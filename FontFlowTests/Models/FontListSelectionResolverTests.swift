//
//  FontListSelectionResolverTests.swift
//  FontFlowTests
//
//  Created on 2026/4/24.
//

import AppKit
import CoreData
import Testing
@testable import FontFlow

@MainActor
struct FontListSelectionResolverTests {

    /// Regression for the single-typeface family Cmd+click bug.
    ///
    /// Sequence:
    ///   1. Plain click on the section row of a family with exactly one
    ///      typeface. AppKit proposes `{sectionRow}`; the resolver expands
    ///      to `{sectionRow, typefaceRow}`.
    ///   2. The selection commits (in the controller this happens in
    ///      `outlineViewSelectionDidChange`), and the resolver's per-gesture
    ///      cache is invalidated via `resetCache()`.
    ///   3. Cmd+click on the lone typeface row. AppKit again proposes
    ///      `{sectionRow}` (it strips the typeface row). The resolver must
    ///      treat this as a hole-punch and return an empty selection — not
    ///      short-circuit to the previously resolved `{sectionRow,
    ///      typefaceRow}`.
    @Test func cmdClickDeselectsLoneTypefaceAfterFamilyClick() throws {
        let harness = try ResolverHarness.makeWithSingleTypefaceFamily()
        let resolver = harness.resolver
        let outlineView = harness.outlineView

        let sectionRow = outlineView.row(forItem: harness.section)
        let typefaceRow = outlineView.row(forItem: harness.typeface)
        #expect(sectionRow >= 0)
        #expect(typefaceRow >= 0)

        // Step 1: plain click on the section row.
        let firstProposed = IndexSet(integer: sectionRow)
        let firstResolved = resolver.resolve(
            proposed: firstProposed,
            isDragGesture: false,
            hasCommandModifier: false
        )
        #expect(firstResolved == IndexSet([sectionRow, typefaceRow]))

        // Step 2: simulate AppKit applying the resolution and committing the
        // gesture. The controller does this from
        // `outlineViewSelectionDidChange`.
        outlineView.selectRowIndexes(firstResolved, byExtendingSelection: false)
        resolver.resetCache()

        // Step 3: Cmd+click on the lone typeface row. AppKit drops the
        // typeface row from `selectedRowIndexes` ({0,1} -> {0}) and proposes
        // that. With the cache properly invalidated and the Command
        // modifier signal forwarded, the resolver must run the hole-punch
        // path and return an empty IndexSet.
        let secondProposed = IndexSet(integer: sectionRow)
        let secondResolved = resolver.resolve(
            proposed: secondProposed,
            isDragGesture: false,
            hasCommandModifier: true
        )
        #expect(secondResolved.isEmpty)
    }

    /// Locks in the cache's documented in-gesture role: identical proposals
    /// during a single uncommitted gesture must return the same resolution
    /// (so noisy mid-drag re-emissions don't flip the section row off).
    @Test func identicalProposalsWithinGestureAreIdempotent() throws {
        let harness = try ResolverHarness.makeWithSingleTypefaceFamily()
        let resolver = harness.resolver
        let outlineView = harness.outlineView

        let sectionRow = outlineView.row(forItem: harness.section)
        let typefaceRow = outlineView.row(forItem: harness.typeface)

        let proposed = IndexSet(integer: sectionRow)
        let first = resolver.resolve(
            proposed: proposed,
            isDragGesture: false,
            hasCommandModifier: false
        )
        let second = resolver.resolve(
            proposed: proposed,
            isDragGesture: false,
            hasCommandModifier: false
        )
        #expect(first == IndexSet([sectionRow, typefaceRow]))
        #expect(second == first)
    }

    /// Regression for the secondary bug uncovered by the cache-reset fix:
    /// after a single-typeface family is fully selected, a plain re-click
    /// on the section row must keep the family selected. AppKit's
    /// replace-selection semantics drop the typeface row from `proposed`,
    /// producing the exact same shrinkage signature as a Cmd+click on the
    /// typeface row. Only the Command modifier signal disambiguates the
    /// two; without it the hole-punch path would incorrectly fire and
    /// deselect the family.
    @Test func plainReclickOnSelectedSingleTypefaceFamilyKeepsSelection() throws {
        let harness = try ResolverHarness.makeWithSingleTypefaceFamily()
        let resolver = harness.resolver
        let outlineView = harness.outlineView

        let sectionRow = outlineView.row(forItem: harness.section)
        let typefaceRow = outlineView.row(forItem: harness.typeface)

        // First plain click selects the family.
        let firstProposed = IndexSet(integer: sectionRow)
        let firstResolved = resolver.resolve(
            proposed: firstProposed,
            isDragGesture: false,
            hasCommandModifier: false
        )
        #expect(firstResolved == IndexSet([sectionRow, typefaceRow]))

        outlineView.selectRowIndexes(firstResolved, byExtendingSelection: false)
        resolver.resetCache()

        // Plain re-click on the same section row. Without Command, the
        // resolver must keep the family selected even though the proposal
        // signature is identical to the Cmd+click hole-punch case.
        let secondProposed = IndexSet(integer: sectionRow)
        let secondResolved = resolver.resolve(
            proposed: secondProposed,
            isDragGesture: false,
            hasCommandModifier: false
        )
        #expect(secondResolved == IndexSet([sectionRow, typefaceRow]))
    }
}

// MARK: - Harness

@MainActor
private final class ResolverHarness: NSObject, NSOutlineViewDataSource {

    let outlineView: NSOutlineView
    let resolver: FontListSelectionResolver
    let section: FontFamilySection
    let typeface: FontTypefaceItem

    private init(section: FontFamilySection, typeface: FontTypefaceItem) {
        self.outlineView = NSOutlineView()
        self.section = section
        self.typeface = typeface
        let snapshot = FontBrowserSnapshot(
            families: [section],
            familyByID: [section.id: section],
            typefaceByID: [typeface.id: typeface]
        )
        self.resolver = FontListSelectionResolver(outlineView: outlineView, snapshot: snapshot)
        super.init()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.allowsMultipleSelection = true
        outlineView.allowsEmptySelection = true
        outlineView.dataSource = self
        outlineView.reloadData()
        outlineView.expandItem(section)
    }

    static func makeWithSingleTypefaceFamily() throws -> ResolverHarness {
        let context = try makeInMemoryContext()
        let family = FontFamily(context: context)
        family.id = UUID()
        family.name = "Solo Family"

        let record = FontRecord(context: context)
        record.id = UUID()
        record.postScriptName = "SoloFont-Regular"
        record.displayName = "Solo Font"
        record.familyName = "Solo Family"
        record.styleName = "Regular"
        record.filePath = "/tmp/solo.ttf"
        record.importedDate = Date()
        record.family = family

        try context.obtainPermanentIDs(for: [family, record])

        let familyID = FontFamilyID(objectID: family.objectID)
        let typeface = FontTypefaceItem(
            id: FontTypefaceID(objectID: record.objectID),
            familyID: familyID,
            displayLabel: "Regular",
            record: record
        )
        let section = FontFamilySection(
            id: familyID,
            displayName: "Solo Family",
            typefaces: [typeface]
        )

        return ResolverHarness(section: section, typeface: typeface)
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        switch item {
        case nil: return 1
        case let s as FontFamilySection: return s.typefaces.count
        default: return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        switch item {
        case nil: return section
        case let s as FontFamilySection: return s.typefaces[index]
        default: fatalError()
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is FontFamilySection
    }
}

@MainActor
private func makeInMemoryContext() throws -> NSManagedObjectContext {
    let container = NSPersistentContainer(name: "FontFlow")
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]

    var loadError: Error?
    container.loadPersistentStores { _, error in
        loadError = error
    }
    if let loadError {
        throw loadError
    }
    return container.viewContext
}
