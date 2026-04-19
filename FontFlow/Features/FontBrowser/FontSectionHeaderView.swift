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
    static let estimatedHeight: CGFloat = 49
    static let contentInsets = NSEdgeInsets(top: 10, left: 10, bottom: 0, right: 10)

    var onToggle: (() -> Void)?
    var onSelect: ((FontFamilySelectionIntent) -> Void)?

    private(set) var selectionState: FontFamilySelectionState = .none

    private let backgroundEffectView: NSVisualEffectView = {
        let effectView = NSVisualEffectView()
        effectView.material = .headerView
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.borderWidth = 1
        return effectView
    }()

    private let disclosureButton: NSButton = {
        let button = NSButton(title: "0", target: nil, action: nil)
        button.bezelStyle = .circular
        button.showsBorderOnlyWhileMouseInside = true
        button.imagePosition = .imageTrailing
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityIdentifier("font-section-disclosure-button")
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


    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        addSubview(backgroundEffectView)
        backgroundEffectView.addSubview(nameLabel)
        backgroundEffectView.addSubview(disclosureButton)

        disclosureButton.target = self
        disclosureButton.action = #selector(handleDisclosureButtonPress(_:))

        let contentInsets = Self.contentInsets

        NSLayoutConstraint.activate([
            backgroundEffectView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            backgroundEffectView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            backgroundEffectView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            backgroundEffectView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom),

            nameLabel.leadingAnchor.constraint(equalTo: backgroundEffectView.leadingAnchor, constant: contentInsets.left),
            nameLabel.topAnchor.constraint(equalTo: backgroundEffectView.topAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: backgroundEffectView.bottomAnchor, constant: -10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: disclosureButton.leadingAnchor, constant: -10),

            disclosureButton.trailingAnchor.constraint(equalTo: backgroundEffectView.trailingAnchor, constant: -contentInsets.right),
            disclosureButton.centerYAnchor.constraint(equalTo: backgroundEffectView.centerYAnchor),
        ])

        setAccessibilityRole(.button)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer = backgroundEffectView.layer else { return }

        switch selectionState {
        case .none:
            backgroundEffectView.material = .headerView
            backgroundEffectView.isEmphasized = false
            layer.borderColor = NSColor.separatorColor.withAlphaComponent(0.1).cgColor
            layer.borderWidth = 1
        case .partial:
            backgroundEffectView.material = .headerView
            backgroundEffectView.isEmphasized = false
            layer.borderColor = NSColor.controlAccentColor.cgColor
            layer.borderWidth = 2
        case .full:
            backgroundEffectView.material = .selection
            backgroundEffectView.isEmphasized = true
            layer.borderColor = NSColor.controlAccentColor.cgColor
            layer.borderWidth = 1
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private static func badgeTitle(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    func configure(
        familyName: String,
        count: Int,
        isCollapsed: Bool,
        selectionState: FontFamilySelectionState,
        onToggle: @escaping () -> Void,
        onSelect: @escaping (FontFamilySelectionIntent) -> Void
    ) {
        nameLabel.stringValue = familyName
        self.onToggle = onToggle
        self.onSelect = onSelect
        updateSelectionState(selectionState)
        updateDisclosureButton(count: count, collapsed: isCollapsed)
        setAccessibilityLabel("Select family \(familyName)")
    }

    func updateSelectionState(_ newState: FontFamilySelectionState) {
        guard newState != selectionState else { return }
        selectionState = newState
        needsDisplay = true
        backgroundEffectView.needsDisplay = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        onToggle = nil
        onSelect = nil
        updateSelectionState(.none)
        updateDisclosureButton(count: 0, collapsed: false)
    }

    override func mouseDown(with event: NSEvent) {
        // The disclosure NSButton consumes its own mouse events, so clicks that
        // reach this method are anywhere on the header except the button.
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let intent: FontFamilySelectionIntent = (modifiers.contains(.command) || modifiers.contains(.shift))
            ? .toggleAdditive
            : .select
        onSelect?(intent)
    }

    @objc private func handleDisclosureButtonPress(_ sender: NSButton) {
        onToggle?()
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
