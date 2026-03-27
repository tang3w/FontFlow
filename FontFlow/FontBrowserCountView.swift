//
//  FontBrowserCountView.swift
//  FontFlow
//
//  Created on 2026/3/27.
//

import Cocoa

final class FontBrowserCountView: NSView {

    private enum LayoutMetrics {
        static let stackSpacing: CGFloat = 8
        static let familyFontSize: CGFloat = 22
        static let typefaceFontSize: CGFloat = 13
    }

    private let stackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .lastBaseline
        stackView.spacing = LayoutMetrics.stackSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stackView
    }()

    private let familyCountLabel: NSTextField = {
        let label = NSTextField(labelWithString: "0 families")
        label.font = .systemFont(ofSize: LayoutMetrics.familyFontSize, weight: .semibold)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let typefaceCountLabel: NSTextField = {
        let label = NSTextField(labelWithString: "0 typefaces")
        label.font = .systemFont(ofSize: LayoutMetrics.typefaceFontSize, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        addSubview(stackView)
        stackView.addArrangedSubview(familyCountLabel)
        stackView.addArrangedSubview(typefaceCountLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        stackView.fittingSize
    }

    func update(familyCount: Int, typefaceCount: Int) {
        familyCountLabel.stringValue = Self.familyCountString(for: familyCount)
        typefaceCountLabel.stringValue = Self.typefaceCountString(for: typefaceCount)
        invalidateIntrinsicContentSize()
    }

    private static func familyCountString(for count: Int) -> String {
        "\(count) \(count == 1 ? "family" : "families")"
    }

    private static func typefaceCountString(for count: Int) -> String {
        "\(count) \(count == 1 ? "typeface" : "typefaces")"
    }
}
