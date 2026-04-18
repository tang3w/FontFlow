//
//  FontListRowCellView.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

final class FontListRowCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("FontListRowCellView")

    private enum LayoutMetrics {
        static let leadingInset: CGFloat = 20
        static let trailingInset: CGFloat = 4
        static let verticalInset: CGFloat = 4
    }

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
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayoutMetrics.leadingInset),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -LayoutMetrics.trailingInset),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: LayoutMetrics.verticalInset),
            bottomAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: LayoutMetrics.verticalInset),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with item: FontTypefaceItem) {
        nameLabel.stringValue = item.displayLabel
    }
}
