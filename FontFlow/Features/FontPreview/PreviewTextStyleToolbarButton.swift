//
//  PreviewTextStyleToolbarButton.swift
//  FontFlow
//
//  Created on 2026/3/27.
//

import Cocoa

final class PreviewTextStyleToolbarButton: NSButton {

    var onPress: ((PreviewTextStyleToolbarButton) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let image = NSImage(
            systemSymbolName: "slider.horizontal.3",
            accessibilityDescription: "Preview Text Style"
        )

        self.image = image
        self.imagePosition = .imageOnly
        self.isBordered = true
        self.bezelStyle = .texturedRounded
        self.controlSize = .small
        self.toolTip = "Adjust preview text style"
        self.translatesAutoresizingMaskIntoConstraints = false
        self.target = self
        self.action = #selector(handlePress(_:))

        setAccessibilityIdentifier("preview-text-style-toolbar-button")
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func handlePress(_ sender: Any?) {
        onPress?(self)
    }
}
