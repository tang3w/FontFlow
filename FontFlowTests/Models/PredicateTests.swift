//
//  PredicateTests.swift
//  FontFlowTests
//
//  Created on 2026/3/21.
//

import Testing
import CoreData
@testable import FontFlow

@MainActor
struct PredicateTests {

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "FontFlow")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let error = loadError { throw error }
        return container.viewContext
    }

    @discardableResult
    private func makeFont(
        context: NSManagedObjectContext,
        displayName: String,
        familyName: String = "TestFamily",
        postScriptName: String? = nil,
        isFavorite: Bool = false,
        importedDate: Date = Date()
    ) -> FontRecord {
        let record = FontRecord(context: context)
        record.id = UUID()
        record.displayName = displayName
        record.familyName = familyName
        record.postScriptName = postScriptName ?? displayName.replacingOccurrences(of: " ", with: "-")
        record.styleName = "Regular"
        record.filePath = "/tmp/\(displayName).ttf"
        record.fileSize = 1024
        record.isFavorite = isFavorite
        record.importedDate = importedDate
        record.isValid = true
        return record
    }

    private func fetchFonts(
        context: NSManagedObjectContext,
        predicate: NSPredicate?
    ) throws -> [FontRecord] {
        let request = FontRecord.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
        return try context.fetch(request)
    }

    // MARK: - All Fonts (nil predicate)

    @Test func allFontsPredicateReturnsEverything() throws {
        let ctx = try makeInMemoryContext()
        makeFont(context: ctx, displayName: "Alpha")
        makeFont(context: ctx, displayName: "Beta")
        makeFont(context: ctx, displayName: "Gamma")
        try ctx.save()

        let results = try fetchFonts(context: ctx, predicate: nil)
        #expect(results.count == 3)
    }

    // MARK: - Favorites

    @Test func favoritesPredicateFiltersCorrectly() throws {
        let ctx = try makeInMemoryContext()
        makeFont(context: ctx, displayName: "Fav1", isFavorite: true)
        makeFont(context: ctx, displayName: "Fav2", isFavorite: true)
        makeFont(context: ctx, displayName: "NotFav", isFavorite: false)
        try ctx.save()

        let predicate = NSPredicate(format: "isFavorite == YES")
        let results = try fetchFonts(context: ctx, predicate: predicate)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.isFavorite })
    }

    // MARK: - Recently Added

    @Test func recentlyAddedPredicateFiltersCorrectly() throws {
        let ctx = try makeInMemoryContext()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        makeFont(context: ctx, displayName: "Recent", importedDate: threeDaysAgo)
        makeFont(context: ctx, displayName: "Old", importedDate: tenDaysAgo)
        try ctx.save()

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let predicate = NSPredicate(format: "importedDate >= %@", sevenDaysAgo as NSDate)
        let results = try fetchFonts(context: ctx, predicate: predicate)
        #expect(results.count == 1)
        #expect(results.first?.displayName == "Recent")
    }

    // MARK: - Collection

    @Test func collectionPredicateFiltersCorrectly() throws {
        let ctx = try makeInMemoryContext()
        let collection = FontCollection(context: ctx)
        collection.id = UUID()
        collection.name = "My Collection"
        collection.createdDate = Date()

        let inCollection = makeFont(context: ctx, displayName: "InCollection")
        inCollection.addToCollections(collection)
        makeFont(context: ctx, displayName: "NotInCollection")
        try ctx.save()

        let predicate = NSPredicate(format: "ANY collections == %@", collection)
        let results = try fetchFonts(context: ctx, predicate: predicate)
        #expect(results.count == 1)
        #expect(results.first?.displayName == "InCollection")
    }

    // MARK: - Tag

    @Test func tagPredicateFiltersCorrectly() throws {
        let ctx = try makeInMemoryContext()
        let tag = Tag(context: ctx)
        tag.id = UUID()
        tag.name = "Serif"

        let tagged = makeFont(context: ctx, displayName: "Tagged")
        tagged.addToTags(tag)
        makeFont(context: ctx, displayName: "Untagged")
        try ctx.save()

        let predicate = NSPredicate(format: "ANY tags == %@", tag)
        let results = try fetchFonts(context: ctx, predicate: predicate)
        #expect(results.count == 1)
        #expect(results.first?.displayName == "Tagged")
    }

    // MARK: - Project Set

    @Test func projectSetPredicateFiltersCorrectly() throws {
        let ctx = try makeInMemoryContext()
        let projectSet = ProjectSet(context: ctx)
        projectSet.id = UUID()
        projectSet.name = "Client Project"
        projectSet.createdDate = Date()

        let inProject = makeFont(context: ctx, displayName: "InProject")
        inProject.addToProjectSets(projectSet)
        makeFont(context: ctx, displayName: "NotInProject")
        try ctx.save()

        let predicate = NSPredicate(format: "ANY projectSets == %@", projectSet)
        let results = try fetchFonts(context: ctx, predicate: predicate)
        #expect(results.count == 1)
        #expect(results.first?.displayName == "InProject")
    }

    // MARK: - Search Predicate

    @Test func searchPredicateMatchesDisplayName() throws {
        let ctx = try makeInMemoryContext()
        makeFont(context: ctx, displayName: "Helvetica Bold", familyName: "Helvetica")
        makeFont(context: ctx, displayName: "Arial Regular", familyName: "Arial")
        try ctx.save()

        let searchText = "helv"
        let predicate = NSPredicate(
            format: "displayName CONTAINS[cd] %@ OR familyName CONTAINS[cd] %@ OR postScriptName CONTAINS[cd] %@",
            searchText, searchText, searchText
        )
        let results = try fetchFonts(context: ctx, predicate: predicate)
        #expect(results.count == 1)
        #expect(results.first?.displayName == "Helvetica Bold")
    }

    // MARK: - Compound Predicate (sidebar + search)

    @Test func compoundPredicateNarrowsResults() throws {
        let ctx = try makeInMemoryContext()
        makeFont(context: ctx, displayName: "Helvetica Bold", familyName: "Helvetica", isFavorite: true)
        makeFont(context: ctx, displayName: "Helvetica Light", familyName: "Helvetica", isFavorite: false)
        makeFont(context: ctx, displayName: "Arial Bold", familyName: "Arial", isFavorite: true)
        try ctx.save()

        let sidebarPredicate = NSPredicate(format: "isFavorite == YES")
        let searchPredicate = NSPredicate(
            format: "displayName CONTAINS[cd] %@ OR familyName CONTAINS[cd] %@ OR postScriptName CONTAINS[cd] %@",
            "helv", "helv", "helv"
        )
        let combined = NSCompoundPredicate(andPredicateWithSubpredicates: [sidebarPredicate, searchPredicate])
        let results = try fetchFonts(context: ctx, predicate: combined)
        #expect(results.count == 1)
        #expect(results.first?.displayName == "Helvetica Bold")
    }
}
