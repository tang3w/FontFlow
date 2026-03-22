//
//  FontPreviewCell.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreText

/// Collection view item that renders sample text in a specific font.
class FontPreviewCell: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("FontPreviewCell")

    private let fontNameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let sampleLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: 48)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        view = root

        view.addSubview(fontNameLabel)
        view.addSubview(sampleLabel)

        NSLayoutConstraint.activate([
            fontNameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            fontNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            fontNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            sampleLabel.topAnchor.constraint(equalTo: fontNameLabel.bottomAnchor, constant: 8),
            sampleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sampleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sampleLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12),
        ])
    }

    func configure(record: FontRecord, sampleText: String, fontSize: CGFloat, lineSpacing: CGFloat, variationValues: [UInt32: Double]? = nil) {
        let displayName = record.displayName ?? record.postScriptName ?? "Unknown"
        fontNameLabel.stringValue = displayName

        sampleLabel.stringValue = sampleText

        let font = loadFont(for: record, size: fontSize, variationValues: variationValues)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (lineSpacing - 1.0) * fontSize
        let attributed = NSAttributedString(
            string: sampleText,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ]
        )
        sampleLabel.attributedStringValue = attributed
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        fontNameLabel.stringValue = ""
        sampleLabel.stringValue = ""
        sampleLabel.font = .systemFont(ofSize: 48)
    }

    // MARK: - Font Loading

    private func loadFont(for record: FontRecord, size: CGFloat, variationValues: [UInt32: Double]?) -> NSFont {
        var font: NSFont?

        // Try by PostScript name first
        if let psName = record.postScriptName {
            font = NSFont(name: psName, size: size)
        }

        // Fallback: create from file URL via CoreText
        if font == nil, let filePath = record.filePath {
            let url = URL(fileURLWithPath: filePath)
            if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
               let descriptor = descriptors.first {
                font = CTFontCreateWithFontDescriptor(descriptor, size, nil) as NSFont
            }
        }

        guard var resolvedFont = font else {
            return .systemFont(ofSize: size)
        }

        // Apply variation values if provided
        if let variations = variationValues, !variations.isEmpty {
            let variationDict = variations as NSDictionary
            let attrs = [kCTFontVariationAttribute: variationDict] as CFDictionary
            if let varDescriptor = CTFontDescriptorCreateWithAttributes(attrs) as CTFontDescriptor? {
                let varFont = CTFontCreateCopyWithAttributes(resolvedFont, size, nil, varDescriptor)
                resolvedFont = varFont as NSFont
            }
        }

        return resolvedFont
    }
}
