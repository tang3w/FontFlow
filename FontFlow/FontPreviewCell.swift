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
    private var currentTextStyle = FontPreviewTextStyle.default
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

    private let sampleBackgroundView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer?.cornerRadius = 10
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }()

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        view.addSubview(fontNameLabel)
        view.addSubview(sampleBackgroundView)
        sampleBackgroundView.addSubview(sampleLabel)

        NSLayoutConstraint.activate([
            fontNameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            fontNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            fontNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            sampleBackgroundView.topAnchor.constraint(equalTo: fontNameLabel.bottomAnchor, constant: 8),
            sampleBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sampleBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sampleBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            sampleLabel.topAnchor.constraint(equalTo: sampleBackgroundView.topAnchor, constant: 12),
            sampleLabel.leadingAnchor.constraint(equalTo: sampleBackgroundView.leadingAnchor, constant: 12),
            sampleLabel.trailingAnchor.constraint(equalTo: sampleBackgroundView.trailingAnchor, constant: -12),
            sampleLabel.bottomAnchor.constraint(equalTo: sampleBackgroundView.bottomAnchor, constant: -12),
        ])
    }

    func configure(record: FontRecord, sampleText: String, fontSize: CGFloat, textStyle: FontPreviewTextStyle, variationValues: [UInt32: Double]? = nil) {
        configure(
            record: record,
            sampleText: sampleText,
            fontSize: fontSize,
            textStyle: textStyle,
            variationValues: variationValues,
            isEditable: false
        )
    }

    func configure(record: FontRecord, sampleText: String, fontSize: CGFloat, textStyle: FontPreviewTextStyle, variationValues: [UInt32: Double]? = nil, isEditable: Bool) {
        let displayName = record.displayName ?? record.postScriptName ?? "Unknown"
        fontNameLabel.stringValue = displayName

        currentSampleText = sampleText
        currentSampleFont = loadFont(for: record, size: fontSize, variationValues: variationValues)
        currentTextStyle = textStyle
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
        currentTextStyle = .default
        isSampleEditable = false
        sampleLabel.delegate = nil
        sampleLabel.isEditable = false
        sampleLabel.isSelectable = false
        sampleBackgroundView.layer?.backgroundColor = nil
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
        sampleLabel.textColor = currentTextStyle.resolvedForegroundColor
        sampleLabel.stringValue = currentSampleText
        sampleBackgroundView.layer?.backgroundColor = currentTextStyle.backgroundColor?.cgColor

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (currentTextStyle.lineSpacingMultiplier - 1.0) * currentSampleFont.pointSize

        sampleLabel.attributedStringValue = NSAttributedString(
            string: currentSampleText,
            attributes: [
                .font: currentSampleFont,
                .foregroundColor: currentTextStyle.resolvedForegroundColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }

    private func loadFont(for record: FontRecord, size: CGFloat, variationValues: [UInt32: Double]?) -> NSFont {
        guard var resolvedFont = FontLoader.font(for: record, size: size) else {
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
