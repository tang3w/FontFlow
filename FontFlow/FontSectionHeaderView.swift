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
    static let estimatedHeight: CGFloat = 40

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
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let countLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        addSubview(nameLabel)
        addSubview(countLabel)
        addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            countLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            countLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
        ])
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(familyName: String, count: Int, isCollapsed: Bool, onToggle: @escaping () -> Void) {
        nameLabel.stringValue = familyName
        countLabel.stringValue = "\(count) styles"
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
