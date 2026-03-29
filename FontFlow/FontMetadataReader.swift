//
//  FontMetadataReader.swift
//  FontFlow
//
//  Created on 2026/3/20.
//

import Foundation
import CoreText

// MARK: - Data Types

nonisolated struct VariationAxis: Sendable, Equatable {
    let name: String
    let identifier: UInt32
    let minValue: Double
    let maxValue: Double
    let defaultValue: Double
}

nonisolated struct FontFaceMetadata: Sendable {
    let postScriptName: String
    let displayName: String
    let familyName: String
    let styleName: String
    let fontTraits: FontTraits
    let isVariable: Bool
    let variationAxes: [VariationAxis]
    let glyphCount: Int
}

nonisolated struct FontFileMetadata: Sendable {
    let fileURL: URL
    let fileSize: Int64
    let faces: [FontFaceMetadata]

    var isCollection: Bool { faces.count > 1 }
}

// MARK: - Reader

nonisolated struct FontMetadataReader {

    enum ReadError: Error, Equatable {
        case fileNotFound(URL)
        case unreadableFont(URL)
    }

    static let supportedExtensions: Set<String> = [
        "ttf", "otf", "ttc", "otc", "woff", "woff2"
    ]

    static func readMetadata(from url: URL) throws -> FontFileMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ReadError.fileNotFound(url)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0

        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              !descriptors.isEmpty else {
            throw ReadError.unreadableFont(url)
        }

        let faces = descriptors.map { descriptor -> FontFaceMetadata in
            let psName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String ?? ""
            let display = CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String ?? ""
            let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? ""
            let style = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? ""

            let font = CTFontCreateWithFontDescriptor(descriptor, 0, nil)
            let glyphCount = CTFontGetGlyphCount(font)
            let fontTraits = readFontTraits(from: font)

            var axes: [VariationAxis] = []
            if let rawAxes = CTFontCopyVariationAxes(font) as? [[String: Any]] {
                axes = rawAxes.compactMap { dict in
                    guard let name = dict[kCTFontVariationAxisNameKey as String] as? String,
                          let id = dict[kCTFontVariationAxisIdentifierKey as String] as? UInt32,
                          let min = dict[kCTFontVariationAxisMinimumValueKey as String] as? Double,
                          let max = dict[kCTFontVariationAxisMaximumValueKey as String] as? Double,
                          let def = dict[kCTFontVariationAxisDefaultValueKey as String] as? Double
                    else { return nil }
                    return VariationAxis(name: name, identifier: id, minValue: min, maxValue: max, defaultValue: def)
                }
            }

            return FontFaceMetadata(
                postScriptName: psName,
                displayName: display,
                familyName: family,
                styleName: style,
                fontTraits: fontTraits,
                isVariable: !axes.isEmpty,
                variationAxes: axes,
                glyphCount: glyphCount
            )
        }

        return FontFileMetadata(fileURL: url, fileSize: fileSize, faces: faces)
    }

    private static func readFontTraits(from font: CTFont) -> FontTraits {
        let rawTraits = CTFontCopyTraits(font) as NSDictionary

        return FontTraits(
            weight: numericTrait(kCTFontWeightTrait, from: rawTraits),
            width: numericTrait(kCTFontWidthTrait, from: rawTraits),
            slant: numericTrait(kCTFontSlantTrait, from: rawTraits),
            symbolicTraits: CTFontGetSymbolicTraits(font)
        )
    }

    private static func numericTrait(_ key: CFString, from traits: NSDictionary) -> Double? {
        (traits[key] as? NSNumber)?.doubleValue
    }
}
