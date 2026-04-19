//
//  FontListSectionCellView.swift
//  FontFlow
//
//  Created on 2026/3/29.
//

import Cocoa

final class FontListSectionCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("FontListSectionCellView")

    private enum LayoutMetrics {
        static let leadingInset: CGFloat = 0
        static let trailingInset: CGFloat = 4
        static let interItemSpacing: CGFloat = 4
        static let verticalInset: CGFloat = 4
        static let disclosureButtonWidth: CGFloat = 16
        static let iconWidth: CGFloat = 18
    }

    var onToggle: (() -> Void)?

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let disclosureButton: NSButton = {
        let button = NSButton(image: NSImage(), target: nil, action: nil)
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityIdentifier("font-list-section-disclosure-button")
        return button
    }()

    private let iconView: NSImageView = {
        let imageView = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        imageView.image = NSImage(
            systemSymbolName: "square.stack.3d.down.forward.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let countLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(disclosureButton)
        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(countLabel)

        textField = nameLabel

        disclosureButton.target = self
        disclosureButton.action = #selector(handleDisclosureButtonPress(_:))

        NSLayoutConstraint.activate([
            disclosureButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayoutMetrics.leadingInset),
            disclosureButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            disclosureButton.widthAnchor.constraint(equalToConstant: LayoutMetrics.disclosureButtonWidth),
            disclosureButton.heightAnchor.constraint(equalTo: heightAnchor),

            iconView.leadingAnchor.constraint(equalTo: disclosureButton.trailingAnchor, constant: LayoutMetrics.interItemSpacing),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: LayoutMetrics.iconWidth),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: LayoutMetrics.interItemSpacing),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: LayoutMetrics.verticalInset),
            bottomAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: LayoutMetrics.verticalInset),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -LayoutMetrics.interItemSpacing),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LayoutMetrics.trailingInset),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(familyName: String, count: Int, isCollapsed: Bool, onToggle: @escaping () -> Void) {
        nameLabel.stringValue = familyName
        countLabel.stringValue = "\(count)"
        countLabel.toolTip = "\(count) \(count == 1 ? "typeface" : "typefaces")"
        self.onToggle = onToggle
        updateDisclosureButton(collapsed: isCollapsed)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        countLabel.stringValue = ""
        countLabel.toolTip = nil
        onToggle = nil
        updateDisclosureButton(collapsed: false)
    }

    override func mouseDown(with event: NSEvent) {
        // Consume the event so section rows behave like headers rather than selectable items.
    }

    @objc private func handleDisclosureButtonPress(_ sender: NSButton) {
        onToggle?()
    }

    private func updateDisclosureButton(collapsed: Bool) {
        let symbolName = collapsed ? "chevron.right" : "chevron.down"
        let actionLabel = collapsed ? "Expand section" : "Collapse section"
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        disclosureButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: actionLabel)?
            .withSymbolConfiguration(config)
        disclosureButton.toolTip = actionLabel
        disclosureButton.setAccessibilityLabel(actionLabel)
    }
}
