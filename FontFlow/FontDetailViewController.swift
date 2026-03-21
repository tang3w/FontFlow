//
//  FontDetailViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

/// Right pane of the split view. Shows basic font info when a font is selected,
/// or a placeholder message when nothing is selected. Full preview is built in M4.
class FontDetailViewController: NSViewController {

    // MARK: - Views

    private let emptyLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Select a font to preview")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let fontNameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let familyLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let styleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let filePathLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let placeholderLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Preview coming soon")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var infoStack: NSStackView = {
        let stack = NSStackView(views: [fontNameLabel, familyLabel, styleLabel, filePathLabel, placeholderLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.addSubview(emptyLabel)
        view.addSubview(infoStack)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            infoStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            infoStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])

        showEmpty()
    }

    // MARK: - Public

    func updateFont(_ font: FontRecord?) {
        guard let font = font else {
            showEmpty()
            return
        }
        showInfo(font)
    }

    // MARK: - Private

    private func showEmpty() {
        emptyLabel.isHidden = false
        infoStack.isHidden = true
    }

    private func showInfo(_ font: FontRecord) {
        emptyLabel.isHidden = true
        infoStack.isHidden = false

        fontNameLabel.stringValue = font.displayName ?? font.postScriptName ?? "Unknown"
        familyLabel.stringValue = font.familyName ?? ""
        styleLabel.stringValue = font.styleName ?? ""
        filePathLabel.stringValue = font.filePath ?? ""
    }
}
