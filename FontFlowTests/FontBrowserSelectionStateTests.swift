//
//  FontBrowserSelectionStateTests.swift
//  FontFlowTests
//
//  Created on 2026/3/30.
//

import Testing
import CoreData
@testable import FontFlow

@MainActor
struct FontBrowserSelectionStateTests {

    @Test func preservesHiddenSelectionWhenVisibleSelectionExtends() throws {
        let typefaceIDs = try makeTypefaceIDs(count: 4)

        let updatedSelection = FontBrowserSelectionState.updatedSelection(
            existingTypefaceIDs: Set([typefaceIDs[0], typefaceIDs[1], typefaceIDs[2]]),
            visibleTypefaceIDs: Set([typefaceIDs[1], typefaceIDs[2], typefaceIDs[3]]),
            selectedVisibleTypefaceIDs: Set([typefaceIDs[1], typefaceIDs[2], typefaceIDs[3]]),
            preservesHiddenSelection: true
        )

        #expect(updatedSelection == Set(typefaceIDs))
    }

    @Test func replacesSelectionWhenUserDoesNotExtendSelection() throws {
        let typefaceIDs = try makeTypefaceIDs(count: 4)

        let updatedSelection = FontBrowserSelectionState.updatedSelection(
            existingTypefaceIDs: Set([typefaceIDs[0], typefaceIDs[1], typefaceIDs[2]]),
            visibleTypefaceIDs: Set([typefaceIDs[1], typefaceIDs[2], typefaceIDs[3]]),
            selectedVisibleTypefaceIDs: Set([typefaceIDs[3]]),
            preservesHiddenSelection: false
        )

        #expect(updatedSelection == Set([typefaceIDs[3]]))
    }

    @Test func keepsHiddenSelectionWhenVisibleItemsAreCommandDeselected() throws {
        let typefaceIDs = try makeTypefaceIDs(count: 3)

        let updatedSelection = FontBrowserSelectionState.updatedSelection(
            existingTypefaceIDs: Set(typefaceIDs),
            visibleTypefaceIDs: Set([typefaceIDs[1], typefaceIDs[2]]),
            selectedVisibleTypefaceIDs: [],
            preservesHiddenSelection: true
        )

        #expect(updatedSelection == Set([typefaceIDs[0]]))
    }

    private func makeTypefaceIDs(count: Int) throws -> [FontTypefaceID] {
        let context = try makeInMemoryContext()
        let records = (0..<count).map { index in
            let record = FontRecord(context: context)
            record.id = UUID()
            record.postScriptName = "Font-\(index)"
            record.displayName = "Font \(index)"
            record.familyName = index == 0 ? "Hidden Family" : "Visible Family"
            record.styleName = "Style \(index)"
            record.filePath = "/tmp/font-\(index).ttf"
            record.importedDate = Date()
            return record
        }

        try context.obtainPermanentIDs(for: records)
        return records.map { FontTypefaceID(objectID: $0.objectID) }
    }

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
}
