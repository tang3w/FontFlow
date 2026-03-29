//
//  FontStyleSorting.swift
//  FontFlow
//
//  Created on 2026/3/29.
//

import CoreText
import Foundation

nonisolated struct FontTraits: Sendable, Equatable {

    enum WidthBucket: Int, Sendable {
        case normal = 0
        case condensed = 1
        case expanded = 2
    }

    static let normalWidthThreshold = 0.05
    static let italicSlantThreshold = 0.01
    private static let condensedFallbackWidth = -1.0
    private static let expandedFallbackWidth = 1.0
    private static let boldFallbackWeight = 0.4

    let weight: Double?
    let width: Double?
    let slant: Double?
    let symbolicTraits: CTFontSymbolicTraits

    init(
        weight: Double? = nil,
        width: Double? = nil,
        slant: Double? = nil,
        symbolicTraits: CTFontSymbolicTraits = []
    ) {
        self.weight = weight
        self.width = width
        self.slant = slant
        self.symbolicTraits = symbolicTraits
    }

    var effectiveWeight: Double {
        if let weight {
            return weight
        }
        return symbolicTraits.contains(.traitBold) ? Self.boldFallbackWeight : 0
    }

    var effectiveWidth: Double {
        if let width {
            return width
        }
        if symbolicTraits.contains(.traitCondensed) {
            return Self.condensedFallbackWidth
        }
        if symbolicTraits.contains(.traitExpanded) {
            return Self.expandedFallbackWidth
        }
        return 0
    }

    var effectiveSlant: Double {
        if let slant {
            return slant
        }
        return symbolicTraits.contains(.traitItalic) ? 1 : 0
    }

    var widthBucket: WidthBucket {
        let widthValue = effectiveWidth

        if widthValue < -Self.normalWidthThreshold {
            return .condensed
        }
        if widthValue > Self.normalWidthThreshold {
            return .expanded
        }
        return .normal
    }

    var widthDistanceFromNormal: Double {
        switch widthBucket {
        case .normal:
            return 0
        case .condensed, .expanded:
            return abs(effectiveWidth)
        }
    }

    var isItalicLike: Bool {
        symbolicTraits.contains(.traitItalic) || effectiveSlant > Self.italicSlantThreshold
    }

    var italicRank: Int {
        isItalicLike ? 1 : 0
    }
}

enum FontFamilyTypefaceSorter {

    static func areInIncreasingOrder(
        lhsTraits: FontTraits,
        rhsTraits: FontTraits,
        lhsStyleName: String?,
        rhsStyleName: String?,
        lhsDisplayName: String?,
        rhsDisplayName: String?,
        lhsPostScriptName: String?,
        rhsPostScriptName: String?,
        lhsStableID: String,
        rhsStableID: String
    ) -> Bool {
        if lhsTraits.widthBucket.rawValue != rhsTraits.widthBucket.rawValue {
            return lhsTraits.widthBucket.rawValue < rhsTraits.widthBucket.rawValue
        }

        if lhsTraits.widthDistanceFromNormal != rhsTraits.widthDistanceFromNormal {
            return lhsTraits.widthDistanceFromNormal < rhsTraits.widthDistanceFromNormal
        }

        if lhsTraits.effectiveWeight != rhsTraits.effectiveWeight {
            return lhsTraits.effectiveWeight < rhsTraits.effectiveWeight
        }

        if lhsTraits.italicRank != rhsTraits.italicRank {
            return lhsTraits.italicRank < rhsTraits.italicRank
        }

        if lhsTraits.effectiveSlant != rhsTraits.effectiveSlant {
            return lhsTraits.effectiveSlant < rhsTraits.effectiveSlant
        }

        let styleComparison = compare(lhsStyleName, rhsStyleName)
        if styleComparison != .orderedSame {
            return styleComparison == .orderedAscending
        }

        let displayComparison = compare(lhsDisplayName, rhsDisplayName)
        if displayComparison != .orderedSame {
            return displayComparison == .orderedAscending
        }

        let postScriptComparison = compare(lhsPostScriptName, rhsPostScriptName)
        if postScriptComparison != .orderedSame {
            return postScriptComparison == .orderedAscending
        }

        return lhsStableID < rhsStableID
    }

    private static func compare(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        let left = normalized(lhs)
        let right = normalized(rhs)

        switch (left, right) {
        case let (left?, right?):
            let insensitive = left.localizedCaseInsensitiveCompare(right)
            if insensitive != .orderedSame {
                return insensitive
            }
            return left.localizedCompare(right)
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedDescending
        case (_, nil):
            return .orderedAscending
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
