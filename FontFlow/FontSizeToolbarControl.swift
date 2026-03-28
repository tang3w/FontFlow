//
//  FontSizeToolbarControl.swift
//  FontFlow
//
//  Created on 2026/3/26.
//

import Cocoa

protocol FontSizeToolbarControlDelegate: AnyObject {
    func fontSizeToolbarControl(_ control: FontSizeToolbarControl, didChangeFontSize fontSize: CGFloat)
}

private final class ZeroInsetSliderCell: NSSliderCell {

    override func barRect(flipped: Bool) -> NSRect {
        var rect = super.barRect(flipped: flipped)
        rect.origin.x = 0
        rect.size.width = controlView?.bounds.width ?? rect.size.width
        return rect
    }

    override func knobRect(flipped: Bool) -> NSRect {
        let bar = barRect(flipped: flipped)
        let superKnob = super.knobRect(flipped: flipped)
        let knobWidth = superKnob.size.width

        let proportion = (doubleValue - minValue) / (maxValue - minValue)
        let usableWidth = bar.size.width - knobWidth
        let knobX = bar.origin.x + CGFloat(proportion) * usableWidth

        return NSRect(x: knobX, y: superKnob.origin.y, width: knobWidth, height: superKnob.size.height)
    }
}

final class FontSizeToolbarControl: NSView {

    private enum LayoutMetrics {
        static let defaultFontSize: Double = 48
        static let minimumFontSize: Double = 8
        static let maximumFontSize: Double = 200
        static let sliderWidth: CGFloat = 100
        static let stackSpacing: CGFloat = 10
        static let horizontalInset: CGFloat = 10
        static let verticalInset: CGFloat = 3
        static let smallGlyphFontSize: CGFloat = 11
        static let largeGlyphFontSize: CGFloat = 15
    }

    weak var delegate: FontSizeToolbarControlDelegate?
    var onFontSizeChanged: ((CGFloat) -> Void)?

    var fontSize: CGFloat {
        get { currentFontSize }
        set { setFontSize(newValue, notify: false) }
    }

    var isEnabled: Bool = true {
        didSet {
            guard isEnabled != oldValue else { return }
            updateEnabledState()
        }
    }

    private let stackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = LayoutMetrics.stackSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stackView
    }()

    private let smallGlyphLabel: NSTextField = {
        let label = NSTextField(labelWithString: "A")
        label.font = .systemFont(ofSize: LayoutMetrics.smallGlyphFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let slider: NSSlider = {
        let slider = NSSlider(
            value: LayoutMetrics.defaultFontSize,
            minValue: LayoutMetrics.minimumFontSize,
            maxValue: LayoutMetrics.maximumFontSize,
            target: nil,
            action: nil
        )
        slider.controlSize = .small
        let cell = ZeroInsetSliderCell()
        cell.controlSize = .small
        cell.minValue = LayoutMetrics.minimumFontSize
        cell.maxValue = LayoutMetrics.maximumFontSize
        cell.doubleValue = LayoutMetrics.defaultFontSize
        cell.isContinuous = true
        slider.cell = cell
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: LayoutMetrics.sliderWidth).isActive = true
        return slider
    }()

    private let largeGlyphLabel: NSTextField = {
        let label = NSTextField(labelWithString: "A")
        label.font = .systemFont(ofSize: LayoutMetrics.largeGlyphFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private var currentFontSize = CGFloat(LayoutMetrics.defaultFontSize)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setAccessibilityIdentifier("font-size-toolbar-control")
        toolTip = "Adjust preview size"
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(stackView)
        stackView.addArrangedSubview(smallGlyphLabel)
        stackView.addArrangedSubview(slider)
        stackView.addArrangedSubview(largeGlyphLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayoutMetrics.horizontalInset),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: LayoutMetrics.verticalInset),
            trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: LayoutMetrics.horizontalInset),
            bottomAnchor.constraint(equalTo: stackView.bottomAnchor, constant: LayoutMetrics.verticalInset),
        ])

        slider.setAccessibilityIdentifier("font-size-slider")
        slider.target = self
        slider.action = #selector(sliderValueDidChange(_:))

        updateToolTips(for: fontSize)
        updateEnabledState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        let contentSize = stackView.fittingSize
        return NSSize(
            width: contentSize.width + (LayoutMetrics.horizontalInset * 2),
            height: contentSize.height + (LayoutMetrics.verticalInset * 2)
        )
    }

    @objc private func sliderValueDidChange(_ sender: NSSlider) {
        let previousValue = currentFontSize
        let newValue = normalizedFontSize(from: sender.doubleValue)

        currentFontSize = newValue
        sender.doubleValue = Double(newValue)
        updateToolTips(for: newValue)

        guard newValue != previousValue else { return }
        delegate?.fontSizeToolbarControl(self, didChangeFontSize: newValue)
        onFontSizeChanged?(newValue)
    }

    private func setFontSize(_ newValue: CGFloat, notify: Bool) {
        let previousValue = currentFontSize
        let normalizedValue = normalizedFontSize(from: Double(newValue))

        currentFontSize = normalizedValue
        slider.doubleValue = Double(normalizedValue)
        updateToolTips(for: normalizedValue)

        guard notify, normalizedValue != previousValue else { return }
        delegate?.fontSizeToolbarControl(self, didChangeFontSize: normalizedValue)
        onFontSizeChanged?(normalizedValue)
    }

    private func normalizedFontSize(from value: Double) -> CGFloat {
        CGFloat(value).rounded()
    }

    private func updateEnabledState() {
        slider.isEnabled = isEnabled

        let glyphColor: NSColor = isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
        smallGlyphLabel.textColor = glyphColor
        largeGlyphLabel.textColor = glyphColor
    }

    private func updateToolTips(for size: CGFloat) {
        let toolTip = "Preview Size: \(Int(size)) pt"
        self.toolTip = toolTip
        slider.toolTip = toolTip
    }
}
