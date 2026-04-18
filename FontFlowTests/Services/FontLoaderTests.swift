//
//  FontLoaderTests.swift
//  FontFlowTests
//
//  Created on 2026/3/23.
//

import Testing
import AppKit
import CoreData
import CoreText
@testable import FontFlow

@MainActor
struct FontLoaderTests {

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

    private func bundledFontURL(_ filename: String) throws -> URL {
        let bundle = Bundle(for: TestBundleAnchor.self)
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw FontMetadataReader.ReadError.fileNotFound(URL(fileURLWithPath: filename))
        }

        return url
    }

    @Test func loadsImportedFontFromBookmarkData() throws {
        let context = try makeInMemoryContext()
        let fileURL = try bundledFontURL("Cousine-Regular.ttf")
        let result = FontImportService.importFonts(from: [fileURL], context: context)

        guard case .imported(let record) = result.items.first?.status else {
            Issue.record("Expected imported record")
            return
        }

        let font = try #require(FontLoader.font(for: record, size: 24))
        #expect(font.fontName == record.postScriptName)
        #expect(FontFileAccessService.resolvedFileURL(for: record)?.lastPathComponent == fileURL.lastPathComponent)
    }

    @Test func selectsMatchingFaceFromFontCollection() throws {
        let collectionURL = URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc")
        let metadata = try FontMetadataReader.readMetadata(from: collectionURL)
        let targetFace = try #require(metadata.faces.last)

        let context = try makeInMemoryContext()
        let record = FontRecord(context: context)
        record.id = UUID()
        record.postScriptName = targetFace.postScriptName
        record.displayName = targetFace.displayName
        record.familyName = targetFace.familyName
        record.styleName = targetFace.styleName
        record.filePath = collectionURL.path
        record.importedDate = Date()

        let descriptor = try #require(FontLoader.fontDescriptor(for: record))
        let descriptorName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
        #expect(descriptorName == targetFace.postScriptName)
    }

    @Test func staleBookmarkRefreshesStoredBookmarkData() throws {
        let context = try makeInMemoryContext()
        let originalBookmarkData = Data("old-bookmark".utf8)
        let refreshedBookmarkData = Data("new-bookmark".utf8)
        let resolvedURL = URL(fileURLWithPath: "/tmp/stale-font.ttf")

        let record = FontRecord(context: context)
        record.id = UUID()
        record.postScriptName = "StaleFont-Regular"
        record.displayName = "Stale Font Regular"
        record.familyName = "Stale Font"
        record.styleName = "Regular"
        record.filePath = resolvedURL.path
        record.bookmarkData = originalBookmarkData
        record.importedDate = Date()
        try context.save()

        let returnedURL = FontFileAccessService.resolvedFileURL(
            for: record,
            bookmarkResolver: { _ in
                FontFileAccessService.BookmarkResolution(url: resolvedURL, isStale: true)
            },
            bookmarkDataProvider: { _ in
                refreshedBookmarkData
            }
        )

        #expect(returnedURL == resolvedURL)
        #expect(record.bookmarkData == refreshedBookmarkData)
    }

    @Test func nonStaleBookmarkDoesNotRegenerate() throws {
        let context = try makeInMemoryContext()
        let originalBookmarkData = Data("stable-bookmark".utf8)
        let resolvedURL = URL(fileURLWithPath: "/tmp/stable-font.ttf")

        let record = FontRecord(context: context)
        record.id = UUID()
        record.postScriptName = "StableFont-Regular"
        record.displayName = "Stable Font Regular"
        record.familyName = "Stable Font"
        record.styleName = "Regular"
        record.filePath = resolvedURL.path
        record.bookmarkData = originalBookmarkData
        record.importedDate = Date()
        try context.save()

        var bookmarkProviderCallCount = 0
        let returnedURL = FontFileAccessService.resolvedFileURL(
            for: record,
            bookmarkResolver: { _ in
                FontFileAccessService.BookmarkResolution(url: resolvedURL, isStale: false)
            },
            bookmarkDataProvider: { _ in
                bookmarkProviderCallCount += 1
                return Data("should-not-be-used".utf8)
            }
        )

        #expect(returnedURL == resolvedURL)
        #expect(bookmarkProviderCallCount == 0)
        #expect(record.bookmarkData == originalBookmarkData)
    }

    @Test func fallsBackToFilePathWhenBookmarkResolutionFails() throws {
        let context = try makeInMemoryContext()
        let fallbackURL = URL(fileURLWithPath: "/tmp/fallback-font.ttf")

        let record = FontRecord(context: context)
        record.id = UUID()
        record.postScriptName = "FallbackFont-Regular"
        record.displayName = "Fallback Font Regular"
        record.familyName = "Fallback Font"
        record.styleName = "Regular"
        record.filePath = fallbackURL.path
        record.bookmarkData = Data("broken-bookmark".utf8)
        record.importedDate = Date()

        let returnedURL = FontFileAccessService.resolvedFileURL(
            for: record,
            bookmarkResolver: { _ in
                struct BookmarkFailure: Error {}
                throw BookmarkFailure()
            },
            bookmarkDataProvider: { _ in
                Data()
            }
        )

        #expect(returnedURL == fallbackURL)
    }
}
