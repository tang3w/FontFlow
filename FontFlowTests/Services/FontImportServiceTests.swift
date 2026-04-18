//
//  FontImportServiceTests.swift
//  FontFlowTests
//
//  Created on 2026/3/21.
//

import Testing
import CoreData
@testable import FontFlow

@MainActor
struct FontImportServiceTests {

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

    /// Returns the URL for a bundled test font file.
    private func bundledFontURL(_ filename: String) throws -> URL {
        let bundle = Bundle(for: TestBundleAnchor.self)
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw FontMetadataReader.ReadError.fileNotFound(URL(fileURLWithPath: filename))
        }
        return url
    }

    // MARK: - Basic Import

    @Test func importSingleFontFile() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        let result = FontImportService.importFonts(from: [url], context: ctx)

        #expect(result.totalCount == 1)
        #expect(result.importedCount == 1)
        #expect(result.duplicateCount == 0)
        #expect(result.failedCount == 0)

        let item = try #require(result.items.first)
        #expect(item.fileURL == url)
        #expect(item.postScriptName != nil)
        #expect(item.postScriptName!.isEmpty == false)

        guard case .imported(let record) = item.status else {
            Issue.record("Expected .imported status")
            return
        }

        #expect(record.postScriptName == item.postScriptName)
        #expect(record.familyName != nil)
        #expect(record.displayName != nil)
        #expect(record.fileSize > 0)
        #expect(record.fileHash != nil)
        #expect(record.fileHash!.isEmpty == false)
        #expect(record.importedDate != nil)
        #expect(record.isValid == true)
        #expect(record.isActivated == false)
    }

    @Test func importCreatesSecurityBookmark() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        let result = FontImportService.importFonts(from: [url], context: ctx)

        guard case .imported(let record) = result.items.first?.status else {
            Issue.record("Expected .imported status")
            return
        }

        #expect(record.bookmarkData != nil)
    }

    @Test func importPersistsExtractedFontTraits() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        let result = FontImportService.importFonts(from: [url], context: ctx)

        guard case .imported(let record) = result.items.first?.status else {
            Issue.record("Expected .imported status")
            return
        }

        #expect(record.traitWeight?.doubleValue == 0)
        #expect(record.traitWidth?.doubleValue == 0)
        #expect(record.traitSlant?.doubleValue == 0)
        #expect(record.traitSymbolicTraitsRaw != 0)
        #expect(record.fontTraits.widthBucket == .normal)
        #expect(!record.fontTraits.isItalicLike)
    }

    @Test func importCreatesFontFamily() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        let result = FontImportService.importFonts(from: [url], context: ctx)

        guard case .imported(let record) = result.items.first?.status else {
            Issue.record("Expected .imported status")
            return
        }

        #expect(record.family != nil)
        #expect(record.family?.name == record.familyName)

        // Verify FontFamily was persisted.
        let fetch = FontFamily.fetchRequest()
        let families = try ctx.fetch(fetch)
        #expect(families.count >= 1)
    }

    @Test func importMultipleFontFiles() throws {
        let ctx = try makeInMemoryContext()
        let url1 = try bundledFontURL("Cousine-Regular.ttf")
        let url2 = try bundledFontURL("Inter-Variable.ttf")

        let result = FontImportService.importFonts(from: [url1, url2], context: ctx)

        #expect(result.importedCount >= 2)
        #expect(result.failedCount == 0)

        // Verify records were persisted.
        let fetch = FontRecord.fetchRequest()
        let records = try ctx.fetch(fetch)
        #expect(records.count >= 2)
    }

    // MARK: - Duplicate Detection

    @Test func importDetectsExactDuplicate() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        // First import.
        let result1 = FontImportService.importFonts(from: [url], context: ctx)
        #expect(result1.importedCount == 1)

        // Second import of the same file.
        let result2 = FontImportService.importFonts(from: [url], context: ctx)
        #expect(result2.duplicateCount == 1)
        #expect(result2.importedCount == 0)

        guard case .duplicate(let existing) = result2.items.first?.status else {
            Issue.record("Expected .duplicate status on second import")
            return
        }

        #expect(existing.postScriptName == result1.items.first?.postScriptName)

        // Only one record should exist in the database.
        let fetch = FontRecord.fetchRequest()
        let records = try ctx.fetch(fetch)
        #expect(records.count == 1)
    }

    @Test func importSameFileTwiceInOneCall() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        // Import the same URL twice in a single call.
        let result = FontImportService.importFonts(from: [url, url], context: ctx)

        // First should be imported, second should be duplicate.
        #expect(result.importedCount == 1)
        #expect(result.duplicateCount == 1)
    }

    // MARK: - Font Family Reuse

    @Test func importReusesExistingFontFamily() throws {
        let ctx = try makeInMemoryContext()

        // Pre-create a FontFamily.
        let family = FontFamily(context: ctx)
        family.id = UUID()
        family.name = "Cousine"
        try ctx.save()

        let url = try bundledFontURL("Cousine-Regular.ttf")
        let result = FontImportService.importFonts(from: [url], context: ctx)

        guard case .imported(let record) = result.items.first?.status else {
            Issue.record("Expected .imported status")
            return
        }

        // Should reuse the existing family, not create a new one.
        #expect(record.family?.id == family.id)

        let fetch = FontFamily.fetchRequest()
        fetch.predicate = NSPredicate(format: "name == %@", "Cousine")
        let families = try ctx.fetch(fetch)
        #expect(families.count == 1)
    }

    // MARK: - Folder Import

    @Test func importFromFolder() throws {
        let ctx = try makeInMemoryContext()
        let bundle = Bundle(for: TestBundleAnchor.self)

        // Use the bundle's resource directory as a folder import target.
        guard let resourcesDir = bundle.resourceURL else {
            Issue.record("Could not find test bundle resources directory")
            return
        }

        let result = FontImportService.importFonts(from: [resourcesDir], context: ctx)

        // Should find at least the 2 bundled font files.
        #expect(result.importedCount >= 2)
        #expect(result.failedCount == 0)
    }

    // MARK: - Error Handling

    @Test func importSkipsNonFontFiles() throws {
        let ctx = try makeInMemoryContext()

        // Import a non-font file (the license file).
        let bundle = Bundle(for: TestBundleAnchor.self)
        guard let licenseURL = bundle.url(forResource: "Cousine-LICENSE", withExtension: "txt") else {
            Issue.record("Could not find license file")
            return
        }

        let result = FontImportService.importFonts(from: [licenseURL], context: ctx)

        // Non-font extension should be filtered out entirely.
        #expect(result.totalCount == 0)
    }

    @Test func importHandlesNonExistentFile() throws {
        let ctx = try makeInMemoryContext()
        let fakeURL = URL(filePath: "/nonexistent/path/to/font.ttf")

        let result = FontImportService.importFonts(from: [fakeURL], context: ctx)

        // Non-existent files are filtered out during URL resolution (they never
        // reach the processing stage), so totalCount should be 0.
        #expect(result.totalCount == 0)
        #expect(result.importedCount == 0)
    }

    // MARK: - Progress Reporting

    @Test func importProgressReporting() throws {
        let ctx = try makeInMemoryContext()
        let url1 = try bundledFontURL("Cousine-Regular.ttf")
        let url2 = try bundledFontURL("Inter-Variable.ttf")

        var progressCalls: [(processed: Int, total: Int)] = []

        _ = FontImportService.importFonts(from: [url1, url2], context: ctx) { processed, total in
            progressCalls.append((processed, total))
        }

        #expect(progressCalls.count == 2)
        #expect(progressCalls[0].processed == 1)
        #expect(progressCalls[0].total == 2)
        #expect(progressCalls[1].processed == 2)
        #expect(progressCalls[1].total == 2)
    }

    // MARK: - Result Counts

    @Test func importResultCountsAreConsistent() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        // Import once.
        let result1 = FontImportService.importFonts(from: [url], context: ctx)
        #expect(result1.totalCount == result1.importedCount + result1.duplicateCount + result1.failedCount)

        // Import again (will be duplicate).
        let result2 = FontImportService.importFonts(from: [url], context: ctx)
        #expect(result2.totalCount == result2.importedCount + result2.duplicateCount + result2.failedCount)
    }

    // MARK: - File Hash

    @Test func importedFontHasFileHash() throws {
        let ctx = try makeInMemoryContext()
        let url = try bundledFontURL("Cousine-Regular.ttf")

        let result = FontImportService.importFonts(from: [url], context: ctx)

        guard case .imported(let record) = result.items.first?.status else {
            Issue.record("Expected .imported status")
            return
        }

        let hash = try #require(record.fileHash)
        // SHA-256 hex string is 64 characters.
        #expect(hash.count == 64)
        // Should be all hex characters.
        #expect(hash.allSatisfy { $0.isHexDigit })
    }
}
