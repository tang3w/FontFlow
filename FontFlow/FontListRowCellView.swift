//
//  FontListRowCellView.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

final class FontListRowCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("FontListRowCellView")

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(nameLabel)
        textField = nameLabel

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with record: FontRecord) {
        nameLabel.stringValue = record.styleName ?? record.displayName ?? record.postScriptName ?? "Unknown"
    }
}
