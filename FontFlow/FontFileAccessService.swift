//
//  FontFileAccessService.swift
//  FontFlow
//
//  Created on 2026/3/24.
//

import Foundation
import CoreData

@MainActor
enum FontFileAccessService {

    struct BookmarkResolution {
        let url: URL
        let isStale: Bool
    }

    private static let bookmarkCreationOptions: URL.BookmarkCreationOptions = [
        .withSecurityScope,
        .securityScopeAllowOnlyReadAccess,
    ]

    private static let bookmarkResolutionOptions: URL.BookmarkResolutionOptions = [
        .withSecurityScope,
        .withoutUI,
    ]

    static func bookmarkData(for fileURL: URL) throws -> Data {
        try fileURL.bookmarkData(
            options: bookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolvedFileURL(for record: FontRecord) -> URL? {
        resolvedFileURL(
            for: record,
            bookmarkResolver: resolveBookmarkData(_:),
            bookmarkDataProvider: bookmarkData(for:)
        )
    }

    static func withResolvedFileAccess<T>(for record: FontRecord, access: @MainActor (URL) -> T?) -> T? {
        guard let fileURL = resolvedFileURL(for: record) else {
            return nil
        }

        let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        return access(fileURL)
    }

    static func resolvedFileURL(
        for record: FontRecord,
        bookmarkResolver: @MainActor (Data) throws -> BookmarkResolution,
        bookmarkDataProvider: @MainActor (URL) throws -> Data
    ) -> URL? {
        if let bookmarkData = record.bookmarkData {
            do {
                let resolution = try bookmarkResolver(bookmarkData)
                refreshStaleBookmarkIfNeeded(
                    for: record,
                    resolution: resolution,
                    bookmarkDataProvider: bookmarkDataProvider
                )
                return resolution.url
            } catch {
                NSLog(
                    "FontFileAccessService: Failed to resolve bookmark for %@ - %@",
                    record.postScriptName ?? "Unknown",
                    String(describing: error)
                )
            }
        }

        return fileURLFromPath(for: record)
    }

    static func resolveBookmarkData(_ bookmarkData: Data) throws -> BookmarkResolution {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return BookmarkResolution(url: url, isStale: isStale)
    }

    @discardableResult
    static func refreshStaleBookmarkIfNeeded(
        for record: FontRecord,
        resolution: BookmarkResolution,
        bookmarkDataProvider: @MainActor (URL) throws -> Data
    ) -> Bool {
        guard resolution.isStale else {
            return false
        }

        do {
            let refreshedBookmarkData = try withSecurityScopedAccess(to: resolution.url) { fileURL in
                try bookmarkDataProvider(fileURL)
            }

            guard persistBookmarkDataIfNeeded(refreshedBookmarkData, for: record) else {
                return false
            }

            NSLog(
                "FontFileAccessService: Refreshed stale bookmark for %@",
                record.postScriptName ?? "Unknown"
            )
            return true
        } catch {
            NSLog(
                "FontFileAccessService: Failed to refresh stale bookmark for %@ - %@",
                record.postScriptName ?? "Unknown",
                String(describing: error)
            )
            return false
        }
    }

    private static func fileURLFromPath(for record: FontRecord) -> URL? {
        guard let filePath = record.filePath, !filePath.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: filePath)
    }

    private static func persistBookmarkDataIfNeeded(_ bookmarkData: Data, for record: FontRecord) -> Bool {
        guard record.bookmarkData != bookmarkData else {
            return false
        }

        guard let context = record.managedObjectContext else {
            record.bookmarkData = bookmarkData
            return true
        }

        guard let coordinator = context.persistentStoreCoordinator, !record.objectID.isTemporaryID else {
            record.bookmarkData = bookmarkData
            return true
        }

        let objectID = record.objectID
        let persistenceContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        persistenceContext.persistentStoreCoordinator = coordinator
        persistenceContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        var saveError: Error?
        var didPersist = false

        persistenceContext.performAndWait {
            do {
                guard let persistedRecord = try persistenceContext.existingObject(with: objectID) as? FontRecord else {
                    return
                }

                guard persistedRecord.bookmarkData != bookmarkData else {
                    return
                }

                persistedRecord.bookmarkData = bookmarkData

                if persistenceContext.hasChanges {
                    try persistenceContext.save()
                    didPersist = true
                }
            } catch {
                saveError = error
            }
        }

        if let saveError {
            NSLog(
                "FontFileAccessService: Failed to persist refreshed bookmark for %@ - %@",
                record.postScriptName ?? "Unknown",
                String(describing: saveError)
            )
            return false
        }

        guard didPersist else {
            return false
        }

        context.performAndWait {
            guard let localRecord = try? context.existingObject(with: objectID) as? FontRecord else {
                return
            }

            context.refresh(localRecord, mergeChanges: true)
        }

        return true
    }

    private static func withSecurityScopedAccess<T>(to fileURL: URL, access: @MainActor (URL) throws -> T) rethrows -> T {
        let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        return try access(fileURL)
    }
}
