//
//  FontListSectionCellView.swift
//  FontFlow
//
//  Created on 2026/3/29.
//

import Cocoa

final class FontListSectionCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("FontListSectionCellView")

    var onToggle: (() -> Void)?

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
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(nameLabel)
        addSubview(countLabel)
        textField = nameLabel

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -8),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(familyName: String, count: Int, onToggle: @escaping () -> Void) {
        nameLabel.stringValue = familyName
        countLabel.stringValue = String(count)
        countLabel.toolTip = count == 1 ? "1 typeface" : "\(count) typefaces"
        self.onToggle = onToggle
    }

    override func mouseDown(with event: NSEvent) {
        // Consume the event so section rows behave like headers rather than selectable items.
    }

    override func mouseUp(with event: NSEvent) {
        guard event.clickCount == 1 else { return }

        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }

        onToggle?()
    }
}
