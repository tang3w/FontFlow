//
//  FontStyleSortingTests.swift
//  FontFlowTests
//
//  Created on 2026/3/29.
//

import Testing
import CoreText
@testable import FontFlow

struct FontStyleSortingTests {

    @Test func sortsNormalWidthBeforeCondensedAndExpanded() {
        let regular = TestFontFace(
            traits: FontTraits(weight: 0, width: 0, slant: 0),
            styleName: "Regular",
            stableID: "regular"
        )
        let condensed = TestFontFace(
            traits: FontTraits(weight: 0, width: -0.3, slant: 0, symbolicTraits: [.traitCondensed]),
            styleName: "Condensed",
            stableID: "condensed"
        )
        let expanded = TestFontFace(
            traits: FontTraits(weight: 0, width: 0.4, slant: 0, symbolicTraits: [.traitExpanded]),
            styleName: "Expanded",
            stableID: "expanded"
        )

        let sorted = [expanded, condensed, regular].sorted(by: TestFontFace.areInIncreasingOrder)
        #expect(sorted.map(\.stableID) == ["regular", "condensed", "expanded"])
    }

    @Test func sortsCloserWidthsBeforeMoreExtremeWidthsWithinBucket() {
        let semiCondensed = TestFontFace(
            traits: FontTraits(weight: 0, width: -0.15, slant: 0),
            styleName: "Semi Condensed",
            stableID: "semi-condensed"
        )
        let condensed = TestFontFace(
            traits: FontTraits(weight: 0, width: -0.35, slant: 0),
            styleName: "Condensed",
            stableID: "condensed"
        )

        let sorted = [condensed, semiCondensed].sorted(by: TestFontFace.areInIncreasingOrder)
        #expect(sorted.map(\.stableID) == ["semi-condensed", "condensed"])
    }

    @Test func sortsWeightFromLightToBlack() {
        let light = TestFontFace(
            traits: FontTraits(weight: -0.3, width: 0, slant: 0),
            styleName: "Light",
            stableID: "light"
        )
        let regular = TestFontFace(
            traits: FontTraits(weight: 0, width: 0, slant: 0),
            styleName: "Regular",
            stableID: "regular"
        )
        let black = TestFontFace(
            traits: FontTraits(weight: 0.8, width: 0, slant: 0, symbolicTraits: [.traitBold]),
            styleName: "Black",
            stableID: "black"
        )

        let sorted = [black, regular, light].sorted(by: TestFontFace.areInIncreasingOrder)
        #expect(sorted.map(\.stableID) == ["light", "regular", "black"])
    }

    @Test func sortsUprightBeforeItalicWhenOtherTraitsMatch() {
        let regular = TestFontFace(
            traits: FontTraits(weight: 0, width: 0, slant: 0),
            styleName: "Regular",
            stableID: "regular"
        )
        let italic = TestFontFace(
            traits: FontTraits(weight: 0, width: 0, slant: 0.1, symbolicTraits: [.traitItalic]),
            styleName: "Italic",
            stableID: "italic"
        )

        let sorted = [italic, regular].sorted(by: TestFontFace.areInIncreasingOrder)
        #expect(sorted.map(\.stableID) == ["regular", "italic"])
    }

    @Test func fallsBackToStyleNameWhenTraitsMatch() {
        let alpha = TestFontFace(
            traits: FontTraits(weight: 0, width: 0, slant: 0),
            styleName: "Alpha",
            stableID: "alpha"
        )
        let beta = TestFontFace(
            traits: FontTraits(weight: 0, width: 0, slant: 0),
            styleName: "Beta",
            stableID: "beta"
        )

        let sorted = [beta, alpha].sorted(by: TestFontFace.areInIncreasingOrder)
        #expect(sorted.map(\.stableID) == ["alpha", "beta"])
    }
}

private struct TestFontFace {
    let traits: FontTraits
    let styleName: String?
    let displayName: String?
    let postScriptName: String?
    let stableID: String

    init(
        traits: FontTraits,
        styleName: String?,
        displayName: String? = nil,
        postScriptName: String? = nil,
        stableID: String
    ) {
        self.traits = traits
        self.styleName = styleName
        self.displayName = displayName
        self.postScriptName = postScriptName
        self.stableID = stableID
    }

    static func areInIncreasingOrder(_ lhs: TestFontFace, _ rhs: TestFontFace) -> Bool {
        FontFamilyTypefaceSorter.areInIncreasingOrder(
            lhsTraits: lhs.traits,
            rhsTraits: rhs.traits,
            lhsStyleName: lhs.styleName,
            rhsStyleName: rhs.styleName,
            lhsDisplayName: lhs.displayName,
            rhsDisplayName: rhs.displayName,
            lhsPostScriptName: lhs.postScriptName,
            rhsPostScriptName: rhs.postScriptName,
            lhsStableID: lhs.stableID,
            rhsStableID: rhs.stableID
        )
    }
}
