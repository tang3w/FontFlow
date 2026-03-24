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
    static let estimatedHeight: CGFloat = 44

    var onToggle: (() -> Void)?

    private let backgroundEffectView: NSVisualEffectView = {
        let effectView = NSVisualEffectView()
        effectView.material = .headerView
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.borderWidth = 1
        return effectView
    }()

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
        label.font = .systemFont(ofSize: 15, weight: .semibold)
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

        addSubview(backgroundEffectView)
        backgroundEffectView.addSubview(nameLabel)
        backgroundEffectView.addSubview(countLabel)
        backgroundEffectView.addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            backgroundEffectView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            backgroundEffectView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            backgroundEffectView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            backgroundEffectView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            nameLabel.leadingAnchor.constraint(equalTo: backgroundEffectView.leadingAnchor, constant: 14),
            nameLabel.topAnchor.constraint(equalTo: backgroundEffectView.topAnchor, constant: 7),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            countLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            countLabel.bottomAnchor.constraint(equalTo: backgroundEffectView.bottomAnchor, constant: -7),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            chevronImageView.trailingAnchor.constraint(equalTo: backgroundEffectView.trailingAnchor, constant: -14),
            chevronImageView.centerYAnchor.constraint(equalTo: backgroundEffectView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
        ])
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        backgroundEffectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.1).cgColor
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
        // Consume the event to prevent NSCollectionView default behavior
        // but do not trigger the toggle yet to prevent layout shifting mid-click.
    }

    override func mouseUp(with event: NSEvent) {
        // Ignore double clicks to prevent accidental double-toggling
        guard event.clickCount == 1 else { return }

        // Ensure the user released the mouse inside the header
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            onToggle?()
        }
    }

    private func updateChevron(collapsed: Bool) {
        let symbolName = collapsed ? "chevron.right" : "chevron.down"
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Disclosure")!
            .withSymbolConfiguration(config)!
        chevronImageView.image = image
    }
}
