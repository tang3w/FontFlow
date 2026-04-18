//
//  FontBrowserModels.swift
//  FontFlow
//
//  Models that drive the font browser's grid and list child controllers.
//  These are plain (non-`NSManagedObject`) types built from a Core Data fetch
//  by `FontBrowserSnapshotBuilder`. Identity is keyed by `NSManagedObjectID`
//  so two families (or typefaces) with the same display name remain distinct.
//

import CoreData
import Foundation

// MARK: - Identifiers

/// Stable identity for a family within a snapshot.
struct FontFamilyID: Hashable {
    let objectID: NSManagedObjectID
}

/// Stable identity for a typeface within a snapshot.
struct FontTypefaceID: Hashable {
    let objectID: NSManagedObjectID
}

// MARK: - Typeface Item

/// One typeface row in either the grid or the list.
///
/// Reference type because `NSOutlineView` expects items to maintain identity
/// across reloads, and so future mutable state (e.g. selection) can attach
/// here without copy semantics.
final class FontTypefaceItem {

    let id: FontTypefaceID
    let familyID: FontFamilyID
    /// Pre-resolved label for cell rendering.
    /// `styleName ?? displayName ?? postScriptName ?? "Unknown"`.
    let displayLabel: String
    /// Underlying record. Cells still need this for font loading (PostScript
    /// name, file path) and the browser delegate publishes `[FontRecord]`.
    let record: FontRecord

    init(
        id: FontTypefaceID,
        familyID: FontFamilyID,
        displayLabel: String,
        record: FontRecord
    ) {
        self.id = id
        self.familyID = familyID
        self.displayLabel = displayLabel
        self.record = record
    }
}

// MARK: - Family Section

/// One family section. `typefaces` is non-empty by construction — the snapshot
/// builder drops families that produce no valid typefaces.
final class FontFamilySection {

    let id: FontFamilyID
    /// Pre-resolved family name for cell rendering. Falls back to "Unknown".
    let displayName: String
    let typefaces: [FontTypefaceItem]

    var typefaceCount: Int { typefaces.count }

    init(
        id: FontFamilyID,
        displayName: String,
        typefaces: [FontTypefaceItem]
    ) {
        self.id = id
        self.displayName = displayName
        self.typefaces = typefaces
    }
}

// MARK: - Snapshot

/// Immutable snapshot delivered to the grid and list child controllers.
struct FontBrowserSnapshot {

    let families: [FontFamilySection]
    let familyByID: [FontFamilyID: FontFamilySection]
    let typefaceByID: [FontTypefaceID: FontTypefaceItem]

    var familyCount: Int { families.count }
    var totalTypefaceCount: Int { typefaceByID.count }

    static let empty = FontBrowserSnapshot(
        families: [],
        familyByID: [:],
        typefaceByID: [:]
    )

    init(
        families: [FontFamilySection],
        familyByID: [FontFamilyID: FontFamilySection],
        typefaceByID: [FontTypefaceID: FontTypefaceItem]
    ) {
        self.families = families
        self.familyByID = familyByID
        self.typefaceByID = typefaceByID
    }
}
