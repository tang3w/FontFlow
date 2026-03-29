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
        let objectIDs = try makeObjectIDs(count: 4)

        let updatedSelection = FontBrowserSelectionState.updatedSelection(
            existingObjectIDs: Set([objectIDs[0], objectIDs[1], objectIDs[2]]),
            visibleObjectIDs: Set([objectIDs[1], objectIDs[2], objectIDs[3]]),
            selectedVisibleObjectIDs: Set([objectIDs[1], objectIDs[2], objectIDs[3]]),
            preservesHiddenSelection: true
        )

        #expect(updatedSelection == Set(objectIDs))
    }

    @Test func replacesSelectionWhenUserDoesNotExtendSelection() throws {
        let objectIDs = try makeObjectIDs(count: 4)

        let updatedSelection = FontBrowserSelectionState.updatedSelection(
            existingObjectIDs: Set([objectIDs[0], objectIDs[1], objectIDs[2]]),
            visibleObjectIDs: Set([objectIDs[1], objectIDs[2], objectIDs[3]]),
            selectedVisibleObjectIDs: Set([objectIDs[3]]),
            preservesHiddenSelection: false
        )

        #expect(updatedSelection == Set([objectIDs[3]]))
    }

    @Test func keepsHiddenSelectionWhenVisibleItemsAreCommandDeselected() throws {
        let objectIDs = try makeObjectIDs(count: 3)

        let updatedSelection = FontBrowserSelectionState.updatedSelection(
            existingObjectIDs: Set(objectIDs),
            visibleObjectIDs: Set([objectIDs[1], objectIDs[2]]),
            selectedVisibleObjectIDs: [],
            preservesHiddenSelection: true
        )

        #expect(updatedSelection == Set([objectIDs[0]]))
    }

    private func makeObjectIDs(count: Int) throws -> [NSManagedObjectID] {
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
        return records.map { $0.objectID }
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
