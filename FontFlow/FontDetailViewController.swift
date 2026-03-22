//
//  FontDetailViewController.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Cocoa

/// Right pane of the split view. Hosts font preview and controls.
class FontDetailViewController: NSViewController {

    // MARK: - Child VC

    private let previewController = FontPreviewController()

    // MARK: - Empty State

    private let emptyLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Select a font to preview")
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

    // MARK: - Controls Bar

    private let controlsBar: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let scriptPopUp: NSPopUpButton = {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.translatesAutoresizingMaskIntoConstraints = false
        for sample in ScriptSamples.all {
            button.addItem(withTitle: sample.name)
        }
        button.selectItem(at: 0)
        return button
    }()

    private let fontSizeSlider: NSSlider = {
        let slider = NSSlider(value: 48, minValue: 8, maxValue: 200, target: nil, action: nil)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 120).isActive = true
        return slider
    }()

    private let fontSizeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "48 pt")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 48).isActive = true
        return label
    }()

    private let lineSpacingStepper: NSStepper = {
        let stepper = NSStepper()
        stepper.minValue = 1.0
        stepper.maxValue = 3.0
        stepper.increment = 0.1
        stepper.doubleValue = 1.2
        stepper.translatesAutoresizingMaskIntoConstraints = false
        return stepper
    }()

    private let lineSpacingLabel: NSTextField = {
        let label = NSTextField(labelWithString: "1.2x")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 32).isActive = true
        return label
    }()

    // MARK: - State

    private var currentFonts: [FontRecord] = []

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

        setupControlsBar()
        setupPreviewController()
        setupActions()

        showEmpty()
    }

    // MARK: - Setup

    private func setupControlsBar() {
        contentContainer.addSubview(controlsBar)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        controlsBar.addArrangedSubview(scriptPopUp)
        controlsBar.addArrangedSubview(spacer)
        controlsBar.addArrangedSubview(fontSizeSlider)
        controlsBar.addArrangedSubview(fontSizeLabel)
        controlsBar.addArrangedSubview(lineSpacingStepper)
        controlsBar.addArrangedSubview(lineSpacingLabel)

        NSLayoutConstraint.activate([
            controlsBar.topAnchor.constraint(equalTo: contentContainer.safeAreaLayoutGuide.topAnchor, constant: regionSpacing),
            controlsBar.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 12),
            controlsBar.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -12),
        ])
    }

    private func setupPreviewController() {
        addChild(previewController)
        let previewView = previewController.view
        previewView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(previewView)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: controlsBar.bottomAnchor, constant: regionSpacing),
            previewView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            previewView.heightAnchor.constraint(greaterThanOrEqualToConstant: previewMinHeight),
        ])
    }

    private func setupActions() {
        scriptPopUp.target = self
        scriptPopUp.action = #selector(scriptChanged(_:))

        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(fontSizeChanged(_:))

        lineSpacingStepper.target = self
        lineSpacingStepper.action = #selector(lineSpacingChanged(_:))
    }

    // MARK: - Public

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

    @objc private func fontSizeChanged(_ sender: NSSlider) {
        let size = CGFloat(sender.doubleValue).rounded()
        fontSizeLabel.stringValue = "\(Int(size)) pt"
        previewController.setFontSize(size)
    }

    @objc private func lineSpacingChanged(_ sender: NSStepper) {
        let spacing = sender.doubleValue
        lineSpacingLabel.stringValue = String(format: "%.1fx", spacing)
        previewController.setLineSpacing(CGFloat(spacing))
    }

    // MARK: - Private

    private func showEmpty() {
        emptyLabel.isHidden = false
        contentContainer.isHidden = true
    }

    private func showContent(_ fonts: [FontRecord]) {
        emptyLabel.isHidden = true
        contentContainer.isHidden = false
        previewController.configure(fonts: fonts)
    }
}
