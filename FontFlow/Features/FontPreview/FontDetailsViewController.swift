//
//  FontDetailsViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

/// Right pane of the split view. Hosts font preview and controls.
class FontDetailsViewController: NSViewController {

    // MARK: - Child VC

    private let previewController = FontPreviewController()
    private let previewTextStylePopover = NSPopover()
    private let previewTextStylePopoverViewController = PreviewTextStylePopoverViewController()

    // MARK: - Empty State

    private let emptyLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Select fonts to preview")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Content Container

    private let contentContainer: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let regionSpacing: CGFloat = 8
    private let previewMinHeight: CGFloat = 120

    private let scriptPopUp: NSPopUpButton = {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.translatesAutoresizingMaskIntoConstraints = false
        for sample in ScriptSamples.all {
            button.addItem(withTitle: sample.name)
        }
        button.selectItem(at: 0)
        return button
    }()

    private let fontSizeToolbarControl = FontSizeToolbarControl()
    private let previewTextStyleToolbarButton = PreviewTextStyleToolbarButton()

    // MARK: - State

    private var currentFonts: [FontRecord] = []
    private var currentPreviewTextStyle = FontPreviewTextStyle.default

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.addSubview(emptyLabel)
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        setupPreviewController()
        setupPreviewTextStylePopover()
        setupActions()

        showEmpty()
    }

    // MARK: - Setup

    private func setupPreviewController() {
        addChild(previewController)
        let previewView = previewController.view
        previewView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(previewView)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            previewView.heightAnchor.constraint(greaterThanOrEqualToConstant: previewMinHeight),
        ])
    }

    private func setupPreviewTextStylePopover() {
        previewTextStylePopover.behavior = .transient
        previewTextStylePopover.animates = true
        previewTextStylePopover.contentViewController = previewTextStylePopoverViewController
        previewTextStylePopoverViewController.apply(style: currentPreviewTextStyle)
    }

    private func setupActions() {
        scriptPopUp.target = self
        scriptPopUp.action = #selector(scriptChanged(_:))

        fontSizeToolbarControl.onFontSizeChanged = { [weak self] fontSize in
            self?.applyPreviewFontSize(fontSize)
        }

        previewTextStyleToolbarButton.onPress = { [weak self] button in
            self?.togglePreviewTextStylePopover(relativeTo: button)
        }

        previewTextStylePopoverViewController.onStyleChanged = { [weak self] style in
            self?.applyPreviewTextStyle(style)
        }

        currentPreviewTextStyle.fontSize = FontPreviewTextStyle.normalizedFontSize(fontSizeToolbarControl.fontSize)
        previewTextStylePopoverViewController.apply(style: currentPreviewTextStyle)
        previewController.setTextStyle(currentPreviewTextStyle)
    }

    // MARK: - Public

    func makeFontSizeToolbarItem(itemIdentifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        // Force loadView() so toolbar control wiring is in place before attaching it.
        _ = view

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Preview Size"
        item.paletteLabel = "Preview Size"
        item.toolTip = "Adjust preview size"
        item.view = fontSizeToolbarControl
        return item
    }

    func makePreviewTextStyleToolbarItem(itemIdentifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        _ = view

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Text Style"
        item.paletteLabel = "Text Style"
        item.toolTip = "Adjust preview text style"
        item.view = previewTextStyleToolbarButton
        return item
    }

    func makeScriptToolbarItem(itemIdentifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        // Force loadView() so toolbar control wiring is in place before attaching it.
        _ = view

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Script"
        item.paletteLabel = "Script"
        item.toolTip = "Choose preview script sample"
        item.view = scriptPopUp
        return item
    }

    func updateFonts(_ fonts: [FontRecord]) {
        currentFonts = fonts
        if fonts.isEmpty {
            showEmpty()
        } else {
            showContent(fonts)
        }
    }

    /// Convenience wrapper for single font selection (backwards compat).
    func updateFont(_ font: FontRecord?) {
        if let font = font {
            updateFonts([font])
        } else {
            updateFonts([])
        }
    }

    // MARK: - Actions

    @objc private func scriptChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0, index < ScriptSamples.all.count else { return }
        let sample = ScriptSamples.all[index]
        previewController.setSampleText(sample.sampleText)
    }

    // MARK: - Private

    private func showEmpty() {
        emptyLabel.isHidden = false
        contentContainer.isHidden = true
        updatePreviewControlAvailability()
    }

    private func showContent(_ fonts: [FontRecord]) {
        emptyLabel.isHidden = true
        contentContainer.isHidden = false
        updatePreviewControlAvailability()
        previewController.configure(fonts: fonts)
    }

    private func updatePreviewControlAvailability() {
        let isEnabled = !currentFonts.isEmpty
        fontSizeToolbarControl.isEnabled = isEnabled
        previewTextStyleToolbarButton.isEnabled = isEnabled

        if !isEnabled {
            previewTextStylePopover.performClose(nil)
        }
    }

    private func togglePreviewTextStylePopover(relativeTo anchorView: NSView) {
        guard !currentFonts.isEmpty else { return }

        if previewTextStylePopover.isShown {
            previewTextStylePopover.performClose(nil)
            return
        }

        previewTextStylePopoverViewController.apply(style: currentPreviewTextStyle)
        previewTextStylePopover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    private func applyPreviewTextStyle(_ style: FontPreviewTextStyle) {
        guard style != currentPreviewTextStyle else { return }

        currentPreviewTextStyle = style
        previewController.setTextStyle(style)
    }

    private func applyPreviewFontSize(_ size: CGFloat) {
        let normalizedSize = FontPreviewTextStyle.normalizedFontSize(size)
        guard normalizedSize != currentPreviewTextStyle.fontSize else { return }

        currentPreviewTextStyle.fontSize = normalizedSize
        previewTextStylePopoverViewController.apply(style: currentPreviewTextStyle)
        previewController.setTextStyle(currentPreviewTextStyle)
    }
}
