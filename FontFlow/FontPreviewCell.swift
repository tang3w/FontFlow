//
//  FontPreviewCell.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa
import CoreText

protocol FontPreviewCellDelegate: AnyObject {
    func fontPreviewCell(_ cell: FontPreviewCell, didChangeSampleText text: String)
}

/// Collection view item that renders sample text in a specific font.
class FontPreviewCell: NSCollectionViewItem, NSTextFieldDelegate {

    static let identifier = NSUserInterfaceItemIdentifier("FontPreviewCell")

    weak var delegate: FontPreviewCellDelegate?

    private var currentSampleText = ""
    private var currentSampleFont: NSFont = .systemFont(ofSize: 48)
    private var currentLineSpacing: CGFloat = 1.2
    private var isSampleEditable = false

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
        label.isSelectable = false
        label.isBordered = false
        label.isBezeled = false
        label.isEnabled = true
        label.drawsBackground = false
        label.allowsEditingTextAttributes = false
        label.maximumNumberOfLines = 0
        label.focusRingType = .none
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.translatesAutoresizingMaskIntoConstraints = false
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
            sampleLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    func configure(record: FontRecord, sampleText: String, fontSize: CGFloat, lineSpacing: CGFloat, variationValues: [UInt32: Double]? = nil) {
        configure(
            record: record,
            sampleText: sampleText,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            variationValues: variationValues,
            isEditable: false
        )
    }

    func configure(record: FontRecord, sampleText: String, fontSize: CGFloat, lineSpacing: CGFloat, variationValues: [UInt32: Double]? = nil, isEditable: Bool) {
        let displayName = record.displayName ?? record.postScriptName ?? "Unknown"
        fontNameLabel.stringValue = displayName

        currentSampleText = sampleText
        currentSampleFont = loadFont(for: record, size: fontSize, variationValues: variationValues)
        currentLineSpacing = lineSpacing
        isSampleEditable = isEditable

        renderSampleText()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        delegate = nil
        fontNameLabel.stringValue = ""
        sampleLabel.stringValue = ""
        sampleLabel.font = .systemFont(ofSize: 48)
        currentSampleText = ""
        currentSampleFont = .systemFont(ofSize: 48)
        currentLineSpacing = 1.2
        isSampleEditable = false
        sampleLabel.delegate = nil
        sampleLabel.isEditable = false
        sampleLabel.isSelectable = false
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: NSCollectionViewLayoutAttributes) -> NSCollectionViewLayoutAttributes {
        view.frame.size.width = layoutAttributes.size.width
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()

        let fittedAttributes = layoutAttributes.copy() as! NSCollectionViewLayoutAttributes
        let fittedSize = view.fittingSize
        fittedAttributes.size.height = ceil(fittedSize.height)
        return fittedAttributes
    }

    func controlTextDidChange(_ obj: Notification) {
        guard isSampleEditable else { return }
        currentSampleText = sampleLabel.stringValue
        delegate?.fontPreviewCell(self, didChangeSampleText: currentSampleText)
    }

    // MARK: - Font Loading

    private func renderSampleText() {
        sampleLabel.delegate = isSampleEditable ? self : nil
        sampleLabel.isEditable = isSampleEditable
        sampleLabel.isSelectable = isSampleEditable
        sampleLabel.font = currentSampleFont
        sampleLabel.stringValue = currentSampleText

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (currentLineSpacing - 1.0) * currentSampleFont.pointSize

        sampleLabel.attributedStringValue = NSAttributedString(
            string: currentSampleText,
            attributes: [
                .font: currentSampleFont,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }

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
