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

    // MARK: - Supported Extensions

    @Test func supportedExtensionsContainsExpectedFormats() {
        let expected: Set<String> = ["ttf", "otf", "ttc", "otc", "woff", "woff2"]
        #expect(FontMetadataReader.supportedExtensions == expected)
    }

    // MARK: - Regular TTF Font

    @Test func readSingleTTFFont() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(metadata.faces.count == 1)
        #expect(metadata.fileSize > 0)
        #expect(metadata.fileURL == url)
        #expect(!metadata.isCollection)

        let face = try #require(metadata.faces.first)
        #expect(face.familyName == "Arial")
        #expect(face.styleName == "Regular")
        #expect(!face.postScriptName.isEmpty)
        #expect(!face.displayName.isEmpty)
        #expect(face.glyphCount > 0)
    }

    // MARK: - Font Collection (TTC)

    @Test func readTTCFontCollection() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(metadata.faces.count > 1)
        #expect(metadata.isCollection)
        #expect(metadata.fileSize > 0)

        // All faces should have valid metadata
        for face in metadata.faces {
            #expect(!face.postScriptName.isEmpty)
            #expect(!face.familyName.isEmpty)
            #expect(!face.displayName.isEmpty)
            #expect(face.glyphCount > 0)
        }
    }

    @Test func ttcFacesHaveDistinctPostScriptNames() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        let psNames = Set(metadata.faces.map(\.postScriptName))
        #expect(psNames.count == metadata.faces.count, "Each face should have a unique PostScript name")
    }

    // MARK: - Variable Font

    @Test func readVariableFont() throws {
        // SFNS (San Francisco) is a variable font on modern macOS
        let url = URL(fileURLWithPath: "/System/Library/Fonts/SFNS.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(!metadata.faces.isEmpty)

        let variableFaces = metadata.faces.filter(\.isVariable)
        #expect(!variableFaces.isEmpty, "SFNS should contain at least one variable face")

        let variableFace = try #require(variableFaces.first)
        #expect(!variableFace.variationAxes.isEmpty)

        // Variable fonts typically have a Weight axis
        let weightAxis = variableFace.variationAxes.first { $0.name == "Weight" }
        if let weight = weightAxis {
            #expect(weight.minValue < weight.maxValue)
            #expect(weight.defaultValue >= weight.minValue)
            #expect(weight.defaultValue <= weight.maxValue)
        }
    }

    @Test func variationAxisValuesAreConsistent() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/SFNS.ttf")
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

    @Test func nonVariableFontHasNoAxes() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        let face = try #require(metadata.faces.first)
        #expect(!face.isVariable)
        #expect(face.variationAxes.isEmpty)
    }

    // MARK: - Error Handling

    @Test func fileNotFoundThrows() {
        let url = URL(fileURLWithPath: "/nonexistent/path/to/font.ttf")
        #expect(throws: FontMetadataReader.ReadError.fileNotFound(url)) {
            try FontMetadataReader.readMetadata(from: url)
        }
    }

    @Test func nonFontFileThrowsUnreadable() throws {
        // Use a known non-font file
        let url = URL(fileURLWithPath: "/etc/hosts")
        #expect {
            try FontMetadataReader.readMetadata(from: url)
        } throws: { error in
            guard let readError = error as? FontMetadataReader.ReadError else { return false }
            return readError == .unreadableFont(url)
        }
    }

    // MARK: - Multiple Font Formats

    @Test func readCourierTTC() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Courier.ttc")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(metadata.isCollection)
        #expect(metadata.faces.count > 1)

        let familyNames = Set(metadata.faces.map(\.familyName))
        #expect(familyNames.contains("Courier"))
    }

    @Test func readMenloTTC() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Menlo.ttc")
        let metadata = try FontMetadataReader.readMetadata(from: url)

        #expect(metadata.isCollection)

        let hasRegular = metadata.faces.contains { $0.styleName == "Regular" }
        #expect(hasRegular, "Menlo should have a Regular style")
    }

    // MARK: - Metadata Completeness

    @Test func allFacesHaveRequiredFields() throws {
        let urls = [
            URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf"),
            URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc"),
            URL(fileURLWithPath: "/System/Library/Fonts/SFNS.ttf"),
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
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)
        #expect(metadata.fileSize > 0)
    }

    @Test func fileURLIsPreserved() throws {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf")
        let metadata = try FontMetadataReader.readMetadata(from: url)
        #expect(metadata.fileURL == url)
    }
}
