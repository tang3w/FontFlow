//
//  CoreDataModelTests.swift
//  FontFlowTests
//
//  Created on 2026/3/20.
//

import Testing
import CoreData
import CoreText
@testable import FontFlow

@MainActor
struct CoreDataModelTests {

    // MARK: - Helpers

    /// Creates an in-memory Core Data stack for testing.
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

    // MARK: - FontRecord

    @Test func createFontRecord() throws {
        let ctx = try makeInMemoryContext()

        let record = FontRecord(context: ctx)
        record.id = UUID()
        record.postScriptName = "Helvetica-Bold"
        record.displayName = "Helvetica Bold"
        record.familyName = "Helvetica"
        record.styleName = "Bold"
        record.filePath = "/System/Library/Fonts/Helvetica.ttc"
        record.fileSize = 1024
        record.isActivated = false
        record.isFavorite = true
        record.importedDate = Date()
        record.isValid = true

        try ctx.save()

        let fetch = FontRecord.fetchRequest()
        let results = try ctx.fetch(fetch)
        #expect(results.count == 1)

        let fetched = try #require(results.first)
        #expect(fetched.postScriptName == "Helvetica-Bold")
        #expect(fetched.familyName == "Helvetica")
        #expect(fetched.isFavorite == true)
        #expect(fetched.isActivated == false)
        #expect(fetched.isValid == true)
        #expect(fetched.fileSize == 1024)
    }

    @Test func fontRecordDefaultValues() throws {
        let ctx = try makeInMemoryContext()

        let record = FontRecord(context: ctx)
        // Only set required non-defaulted attributes
        record.id = UUID()
        record.postScriptName = "Test"
        record.displayName = "Test"
        record.familyName = "Test"
        record.styleName = "Regular"
        record.filePath = "/test"
        record.importedDate = Date()

        #expect(record.isActivated == false)
        #expect(record.isFavorite == false)
        #expect(record.isValid == true)
        #expect(record.fileSize == 0)
        #expect(record.duplicateGroupID == nil)
        #expect(record.lastUsedDate == nil)
        #expect(record.bookmarkData == nil)
        #expect(record.traitWeight == nil)
        #expect(record.traitWidth == nil)
        #expect(record.traitSlant == nil)
        #expect(record.traitSymbolicTraitsRaw == 0)
    }

    @Test func fontRecordAppliesAndReadsTraits() throws {
        let ctx = try makeInMemoryContext()

        let record = FontRecord(context: ctx)
        record.id = UUID()
        record.postScriptName = "Helvetica-Oblique"
        record.displayName = "Helvetica Oblique"
        record.familyName = "Helvetica"
        record.styleName = "Oblique"
        record.filePath = "/System/Library/Fonts/Helvetica.ttc"
        record.importedDate = Date()

        let traits = FontTraits(
            weight: 0,
            width: 0,
            slant: 0.06666666666666667,
            symbolicTraits: [.traitItalic]
        )
        record.applyFontTraits(traits)

        #expect(record.traitWeight?.doubleValue == 0)
        #expect(record.traitWidth?.doubleValue == 0)
        #expect(record.traitSlant?.doubleValue == traits.slant)
        #expect(record.traitSymbolicTraitsRaw == Int64(CTFontSymbolicTraits.traitItalic.rawValue))

        let storedTraits = record.fontTraits
        #expect(storedTraits.isItalicLike)
        #expect(storedTraits.effectiveSlant == traits.slant)
        #expect(storedTraits.widthBucket == .normal)
    }

    // MARK: - FontFamily & Relationship

    @Test func fontFamilyToFontRecordRelationship() throws {
        let ctx = try makeInMemoryContext()

        let family = FontFamily(context: ctx)
        family.id = UUID()
        family.name = "Helvetica"

        let regular = FontRecord(context: ctx)
        regular.id = UUID()
        regular.postScriptName = "Helvetica"
        regular.displayName = "Helvetica"
        regular.familyName = "Helvetica"
        regular.styleName = "Regular"
        regular.filePath = "/fonts/Helvetica.ttf"
        regular.importedDate = Date()
        regular.family = family

        let bold = FontRecord(context: ctx)
        bold.id = UUID()
        bold.postScriptName = "Helvetica-Bold"
        bold.displayName = "Helvetica Bold"
        bold.familyName = "Helvetica"
        bold.styleName = "Bold"
        bold.filePath = "/fonts/Helvetica-Bold.ttf"
        bold.importedDate = Date()
        bold.family = family

        try ctx.save()

        #expect(family.fonts?.count == 2)
        #expect(regular.family == family)
        #expect(bold.family == family)
    }

