//
//  FontSectionHeaderView.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

class FontSectionHeaderView: NSView, NSCollectionViewElement {

    static let elementKind = "SectionHeader"
    static let identifier = NSUserInterfaceItemIdentifier("FontSectionHeader")

    var onToggle: (() -> Void)?

    private let chevronImageView: NSImageView = {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        let image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Disclosure")!
            .withSymbolConfiguration(config)!
        let imageView = NSImageView(image: image)
        imageView.contentTintColor = .secondaryLabelColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let countLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor

        addSubview(chevronImageView)
        addSubview(nameLabel)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            chevronImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),

            nameLabel.leadingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -8),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
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
        self.onToggle = onToggle
        updateChevron(collapsed: isCollapsed)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        countLabel.stringValue = ""
        onToggle = nil
        updateChevron(collapsed: false)
    }

    override func mouseDown(with event: NSEvent) {
        onToggle?()
    }

    private func updateChevron(collapsed: Bool) {
        let symbolName = collapsed ? "chevron.right" : "chevron.down"
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Disclosure")!
            .withSymbolConfiguration(config)!
        chevronImageView.image = image
    }
}
