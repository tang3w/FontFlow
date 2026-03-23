//
//  FontListItem.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

class FontListItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("FontListItem")

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15)
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
        view = root

        view.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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

        if let font = FontLoader.font(for: record, size: 15) {
            nameLabel.font = font
        } else {
            nameLabel.font = .systemFont(ofSize: 15)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        nameLabel.font = .systemFont(ofSize: 15)
    }

    private func updateSelectionHighlight() {
        view.layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            : nil
    }
}
