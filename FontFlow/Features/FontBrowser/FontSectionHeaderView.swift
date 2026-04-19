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
    private var cachedCount: Int = 0
    private var cachedCollapsed: Bool = false

    private let contentView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.cornerCurve = .continuous
        view.layer?.borderWidth = 1
        return view
    }()

    private let disclosureButton: NSButton = {
        let button = NSButton(title: "0", target: nil, action: nil)
        // Swap in a cell that honors the attributed title's foreground color;
        // the default NSButtonCell for .circular bezels overrides it with the
        // system control text color.
        button.cell = AttributedTitleButtonCell(textCell: "0")
        button.bezelStyle = .circular
        button.showsBorderOnlyWhileMouseInside = true
        button.imagePosition = .imageTrailing
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityIdentifier("font-section-disclosure-button")
        return button
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .headerTextColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()


    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        addSubview(contentView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(disclosureButton)

        disclosureButton.target = self
        disclosureButton.action = #selector(handleDisclosureButtonPress(_:))

        let contentInsets = Self.contentInsets

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom),

            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentInsets.left),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: disclosureButton.leadingAnchor, constant: -10),

            disclosureButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentInsets.right),
            disclosureButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        setAccessibilityRole(.button)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer = contentView.layer else { return }

        switch selectionState {
        case .none:
            layer.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer.borderColor = NSColor.separatorColor.cgColor
            layer.borderWidth = 1
        case .partial:
            layer.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer.borderColor = NSColor.controlAccentColor.cgColor
            layer.borderWidth = 2
        case .full:
            // Match the standard NSOutlineView (.inset style) selected-row look:
            // a solid, opaque accent fill with no vibrancy and no border.
            layer.backgroundColor = NSColor.controlAccentColor.cgColor
            layer.borderColor = NSColor.clear.cgColor
            layer.borderWidth = 0
        }

        applyForegroundAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private static func badgeTitle(_ string: String, foregroundColor: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: foregroundColor
        ])
    }

    private var foregroundTintColor: NSColor {
        selectionState == .full ? .alternateSelectedControlTextColor : .headerTextColor
    }

    private var secondaryForegroundTintColor: NSColor {
        selectionState == .full ? .alternateSelectedControlTextColor : .secondaryLabelColor
    }

    private func applyForegroundAppearance() {
        nameLabel.textColor = foregroundTintColor
        updateDisclosureBadge()
        updateDisclosureChevron(collapsed: cachedCollapsed)
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
        cachedCount = count
        cachedCollapsed = isCollapsed
        updateSelectionState(selectionState)
        updateDisclosureBadge()
        updateDisclosureChevron(collapsed: isCollapsed)
        // Ensure foreground colors reflect the (possibly unchanged) selection state.
        applyForegroundAppearance()
        setAccessibilityLabel("Select family \(familyName)")
    }

    func updateSelectionState(_ newState: FontFamilySelectionState) {
        guard newState != selectionState else { return }
        selectionState = newState
        needsDisplay = true
        contentView.needsDisplay = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        onToggle = nil
        onSelect = nil
        cachedCount = 0
        cachedCollapsed = false
        updateSelectionState(.none)
        updateDisclosureBadge()
        updateDisclosureChevron(collapsed: false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only claim hits that land within the visible content view. Points in
        // the surrounding insets fall through to the collection view so the
        // user can start a marquee drag-to-select gesture there.
        let pointInContent = contentView.convert(point, from: superview)
        guard contentView.bounds.contains(pointInContent) else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        // Intentionally a no-op. Selection is committed in mouseUp so the
        // gesture matches NSCollectionViewItem's default click-to-select
        // behavior. We still override mouseDown so AppKit routes the
        // matching mouseUp back to this view, and so a future drag handler
        // can take over from here without conflicting with selection.
    }

    override func mouseUp(with event: NSEvent) {
        // Only fire when the click ends inside the content view; pressing
        // and dragging away cancels the selection (and leaves the gesture
        // free for a future drag implementation).
        let locationInContent = contentView.convert(event.locationInWindow, from: nil)
        guard contentView.bounds.contains(locationInContent) else { return }

        // The disclosure NSButton consumes its own mouse events, so clicks
        // that reach this method are anywhere on the header except the button.
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let intent: FontFamilySelectionIntent = (modifiers.contains(.command) || modifiers.contains(.shift))
            ? .toggleAdditive
            : .select
        onSelect?(intent)
    }

    @objc private func handleDisclosureButtonPress(_ sender: NSButton) {
        onToggle?()
    }

    private func updateDisclosureBadge() {
        disclosureButton.attributedTitle = Self.badgeTitle(
            "\(cachedCount)",
            foregroundColor: secondaryForegroundTintColor
        )
    }

    private func updateDisclosureChevron(collapsed: Bool) {
        let symbolName = collapsed ? "chevron.down" : "chevron.up"
        let actionLabel = collapsed ? "Expand section" : "Collapse section"
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: secondaryForegroundTintColor)
        let config = sizeConfig.applying(colorConfig)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: actionLabel)?
            .withSymbolConfiguration(config)
        disclosureButton.image = image
        disclosureButton.toolTip = actionLabel
        disclosureButton.setAccessibilityLabel(actionLabel)
    }
}

/// `NSButtonCell` subclass that draws `attributedTitle` verbatim instead of
/// letting the default cell re-color the title with the system control text
/// color. This is required so the section header's count badge can adopt
/// `alternateSelectedControlTextColor` when the header is fully selected.
private final class AttributedTitleButtonCell: NSButtonCell {
    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        let bounding = title.boundingRect(
            with: frame.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let drawRect = NSRect(
            x: frame.midX - bounding.width / 2,
            y: frame.midY - bounding.height / 2,
            width: bounding.width,
            height: bounding.height
        )
        title.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        return drawRect
    }
}