    @Test func deleteFontFamilyCascadesToFontRecords() throws {
        let ctx = try makeInMemoryContext()

        let family = FontFamily(context: ctx)
        family.id = UUID()
        family.name = "TestFamily"

        let record = FontRecord(context: ctx)
        record.id = UUID()
        record.postScriptName = "TestFont"
        record.displayName = "Test Font"
        record.familyName = "TestFamily"
        record.styleName = "Regular"
        record.filePath = "/test"
        record.importedDate = Date()
        record.family = family

        try ctx.save()

        // Delete the family — should cascade to records
        ctx.delete(family)
        try ctx.save()

        let fetch = FontRecord.fetchRequest()
        let results = try ctx.fetch(fetch)
        #expect(results.isEmpty, "FontRecord should be deleted when its FontFamily is deleted (cascade)")
    }

    // MARK: - Tag (Many-to-Many)

    @Test func tagManyToManyWithFontRecord() throws {
        let ctx = try makeInMemoryContext()

        let tag = FontFlow.Tag(context: ctx)
        tag.id = UUID()
        tag.name = "Serif"
        tag.color = "#FF0000"

        let font1 = makeFontRecord(ctx, psName: "TimesNewRoman", family: "Times")
        let font2 = makeFontRecord(ctx, psName: "Georgia", family: "Georgia")

        font1.addToTags(tag)
        font2.addToTags(tag)

        try ctx.save()

        #expect(tag.fonts?.count == 2)
        #expect((font1.tags as? Set<FontFlow.Tag>)?.contains(tag) == true)
        #expect((font2.tags as? Set<FontFlow.Tag>)?.contains(tag) == true)
    }

    @Test func removingTagDoesNotDeleteFont() throws {
        let ctx = try makeInMemoryContext()

        let tag = FontFlow.Tag(context: ctx)
        tag.id = UUID()
        tag.name = "Display"

        let font = makeFontRecord(ctx, psName: "Impact", family: "Impact")
        font.addToTags(tag)
        try ctx.save()

        ctx.delete(tag)
        try ctx.save()

        let fetch = FontRecord.fetchRequest()
        let results = try ctx.fetch(fetch)
        #expect(results.count == 1, "FontRecord should survive tag deletion")
    }

    // MARK: - FontCollection (Many-to-Many)

    @Test func fontCollectionManyToMany() throws {
        let ctx = try makeInMemoryContext()

        let collection = FontCollection(context: ctx)
        collection.id = UUID()
        collection.name = "My Favorites"
        collection.createdDate = Date()
        collection.sortOrder = 0

        let font1 = makeFontRecord(ctx, psName: "Arial", family: "Arial")
        let font2 = makeFontRecord(ctx, psName: "Verdana", family: "Verdana")

        collection.addToFonts(font1)
        collection.addToFonts(font2)

        try ctx.save()

        #expect(collection.fonts?.count == 2)
        #expect((font1.collections as? Set<FontCollection>)?.contains(collection) == true)
    }

    @Test func fontCanBelongToMultipleCollections() throws {
        let ctx = try makeInMemoryContext()

        let col1 = FontCollection(context: ctx)
        col1.id = UUID()
        col1.name = "Web Fonts"
        col1.createdDate = Date()

        let col2 = FontCollection(context: ctx)
        col2.id = UUID()
        col2.name = "Print Fonts"
        col2.createdDate = Date()

        let font = makeFontRecord(ctx, psName: "Arial", family: "Arial")
        font.addToCollections(col1)
        font.addToCollections(col2)

        try ctx.save()

        #expect(font.collections?.count == 2)
    }

    // MARK: - ProjectSet

    @Test func createProjectSet() throws {
        let ctx = try makeInMemoryContext()

        let project = ProjectSet(context: ctx)
        project.id = UUID()
        project.name = "Client Website"
        project.clientName = "Acme Corp"
        project.createdDate = Date()
        project.sortOrder = 1

        let font = makeFontRecord(ctx, psName: "Roboto", family: "Roboto")
        project.addToFonts(font)

        try ctx.save()

        let fetch = ProjectSet.fetchRequest()
        let results = try ctx.fetch(fetch)
        #expect(results.count == 1)

        let fetched = try #require(results.first)
        #expect(fetched.name == "Client Website")
        #expect(fetched.clientName == "Acme Corp")
        #expect(fetched.fonts?.count == 1)
        #expect(fetched.lastActivatedDate == nil)
    }

