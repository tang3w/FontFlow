//
//  FontRecord+FontTraits.swift
//  FontFlow
//
//  Created on 2026/3/29.
//

import CoreData
import CoreText
import Foundation

extension FontRecord {

    var fontTraits: FontTraits {
        FontTraits(
            weight: traitWeight?.doubleValue,
            width: traitWidth?.doubleValue,
            slant: traitSlant?.doubleValue,
            symbolicTraits: CTFontSymbolicTraits(rawValue: UInt32(truncatingIfNeeded: traitSymbolicTraitsRaw))
        )
    }

    func applyFontTraits(_ traits: FontTraits) {
        traitWeight = traits.weight.map(NSNumber.init(value:))
        traitWidth = traits.width.map(NSNumber.init(value:))
        traitSlant = traits.slant.map(NSNumber.init(value:))
        traitSymbolicTraitsRaw = Int64(traits.symbolicTraits.rawValue)
    }

    var typefaceSortStableID: String {
        if !objectID.isTemporaryID {
            return objectID.uriRepresentation().absoluteString
        }

        if let postScriptName, !postScriptName.isEmpty {
            return postScriptName
        }

        if let displayName, !displayName.isEmpty {
            return displayName
        }

        if let styleName, !styleName.isEmpty {
            return styleName
        }

        if let id {
            return id.uuidString
        }

        return String(describing: Unmanaged.passUnretained(self).toOpaque())
    }
}
