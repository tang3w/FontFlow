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
    static let estimatedHeight: CGFloat = 54
    static let contentInsets = NSEdgeInsets(top: 10, left: 10, bottom: 0, right: 10)

    var onToggle: (() -> Void)?

    private let backgroundEffectView: NSVisualEffectView = {
        let effectView = NSVisualEffectView()
        effectView.material = .headerView
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 15
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.borderWidth = 1
        return effectView
    }()

    private let disclosureButton: NSButton = {
        let button = NSButton(title: "", target: nil, action: nil)
        button.bezelStyle = .circular
        button.imagePosition = .imageOnly
        button.isBordered = true
        button.controlSize = .small
        button.contentTintColor = .secondaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityIdentifier("font-section-disclosure-button")
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .headerTextColor
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
        backgroundEffectView.addSubview(disclosureButton)

        disclosureButton.target = self
        disclosureButton.action = #selector(handleDisclosureButtonPress(_:))

        let contentInsets = Self.contentInsets

        NSLayoutConstraint.activate([
            backgroundEffectView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            backgroundEffectView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            backgroundEffectView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            backgroundEffectView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom),

            nameLabel.leadingAnchor.constraint(equalTo: backgroundEffectView.leadingAnchor, constant: contentInsets.left + 8),
            nameLabel.topAnchor.constraint(equalTo: backgroundEffectView.topAnchor, constant: contentInsets.top - 5),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: disclosureButton.leadingAnchor, constant: -(contentInsets.left + 2)),

            countLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            countLabel.bottomAnchor.constraint(equalTo: backgroundEffectView.bottomAnchor, constant: -(contentInsets.top - 5)),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: disclosureButton.leadingAnchor, constant: -(contentInsets.left + 2)),

            disclosureButton.trailingAnchor.constraint(equalTo: backgroundEffectView.trailingAnchor, constant: -(contentInsets.right + 2)),
            disclosureButton.centerYAnchor.constraint(equalTo: backgroundEffectView.centerYAnchor),
            disclosureButton.widthAnchor.constraint(equalToConstant: 22),
            disclosureButton.heightAnchor.constraint(equalTo: disclosureButton.widthAnchor),
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
        countLabel.stringValue = "\(count) " + (count == 1 ? "typeface" : "typefaces")
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

    @objc private func handleDisclosureButtonPress(_ sender: NSButton) {
        onToggle?()
    }

    private func updateChevron(collapsed: Bool) {
        let symbolName = collapsed ? "chevron.right" : "chevron.down"
        let actionLabel = collapsed ? "Expand section" : "Collapse section"
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: actionLabel)!
            .withSymbolConfiguration(config)!
        disclosureButton.image = image
        disclosureButton.toolTip = actionLabel
        disclosureButton.setAccessibilityLabel(actionLabel)
    }
}
