//
//  FontGridContentView.swift
//  FontFlow
//
//  Created on 2026/3/26.
//

import Cocoa

final class FontGridContentView: NSView, NSCollectionViewElement {

    struct Content {
        let displayName: String
        let previewText: String
        let previewFont: NSFont
    }

    private enum LayoutMetrics {
        static let previewFontSize: CGFloat = 48
        static let previewCardTopInset: CGFloat = 10
        static let nameLabelTopSpacing: CGFloat = 8
        static let bottomInset: CGFloat = 5
        static let previewLabelHorizontalInset: CGFloat = 8
    }

    private final class PreviewCardView: NSView {
        var isHighlighted = false {
            didSet {
                needsDisplay = true
            }
        }

        override var isFlipped: Bool {
            true
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 10
            layer?.cornerCurve = .continuous
            layer?.borderWidth = 1
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsDisplay = true
        }

        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            guard let layer else { return }

            if isHighlighted {
                layer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor
                layer.borderColor = NSColor.controlAccentColor.cgColor
                layer.borderWidth = 2
            } else {
                layer.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.06).cgColor
                layer.borderColor = NSColor.separatorColor.cgColor
                layer.borderWidth = 1
            }
        }
    }

    private static let sizingView = FontGridContentView(isSizingView: true)

    private let previewCardView: PreviewCardView = {
        let view = PreviewCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let previewLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: LayoutMetrics.previewFontSize)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.cell?.wraps = true
        label.cell?.usesSingleLineMode = false
        return label
    }()

    private var content: Content?
    private var cachedPreferredNameLabelWidth: CGFloat = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = true
        configureViewHierarchy()
    }

    private init(isSizingView: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = !isSizingView
        configureViewHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        updateNameLabelPreferredMaxLayoutWidth(for: bounds.width)
    }

    func configure(with content: Content, availableWidth: CGFloat? = nil) {
        self.content = content
        previewLabel.stringValue = content.previewText
        previewLabel.font = content.previewFont
        nameLabel.stringValue = content.displayName
        updateNameLabelPreferredMaxLayoutWidth(for: availableWidth)
    }

    func setSelected(_ isSelected: Bool) {
        previewCardView.isHighlighted = isSelected
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        content = nil
        previewLabel.stringValue = ""
        previewLabel.font = .systemFont(ofSize: LayoutMetrics.previewFontSize)
        nameLabel.stringValue = ""
        nameLabel.preferredMaxLayoutWidth = 0
        cachedPreferredNameLabelWidth = -1
        setSelected(false)
    }

    // Layout strategy:
    // - This view is the real root view for each visible FontGridItem.
    // - The collection layout uses estimated heights, then asks the element for
    //   preferred layout attributes at the resolved item width.
    // - Instead of mutating the on-screen view during that layout pass, we reuse
    //   a detached FontGridContentView instance to measure the fitted height.
    // - The detached view is configured with the same content and width, and the
    //   name label's preferredMaxLayoutWidth is kept in sync so multiline names
    //   wrap exactly as they do in the visible item.
    func preferredLayoutAttributesFitting(
        _ layoutAttributes: NSCollectionViewLayoutAttributes
    ) -> NSCollectionViewLayoutAttributes {
        let fittedAttributes = layoutAttributes.copy() as! NSCollectionViewLayoutAttributes
        guard let content else {
            return fittedAttributes
        }

        let targetWidth = max(layoutAttributes.size.width, layoutAttributes.frame.width)
        guard targetWidth > 0 else {
            return fittedAttributes
        }

        var frame = fittedAttributes.frame
        frame.size.height = ceil(Self.sizingView.measureHeight(with: content, width: targetWidth))
        fittedAttributes.frame = frame

        return fittedAttributes
    }

    private func configureViewHierarchy() {
        addSubview(previewCardView)
        previewCardView.addSubview(previewLabel)
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            previewCardView.topAnchor.constraint(equalTo: topAnchor, constant: LayoutMetrics.previewCardTopInset),
            previewCardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            previewCardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            previewCardView.heightAnchor.constraint(equalTo: previewCardView.widthAnchor),

            previewLabel.centerXAnchor.constraint(equalTo: previewCardView.centerXAnchor),
            previewLabel.centerYAnchor.constraint(equalTo: previewCardView.centerYAnchor),
            previewLabel.leadingAnchor.constraint(greaterThanOrEqualTo: previewCardView.leadingAnchor, constant: LayoutMetrics.previewLabelHorizontalInset),
            previewLabel.trailingAnchor.constraint(lessThanOrEqualTo: previewCardView.trailingAnchor, constant: -LayoutMetrics.previewLabelHorizontalInset),

            nameLabel.topAnchor.constraint(equalTo: previewCardView.bottomAnchor, constant: LayoutMetrics.nameLabelTopSpacing),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -LayoutMetrics.bottomInset),
        ])
    }

    private func measureHeight(with content: Content, width: CGFloat) -> CGFloat {
        configure(with: content, availableWidth: width)

        if abs(frame.width - width) > 0.5 {
            setFrameSize(NSSize(width: width, height: frame.height))
        }

        let widthConstraint = widthAnchor.constraint(equalToConstant: width)
        widthConstraint.isActive = true
        defer {
            widthConstraint.isActive = false
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
        return fittingSize.height
    }

    private func updateNameLabelPreferredMaxLayoutWidth(for availableWidth: CGFloat?) {
        guard let availableWidth, availableWidth > 0 else {
            return
        }

        let preferredWidth = max(availableWidth, 0)
        guard abs(preferredWidth - cachedPreferredNameLabelWidth) > 0.5 else {
            return
        }

        cachedPreferredNameLabelWidth = preferredWidth
        nameLabel.preferredMaxLayoutWidth = preferredWidth
        nameLabel.invalidateIntrinsicContentSize()
    }
}
