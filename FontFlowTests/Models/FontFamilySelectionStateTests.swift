//
//  FontFamilySelectionStateTests.swift
//  FontFlowTests
//
//  Created on 2026/4/19.
//

import Testing
import CoreData
@testable import FontFlow

@MainActor
struct FontFamilySelectionStateTests {

    @Test func resolveReturnsNoneForEmptyFamily() throws {
        #expect(FontFamilySelectionState.resolve(typefaceIDs: [], selected: []) == .none)
    }

    @Test func resolveReturnsNoneWhenNothingSelected() throws {
        let ids = try makeTypefaceIDs(count: 3)
        #expect(FontFamilySelectionState.resolve(typefaceIDs: ids, selected: []) == .none)
    }

    @Test func resolveReturnsFullWhenAllSelected() throws {
        let ids = try makeTypefaceIDs(count: 3)
        #expect(FontFamilySelectionState.resolve(typefaceIDs: ids, selected: Set(ids)) == .full)
    }

    @Test func resolveReturnsPartialWhenSomeSelected() throws {
        let ids = try makeTypefaceIDs(count: 3)
        #expect(FontFamilySelectionState.resolve(typefaceIDs: ids, selected: [ids[0]]) == .partial)
    }

    @Test func resolveIgnoresSelectedIDsOutsideFamily() throws {
        let ids = try makeTypefaceIDs(count: 4)
        let family = Array(ids.prefix(2))
        let outsider = ids[3]
        #expect(FontFamilySelectionState.resolve(typefaceIDs: family, selected: [outsider]) == .none)
    }

    private func makeTypefaceIDs(count: Int) throws -> [FontTypefaceID] {
        let context = try makeInMemoryContext()
        let records = (0..<count).map { index in
            let record = FontRecord(context: context)
            record.id = UUID()
            record.postScriptName = "Font-\(index)"
            record.displayName = "Font \(index)"
            record.familyName = "Family"
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
