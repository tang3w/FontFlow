//
//  FontGridItem.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

class FontGridItem: NSCollectionViewItem {

    private final class PreviewCardView: NSView {
        var isHighlighted = false {
            didSet {
                needsDisplay = true
            }
        }

        override var isFlipped: Bool {
            true
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)

            if isHighlighted {
                NSColor.controlAccentColor.withAlphaComponent(0.10).setFill()
                path.fill()

                NSColor.controlAccentColor.setStroke()
                path.lineWidth = 2
                path.stroke()
            } else {
                NSColor.quaternaryLabelColor.withAlphaComponent(0.06).setFill()
                path.fill()

                NSColor.separatorColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        }
    }

    static let identifier = NSUserInterfaceItemIdentifier("FontGridItem")

    private let previewCardView: PreviewCardView = {
        let view = PreviewCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let previewLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 36)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.cell?.wraps = true
        label.cell?.usesSingleLineMode = false
        return label
    }()

    override func loadView() {
        let root = NSView()
        view = root

        view.addSubview(previewCardView)
        previewCardView.addSubview(previewLabel)
        view.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            previewCardView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            previewCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            previewCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            previewCardView.heightAnchor.constraint(equalTo: previewCardView.widthAnchor),

            previewLabel.centerXAnchor.constraint(equalTo: previewCardView.centerXAnchor),
            previewLabel.centerYAnchor.constraint(equalTo: previewCardView.centerYAnchor),
            previewLabel.leadingAnchor.constraint(greaterThanOrEqualTo: previewCardView.leadingAnchor, constant: 8),
            previewLabel.trailingAnchor.constraint(lessThanOrEqualTo: previewCardView.trailingAnchor, constant: -8),

            nameLabel.topAnchor.constraint(equalTo: previewCardView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -4),
        ])

        updateSelectionHighlight()
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionHighlight()
        }
    }

    func configure(with record: FontRecord) {
        let displayName = record.styleName ?? record.displayName ?? record.postScriptName ?? "Unknown"
        nameLabel.stringValue = displayName
        previewLabel.stringValue = "Aa"

        if let psName = record.postScriptName,
           let font = NSFont(name: psName, size: 36) {
            previewLabel.font = font
        } else {
            previewLabel.font = .systemFont(ofSize: 36)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewLabel.stringValue = ""
        previewLabel.font = .systemFont(ofSize: 36)
        nameLabel.stringValue = ""
        updateSelectionHighlight()
    }

    private func updateSelectionHighlight() {
        previewCardView.isHighlighted = isSelected
    }
}