    @Test func projectSetManyToManyWithFontRecord() throws {
        let ctx = try makeInMemoryContext()

        let project = ProjectSet(context: ctx)
        project.id = UUID()
        project.name = "Branding"
        project.createdDate = Date()

        let font1 = makeFontRecord(ctx, psName: "Futura", family: "Futura")
        let font2 = makeFontRecord(ctx, psName: "Garamond", family: "Garamond")

        project.addToFonts(font1)
        project.addToFonts(font2)

        try ctx.save()

        #expect(project.fonts?.count == 2)
        #expect((font1.projectSets as? Set<ProjectSet>)?.contains(project) == true)
    }

    // MARK: - Cross-Entity Relationships

    @Test func fontRecordWithAllRelationships() throws {
        let ctx = try makeInMemoryContext()

        let family = FontFamily(context: ctx)
        family.id = UUID()
        family.name = "TestFamily"

        let tag = FontFlow.Tag(context: ctx)
        tag.id = UUID()
        tag.name = "Sans-Serif"

        let collection = FontCollection(context: ctx)
        collection.id = UUID()
        collection.name = "Web"
        collection.createdDate = Date()

        let project = ProjectSet(context: ctx)
        project.id = UUID()
        project.name = "Website"
        project.createdDate = Date()

        let font = makeFontRecord(ctx, psName: "TestFont", family: "TestFamily")
        font.family = family
        font.addToTags(tag)
        font.addToCollections(collection)
        font.addToProjectSets(project)

        try ctx.save()

        #expect(font.family == family)
        #expect(font.tags?.count == 1)
        #expect(font.collections?.count == 1)
        #expect(font.projectSets?.count == 1)
    }

    // MARK: - Fetch with Predicates

    @Test func fetchFavorites() throws {
        let ctx = try makeInMemoryContext()

        let fav = makeFontRecord(ctx, psName: "FavFont", family: "FavFamily")
        fav.isFavorite = true

        let notFav = makeFontRecord(ctx, psName: "RegFont", family: "RegFamily")
        notFav.isFavorite = false

        try ctx.save()

        let fetch = FontRecord.fetchRequest()
        fetch.predicate = NSPredicate(format: "isFavorite == YES")
        let results = try ctx.fetch(fetch)
        #expect(results.count == 1)
        #expect(results.first?.postScriptName == "FavFont")
    }

    @Test func fetchActivated() throws {
        let ctx = try makeInMemoryContext()

        let active = makeFontRecord(ctx, psName: "Active", family: "ActiveFamily")
        active.isActivated = true

        let _ = makeFontRecord(ctx, psName: "Inactive", family: "InactiveFamily")

        try ctx.save()

        let fetch = FontRecord.fetchRequest()
        fetch.predicate = NSPredicate(format: "isActivated == YES")
        let results = try ctx.fetch(fetch)
        #expect(results.count == 1)
        #expect(results.first?.postScriptName == "Active")
    }

    @Test func fetchByFamilyName() throws {
        let ctx = try makeInMemoryContext()

        let _ = makeFontRecord(ctx, psName: "Helvetica", family: "Helvetica")
        let _ = makeFontRecord(ctx, psName: "Helvetica-Bold", family: "Helvetica")
        let _ = makeFontRecord(ctx, psName: "Arial", family: "Arial")

        try ctx.save()

        let fetch = FontRecord.fetchRequest()
        fetch.predicate = NSPredicate(format: "familyName == %@", "Helvetica")
        let results = try ctx.fetch(fetch)
        #expect(results.count == 2)
    }

    @Test func fetchDuplicates() throws {
        let ctx = try makeInMemoryContext()

        let groupID = UUID()
        let dup1 = makeFontRecord(ctx, psName: "Dup1", family: "DupFamily")
        dup1.duplicateGroupID = groupID

        let dup2 = makeFontRecord(ctx, psName: "Dup2", family: "DupFamily")
        dup2.duplicateGroupID = groupID

        let _ = makeFontRecord(ctx, psName: "Unique", family: "UniqueFamily")

        try ctx.save()

        let fetch = FontRecord.fetchRequest()
        fetch.predicate = NSPredicate(format: "duplicateGroupID != nil")
        let results = try ctx.fetch(fetch)
        #expect(results.count == 2)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeFontRecord(_ ctx: NSManagedObjectContext, psName: String, family: String) -> FontRecord {
        let record = FontRecord(context: ctx)
        record.id = UUID()
        record.postScriptName = psName
        record.displayName = psName
        record.familyName = family
        record.styleName = "Regular"
        record.filePath = "/fonts/\(psName).ttf"
        record.importedDate = Date()
        return record
    }
}
