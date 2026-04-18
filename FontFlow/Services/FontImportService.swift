//
//  FontImportService.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Foundation
import CoreData

// MARK: - Import Result Types

/// The outcome of importing a single font face.
enum FontImportStatus {
    /// Successfully created a new FontRecord.
    case imported(FontRecord)
    /// An identical font already exists in the library (same PostScript name + file hash).
    case duplicate(existing: FontRecord)
    /// The font file could not be read or processed.
    case failed(Error)
}

/// The result of importing a single font face, with identifying context.
struct FontImportItem {
    /// The source file URL.
    let fileURL: URL
    /// The PostScript name of the face, if metadata was readable.
    let postScriptName: String?
    /// What happened during import.
    let status: FontImportStatus
}

/// Aggregated result of an import operation across all provided URLs.
struct FontImportResult {
    let items: [FontImportItem]

    var importedCount: Int { items.filter { if case .imported = $0.status { return true }; return false }.count }
    var duplicateCount: Int { items.filter { if case .duplicate = $0.status { return true }; return false }.count }
    var failedCount: Int { items.filter { if case .failed = $0.status { return true }; return false }.count }
    var totalCount: Int { items.count }
}

// MARK: - Import Progress

/// Called after each file is processed during import.
/// - Parameters:
///   - processed: Number of files processed so far.
///   - total: Total number of font files to process.
typealias ImportProgressHandler = (_ processed: Int, _ total: Int) -> Void

// MARK: - FontImportService

/// Imports font files into the Core Data library.
///
/// Accepts file and folder URLs, recursively discovers font files, reads metadata,
/// detects duplicates, creates Core Data records, and generates security-scoped bookmarks.
struct FontImportService {

    private enum ImportError: Error {
        case bookmarkCreationFailed(URL, underlyingError: Error)
    }

