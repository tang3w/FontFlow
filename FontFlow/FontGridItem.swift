//
//  FontGridItem.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

class FontGridItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("FontGridItem")

    private let previewLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 24)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 3
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
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.cornerRadius = 8
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor.separatorColor.cgColor
        view = root

        view.addSubview(previewLabel)
        view.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            previewLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            previewLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            previewLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            previewLabel.bottomAnchor.constraint(lessThanOrEqualTo: nameLabel.topAnchor, constant: -8),

            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionHighlight()
        }
    }

    func configure(with record: FontRecord) {
        let displayName = record.displayName ?? record.postScriptName ?? "Unknown"
        nameLabel.stringValue = displayName
        previewLabel.stringValue = displayName

        if let psName = record.postScriptName,
           let font = NSFont(name: psName, size: 24) {
            previewLabel.font = font
        } else {
            previewLabel.font = .systemFont(ofSize: 24)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewLabel.stringValue = ""
        previewLabel.font = .systemFont(ofSize: 24)
        nameLabel.stringValue = ""
        view.layer?.borderColor = NSColor.separatorColor.cgColor
        view.layer?.borderWidth = 1
    }

    private func updateSelectionHighlight() {
        if isSelected {
            view.layer?.borderColor = NSColor.controlAccentColor.cgColor
            view.layer?.borderWidth = 2
        } else {
            view.layer?.borderColor = NSColor.separatorColor.cgColor
            view.layer?.borderWidth = 1
        }
    }
}
