//
//  FontMetadataReaderTests.swift
//  FontFlowTests
//
//  Created on 2026/3/20.
//

import Testing
import Foundation
@testable import FontFlow

struct FontMetadataReaderTests {

    /// Returns the URL for a font file bundled in the test target's resources.
    private static func bundledFontURL(_ filename: String) throws -> URL {
        let bundle = Bundle(for: TestBundleAnchor.self)
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw FontMetadataReader.ReadError.fileNotFound(
                URL(fileURLWithPath: filename)
            )
        }
        return url
    }

    // MARK: - Supported Extensions

    @Test func supportedExtensionsContainsExpectedFormats() {
        let expected: Set<String> = ["ttf", "otf", "ttc", "otc", "woff", "woff2"]
        #expect(FontMetadataReader.supportedExtensions == expected)
    }

    // MARK: - Regular TTF Font (Cousine — Apache 2.0)

    @Test func readSingleTTFFont() throws {
        let url = try Self.bundledFontURL("Cousine-Regular.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(metadata.faces.count == 1)
        #expect(metadata.fileSize > 0)
        #expect(metadata.fileURL == url)
        #expect(!metadata.isCollection)

        let face = try #require(metadata.faces.first)
        #expect(face.familyName == "Cousine")
        #expect(face.styleName == "Regular")
        #expect(!face.postScriptName.isEmpty)
        #expect(!face.displayName.isEmpty)
        #expect(face.glyphCount > 0)
    }

    @Test func nonVariableFontHasNoAxes() throws {
        let url = try Self.bundledFontURL("Cousine-Regular.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        let face = try #require(metadata.faces.first)
        #expect(!face.isVariable)
        #expect(face.variationAxes.isEmpty)
    }

    // MARK: - Variable Font (Inter — SIL OFL)

    @Test func readVariableFont() throws {
        let url = try Self.bundledFontURL("Inter-Variable.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(!metadata.faces.isEmpty)

        let variableFaces = metadata.faces.filter(\.isVariable)
        #expect(!variableFaces.isEmpty, "Inter should contain at least one variable face")

        let variableFace = try #require(variableFaces.first)
        #expect(!variableFace.variationAxes.isEmpty)

        let weightAxis = variableFace.variationAxes.first { $0.name == "Weight" }
        #expect(weightAxis != nil, "Inter variable should have a Weight axis")
        if let weight = weightAxis {
            #expect(weight.minValue < weight.maxValue)
            #expect(weight.defaultValue >= weight.minValue)
            #expect(weight.defaultValue <= weight.maxValue)
        }
    }

    @Test func variationAxisValuesAreConsistent() throws {
        let url = try Self.bundledFontURL("Inter-Variable.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        for face in metadata.faces {
            for axis in face.variationAxes {
                #expect(axis.minValue <= axis.defaultValue,
                        "Axis \(axis.name): min (\(axis.minValue)) should be ≤ default (\(axis.defaultValue))")
                #expect(axis.defaultValue <= axis.maxValue,
                        "Axis \(axis.name): default (\(axis.defaultValue)) should be ≤ max (\(axis.maxValue))")
                #expect(!axis.name.isEmpty, "Axis name should not be empty")
            }
        }
    }

    // MARK: - Font Collection (TTC) — System Font

    @Test func readTTCFontCollection() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(metadata.faces.count > 1)
        #expect(metadata.isCollection)
        #expect(metadata.fileSize > 0)

        let psNames = Set(metadata.faces.map(\.postScriptName))
        #expect(psNames.count == metadata.faces.count, "Each face should have a unique PostScript name")

        for face in metadata.faces {
            #expect(!face.postScriptName.isEmpty)
            #expect(!face.familyName.isEmpty)
            #expect(!face.displayName.isEmpty)
            #expect(face.glyphCount > 0)
        }
    }

    // MARK: - Error Handling

    @Test func fileNotFoundThrows() {
        let url = URL(fileURLWithPath: "/nonexistent/path/to/font.ttf")
        #expect(throws: FontMetadataReader.ReadError.fileNotFound(url)) {
            try FontMetadataReader.readMetadata(from: url)
        }
    }

    @Test func nonFontFileThrowsUnreadable() throws {
        let url = URL(fileURLWithPath: "/etc/hosts")
        #expect {
            try FontMetadataReader.readMetadata(from: url)
        } throws: { error in
            guard let readError = error as? FontMetadataReader.ReadError else { return false }
            return readError == .unreadableFont(url)
        }
    }

    // MARK: - Metadata Completeness

    @Test func allFacesHaveRequiredFields() throws {
        let urls = [
            try Self.bundledFontURL("Cousine-Regular.ttf"),
            try Self.bundledFontURL("Inter-Variable.ttf"),
        ]

        for url in urls {
            let metadata = try FontMetadataReader.readMetadata(from: url)
            for face in metadata.faces {
                #expect(!face.postScriptName.isEmpty, "\(url.lastPathComponent): PostScript name missing")
                #expect(!face.familyName.isEmpty, "\(url.lastPathComponent): Family name missing")
                #expect(!face.displayName.isEmpty, "\(url.lastPathComponent): Display name missing")
                #expect(face.glyphCount > 0, "\(url.lastPathComponent): Glyph count should be positive")
            }
        }
    }

    @Test func fileSizeIsPositive() throws {
        let url = try Self.bundledFontURL("Cousine-Regular.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)
        #expect(metadata.fileSize > 0)
    }

    @Test func fileURLIsPreserved() throws {
        let url = try Self.bundledFontURL("Cousine-Regular.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)
        #expect(metadata.fileURL == url)
    }
}
