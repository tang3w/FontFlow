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
        static let leadingInset: CGFloat = 4
        static let trailingInset: CGFloat = 4
        static let interItemSpacing: CGFloat = 8
        static let verticalInset: CGFloat = 10
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
        let button = NSButton(title: "0", target: nil, action: nil)
        button.bezelStyle = .circular
        button.showsBorderOnlyWhileMouseInside = true
        button.imagePosition = .imageTrailing
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityIdentifier("font-list-section-disclosure-button")
        return button
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(nameLabel)
        addSubview(disclosureButton)

        disclosureButton.target = self
        disclosureButton.action = #selector(handleDisclosureButtonPress(_:))

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayoutMetrics.leadingInset),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: LayoutMetrics.verticalInset),
            bottomAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: LayoutMetrics.verticalInset),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: disclosureButton.leadingAnchor, constant: -LayoutMetrics.interItemSpacing),

            disclosureButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LayoutMetrics.trailingInset),
            disclosureButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(familyName: String, count: Int, isCollapsed: Bool, onToggle: @escaping () -> Void) {
        nameLabel.stringValue = familyName
        self.onToggle = onToggle
        updateDisclosureButton(count: count, collapsed: isCollapsed)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        onToggle = nil
        updateDisclosureButton(count: 0, collapsed: false)
    }

    override func mouseDown(with event: NSEvent) {
        // Consume the event so section rows behave like headers rather than selectable items.
    }

    @objc private func handleDisclosureButtonPress(_ sender: NSButton) {
        onToggle?()
    }

    private static func badgeTitle(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    private func updateDisclosureButton(count: Int, collapsed: Bool) {
        disclosureButton.attributedTitle = Self.badgeTitle("\(count)")

        let symbolName = collapsed ? "chevron.down" : "chevron.up"
        let actionLabel = collapsed ? "Expand section" : "Collapse section"
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .secondaryLabelColor)
        let config = sizeConfig.applying(colorConfig)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: actionLabel)?
            .withSymbolConfiguration(config)
        disclosureButton.image = image
        disclosureButton.toolTip = actionLabel
        disclosureButton.setAccessibilityLabel(actionLabel)
    }
}
