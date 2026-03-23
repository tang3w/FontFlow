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
        #expect(FontLoader.resolvedFileURL(for: record)?.lastPathComponent == fileURL.lastPathComponent)
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
}
