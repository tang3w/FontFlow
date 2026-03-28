//
//  PreviewTextStylePopoverViewController.swift
//  FontFlow
//
//  Created on 2026/3/27.
//

import Cocoa

final class PreviewTextStylePopoverViewController: NSViewController {

    private enum LayoutMetrics {
        static let contentInset: CGFloat = 16
        static let rowSpacing: CGFloat = 12
        static let columnSpacing: CGFloat = 16
        static let labelWidth: CGFloat = 92
        static let sliderWidth: CGFloat = 100
        static let valueLabelWidth: CGFloat = 40
    }

    var onStyleChanged: ((FontPreviewTextStyle) -> Void)?

    private var currentStyle = FontPreviewTextStyle.default

    private let lineSpacingSlider: NSSlider = {
        let slider = NSSlider(
            value: Double(FontPreviewTextStyle.defaultLineSpacingMultiplier),
            minValue: Double(FontPreviewTextStyle.minimumLineSpacingMultiplier),
            maxValue: Double(FontPreviewTextStyle.maximumLineSpacingMultiplier),
            target: nil,
            action: nil
        )
        slider.isContinuous = true
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: LayoutMetrics.sliderWidth).isActive = true
        return slider
    }()

    private let lineSpacingValueLabel: NSTextField = {
        let label = NSTextField(labelWithString: "1.2x")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.alignment = .right
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: LayoutMetrics.valueLabelWidth).isActive = true
        return label
    }()

    private let foregroundColorWell: NSColorWell = {
        let colorWell = NSColorWell()
        colorWell.supportsAlpha = false
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        return colorWell
    }()

    private let foregroundDefaultButton: NSButton = {
        let button = NSButton(title: "Default", target: nil, action: nil)
        button.controlSize = .small
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let backgroundColorWell: NSColorWell = {
        let colorWell = NSColorWell()
        colorWell.supportsAlpha = true
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        return colorWell
    }()

    private let backgroundClearButton: NSButton = {
        let button = NSButton(title: "Clear", target: nil, action: nil)
        button.controlSize = .small
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let resetButton: NSButton = {
        let button = NSButton(title: "Reset All", target: nil, action: nil)
        button.controlSize = .small
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func loadView() {
        view = NSView()

        let lineSpacingControls = makeHorizontalStackView()
        lineSpacingControls.addArrangedSubview(lineSpacingSlider)
        lineSpacingControls.addArrangedSubview(lineSpacingValueLabel)

        let foregroundControls = makeHorizontalStackView()
        foregroundControls.addArrangedSubview(foregroundColorWell)
        foregroundControls.addArrangedSubview(foregroundDefaultButton)

        let backgroundControls = makeHorizontalStackView()
        backgroundControls.addArrangedSubview(backgroundColorWell)
        backgroundControls.addArrangedSubview(backgroundClearButton)

        let gridView = NSGridView(views: [
            [makeSettingLabel("Line Spacing"), lineSpacingControls],
            [makeSettingLabel("Text Color"), foregroundControls],
            [makeSettingLabel("Background"), backgroundControls],
        ])
        gridView.rowSpacing = LayoutMetrics.rowSpacing
        gridView.columnSpacing = LayoutMetrics.columnSpacing
        gridView.translatesAutoresizingMaskIntoConstraints = false
        gridView.column(at: 0).width = LayoutMetrics.labelWidth
        gridView.column(at: 0).xPlacement = .leading
        gridView.column(at: 1).xPlacement = .fill

        view.addSubview(gridView)
        view.addSubview(resetButton)

        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: view.topAnchor, constant: LayoutMetrics.contentInset),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LayoutMetrics.contentInset),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -LayoutMetrics.contentInset),

            resetButton.topAnchor.constraint(equalTo: gridView.bottomAnchor, constant: LayoutMetrics.contentInset),
            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -LayoutMetrics.contentInset),
            resetButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -LayoutMetrics.contentInset),
        ])

        setupActions()
        updateControls()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let fittingSize = view.fittingSize
        if preferredContentSize != fittingSize {
            preferredContentSize = fittingSize
        }
    }

    func apply(style: FontPreviewTextStyle) {
        currentStyle = style

        guard isViewLoaded else { return }
        updateControls()
    }

    private func makeHorizontalStackView() -> NSStackView {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stackView
    }

    private func makeSettingLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func setupActions() {
        lineSpacingSlider.target = self
        lineSpacingSlider.action = #selector(lineSpacingChanged(_:))

        foregroundColorWell.target = self
        foregroundColorWell.action = #selector(foregroundColorChanged(_:))

        foregroundDefaultButton.target = self
        foregroundDefaultButton.action = #selector(resetForegroundColor(_:))

        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(backgroundColorChanged(_:))

        backgroundClearButton.target = self
        backgroundClearButton.action = #selector(clearBackgroundColor(_:))

        resetButton.target = self
        resetButton.action = #selector(resetAll(_:))
    }

    private func updateControls() {
        let normalizedLineSpacing = FontPreviewTextStyle.normalizedLineSpacingMultiplier(
            currentStyle.lineSpacingMultiplier
        )

        lineSpacingSlider.doubleValue = Double(normalizedLineSpacing)
        lineSpacingValueLabel.stringValue = String(format: "%.1fx", normalizedLineSpacing)
        foregroundColorWell.color = currentStyle.resolvedForegroundColor
        backgroundColorWell.color = currentStyle.resolvedBackgroundColor

        foregroundDefaultButton.isEnabled = currentStyle.foregroundColor != nil
        backgroundClearButton.isEnabled = currentStyle.backgroundColor != nil
        resetButton.isEnabled = currentStyle != popoverResetStyle(for: currentStyle)
    }

    private func popoverResetStyle(for style: FontPreviewTextStyle) -> FontPreviewTextStyle {
        FontPreviewTextStyle(fontSize: style.fontSize)
    }

    private func commitStyleChange(_ mutations: (inout FontPreviewTextStyle) -> Void) {
        var nextStyle = currentStyle
        mutations(&nextStyle)
        nextStyle.lineSpacingMultiplier = FontPreviewTextStyle.normalizedLineSpacingMultiplier(
            nextStyle.lineSpacingMultiplier
        )

        guard nextStyle != currentStyle else {
            updateControls()
            return
        }

        currentStyle = nextStyle
        updateControls()
        onStyleChanged?(currentStyle)
    }

    @objc private func lineSpacingChanged(_ sender: NSSlider) {
        commitStyleChange { style in
            style.lineSpacingMultiplier = CGFloat(sender.doubleValue)
        }
    }

    @objc private func foregroundColorChanged(_ sender: NSColorWell) {
        commitStyleChange { style in
            style.foregroundColor = sender.color
        }
    }

    @objc private func resetForegroundColor(_ sender: NSButton) {
        commitStyleChange { style in
            style.foregroundColor = nil
        }
    }

    @objc private func backgroundColorChanged(_ sender: NSColorWell) {
        commitStyleChange { style in
            let selectedColor = sender.color
            style.backgroundColor = selectedColor.alphaComponent == 0 ? nil : selectedColor
        }
    }

    @objc private func clearBackgroundColor(_ sender: NSButton) {
        commitStyleChange { style in
            style.backgroundColor = nil
        }
    }

    @objc private func resetAll(_ sender: NSButton) {
        let nextStyle = popoverResetStyle(for: currentStyle)
        guard nextStyle != currentStyle else { return }

        currentStyle = nextStyle
        updateControls()
        onStyleChanged?(currentStyle)
    }
}
