//
//  FontGridItem.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

class FontGridItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("FontGridItem")

    private let previewCardView: NSView = {
        let view = NSView()
        view.wantsLayer = true
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
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
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
        let displayName = record.displayName ?? record.styleName ?? record.postScriptName ?? "Unknown"
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
        previewCardView.layer?.cornerRadius = 10
        if isSelected {
            previewCardView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor
            previewCardView.layer?.borderColor = NSColor.controlAccentColor.cgColor
            previewCardView.layer?.borderWidth = 2
        } else {
            previewCardView.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.06).cgColor
            previewCardView.layer?.borderColor = NSColor.separatorColor.cgColor
            previewCardView.layer?.borderWidth = 1
        }
    }
}