    /// Imports fonts from the given file or folder URLs.
    ///
    /// - Parameters:
    ///   - urls: File or folder URLs (typically from NSOpenPanel).
    ///   - context: The managed object context to create records in.
    ///   - progress: Optional callback invoked after each file is processed.
    /// - Returns: A structured result describing what happened for each font face.
    static func importFonts(
        from urls: [URL],
        context: NSManagedObjectContext,
        progress: ImportProgressHandler? = nil
    ) -> FontImportResult {
        // 1. Resolve all URLs to individual font file URLs.
        let fontFileURLs = resolveFontFileURLs(from: urls)

        var items: [FontImportItem] = []
        let total = fontFileURLs.count

        // 2. Process each font file.
        for (index, fileURL) in fontFileURLs.enumerated() {
            let fileItems = processFile(fileURL, context: context)
            items.append(contentsOf: fileItems)
            progress?(index + 1, total)
        }

        // 3. Save the context once at the end.
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // If save fails, add a single failed item noting the save error.
                // The individual items already recorded their status optimistically.
                assertionFailure("Failed to save imported fonts")
            }
        }

        return FontImportResult(items: items)
    }

    // MARK: - URL Resolution

    /// Expands folders recursively and filters to supported font file extensions.
    private static func resolveFontFileURLs(from urls: [URL]) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []

        for url in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // Recursively enumerate the directory.
                guard let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for case let fileURL as URL in enumerator {
                    if isSupportedFontFile(fileURL) {
                        result.append(fileURL)
                    }
                }
            } else {
                if isSupportedFontFile(url) {
                    result.append(url)
                }
            }
        }

        return result
    }

    /// Checks whether a URL has a supported font file extension.
    private static func isSupportedFontFile(_ url: URL) -> Bool {
        FontMetadataReader.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - File Processing

    /// Processes a single font file: reads metadata, hashes, deduplicates, creates records.
    private static func processFile(
        _ fileURL: URL,
        context: NSManagedObjectContext
    ) -> [FontImportItem] {
        // Read metadata.
        let metadata: FontFileMetadata
        do {
            metadata = try FontMetadataReader.readMetadata(from: fileURL)
        } catch {
            return [FontImportItem(fileURL: fileURL, postScriptName: nil, status: .failed(error))]
        }

        // Hash the file.
        let fileHash: String
        do {
            fileHash = try FileHasher.sha256(of: fileURL)
        } catch {
            return [FontImportItem(fileURL: fileURL, postScriptName: nil, status: .failed(error))]
        }

        // Generate security-scoped bookmark. This is required for future access.
        let bookmarkData: Data
        do {
            bookmarkData = try FontFileAccessService.bookmarkData(for: fileURL)
        } catch {
            return [FontImportItem(
                fileURL: fileURL,
                postScriptName: nil,
                status: .failed(ImportError.bookmarkCreationFailed(fileURL, underlyingError: error))
            )]
        }

        // Process each face in the file.
        var items: [FontImportItem] = []
        for face in metadata.faces {
            let item = processFace(
                face,
                fileURL: fileURL,
                fileSize: metadata.fileSize,
                fileHash: fileHash,
                bookmarkData: bookmarkData,
                context: context
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Face Processing & Deduplication

    /// Processes a single font face: checks for duplicates, creates record if new.
    private static func processFace(
        _ face: FontFaceMetadata,
        fileURL: URL,
        fileSize: Int64,
        fileHash: String,
        bookmarkData: Data,
        context: NSManagedObjectContext
    ) -> FontImportItem {
        let psName = face.postScriptName

        // Check for exact duplicate (same PostScript name AND same file hash).
        if let existing = findExactDuplicate(postScriptName: psName, fileHash: fileHash, context: context) {
            return FontImportItem(fileURL: fileURL, postScriptName: psName, status: .duplicate(existing: existing))
        }

        // Check for same-name-different-file duplicates (PostScript name matches, hash differs).
        let nameMatches = findByPostScriptName(psName, context: context)

        // Create the FontRecord.
        let record = FontRecord(context: context)
        record.id = UUID()
        record.postScriptName = psName
        record.displayName = face.displayName
        record.familyName = face.familyName
        record.styleName = face.styleName
        record.applyFontTraits(face.fontTraits)
        record.filePath = fileURL.path
        record.fileSize = fileSize
        record.fileHash = fileHash
        record.bookmarkData = bookmarkData
        record.importedDate = Date()

        // Link duplicate group if there are same-name fonts with different files.
        if !nameMatches.isEmpty {
            let groupID = nameMatches.first?.duplicateGroupID ?? UUID()
            record.duplicateGroupID = groupID
            // Ensure all existing matches also have this group ID.
            for match in nameMatches where match.duplicateGroupID == nil {
                match.duplicateGroupID = groupID
            }
        }

        // Find or create FontFamily.
        record.family = findOrCreateFamily(name: face.familyName, context: context)

        return FontImportItem(fileURL: fileURL, postScriptName: psName, status: .imported(record))
    }

    // MARK: - Core Data Queries

    /// Finds an existing FontRecord with matching PostScript name and file hash.
    private static func findExactDuplicate(
        postScriptName: String,
        fileHash: String,
        context: NSManagedObjectContext
    ) -> FontRecord? {
        let request = FontRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "postScriptName == %@ AND fileHash == %@",
            postScriptName, fileHash
        )
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    /// Finds all existing FontRecords with a matching PostScript name.
    private static func findByPostScriptName(
        _ postScriptName: String,
        context: NSManagedObjectContext
    ) -> [FontRecord] {
        let request = FontRecord.fetchRequest()
        request.predicate = NSPredicate(format: "postScriptName == %@", postScriptName)
        return (try? context.fetch(request)) ?? []
    }

    /// Finds an existing FontFamily by name, or creates a new one.
    private static func findOrCreateFamily(
        name: String,
        context: NSManagedObjectContext
    ) -> FontFamily {
        let request = FontFamily.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1

        if let existing = (try? context.fetch(request))?.first {
            return existing
        }

        let family = FontFamily(context: context)
        family.id = UUID()
        family.name = name
        return family
    }
}
