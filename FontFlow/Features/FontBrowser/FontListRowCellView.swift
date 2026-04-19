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
        static let leadingInset: CGFloat = 38
        static let trailingInset: CGFloat = 4
        static let verticalInset: CGFloat = 4
        static let interItemSpacing: CGFloat = 4
        static let iconWidth: CGFloat = 18
    }

    private let iconView: NSImageView = {
        let imageView = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        imageView.image = NSImage(
            systemSymbolName: "t.square.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(iconView)
        addSubview(nameLabel)
        textField = nameLabel

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayoutMetrics.leadingInset),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: LayoutMetrics.iconWidth),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: LayoutMetrics.interItemSpacing),
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
