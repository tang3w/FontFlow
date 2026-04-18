//
//  FontBrowserSnapshotBuilder.swift
//  FontFlow
//
//  Builds an immutable `FontBrowserSnapshot` from a managed object context
//  for the font browser. Centralizes:
//  - fetching `FontRecord`s with a predicate
//  - validating that every typeface has a family (asserts and discards
//    malformed records)
//  - resolving display labels (`styleName ?? displayName ?? postScriptName`)
//  - grouping typefaces under their families and sorting deterministically
//

import CoreData
import Foundation

struct FontBrowserSnapshotBuilder {

    /// Builds a snapshot from a managed context.
    ///
    /// Records without a `family` relationship are considered malformed:
    /// `assertionFailure` fires in debug, and the records are discarded in
    /// release.
    func build(
        in context: NSManagedObjectContext,
        predicate: NSPredicate?
    ) -> FontBrowserSnapshot {
        let request = FontRecord.fetchRequest()
        request.predicate = predicate
        // The final family/typeface ordering is computed below; this just
        // provides a stable input ordering for grouping.
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "familyName",
                ascending: true,
                selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
            ),
        ]

        let records: [FontRecord]
        do {
            records = try context.fetch(request)
        } catch {
            assertionFailure("FontBrowserSnapshotBuilder fetch failed: \(error)")
            return .empty
        }

        // Group typefaces by their family object, dropping malformed records.
        var typefacesByFamily: [NSManagedObjectID: (family: FontFamily, items: [FontTypefaceItem])] = [:]

        for record in records {
            guard let family = record.family else {
                assertionFailure("FontRecord without family encountered: \(record.objectID)")
                continue
            }

            let familyID = FontFamilyID(objectID: family.objectID)
            let item = FontTypefaceItem(
                id: FontTypefaceID(objectID: record.objectID),
                familyID: familyID,
                displayLabel: Self.resolvedDisplayLabel(for: record),
                record: record
            )

            if var bucket = typefacesByFamily[family.objectID] {
                bucket.items.append(item)
                typefacesByFamily[family.objectID] = bucket
            } else {
                typefacesByFamily[family.objectID] = (family, [item])
            }
        }

        // Build sections: sort each family's typefaces, drop empty families.
        var sections: [FontFamilySection] = []
        sections.reserveCapacity(typefacesByFamily.count)

        for (_, bucket) in typefacesByFamily {
            let sortedTypefaces = bucket.items.sorted { lhs, rhs in
                Self.areInIncreasingOrder(lhs: lhs.record, rhs: rhs.record)
            }
            guard !sortedTypefaces.isEmpty else { continue }

            let section = FontFamilySection(
                id: FontFamilyID(objectID: bucket.family.objectID),
                displayName: Self.resolvedDisplayName(for: bucket.family),
                typefaces: sortedTypefaces
            )
            sections.append(section)
        }

        // Sort families by display name.
        sections.sort { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        // Build lookup dictionaries.
        var familyByID: [FontFamilyID: FontFamilySection] = [:]
        familyByID.reserveCapacity(sections.count)
        var typefaceByID: [FontTypefaceID: FontTypefaceItem] = [:]
        typefaceByID.reserveCapacity(records.count)

        for section in sections {
            familyByID[section.id] = section
            for item in section.typefaces {
                typefaceByID[item.id] = item
            }
        }

        return FontBrowserSnapshot(
            families: sections,
            familyByID: familyByID,
            typefaceByID: typefaceByID
        )
    }

    // MARK: - Helpers

    private static func resolvedDisplayLabel(for record: FontRecord) -> String {
        if let styleName = record.styleName, !styleName.isEmpty { return styleName }
        if let displayName = record.displayName, !displayName.isEmpty { return displayName }
        if let postScriptName = record.postScriptName, !postScriptName.isEmpty { return postScriptName }
        return "Unknown"
    }

    private static func resolvedDisplayName(for family: FontFamily) -> String {
        if let name = family.name, !name.isEmpty { return name }
        return "Unknown"
    }

    private static func areInIncreasingOrder(lhs: FontRecord, rhs: FontRecord) -> Bool {
        FontFamilyTypefaceSorter.areInIncreasingOrder(
            lhsTraits: lhs.fontTraits,
            rhsTraits: rhs.fontTraits,
            lhsStyleName: lhs.styleName,
            rhsStyleName: rhs.styleName,
            lhsDisplayName: lhs.displayName,
            rhsDisplayName: rhs.displayName,
            lhsPostScriptName: lhs.postScriptName,
            rhsPostScriptName: rhs.postScriptName,
            lhsStableID: lhs.typefaceSortStableID,
            rhsStableID: rhs.typefaceSortStableID
        )
    }
}
