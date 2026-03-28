//
//  FontPreviewTextStyle.swift
//  FontFlow
//
//  Created on 2026/3/27.
//

import Cocoa

struct FontPreviewTextStyle: Equatable {

    static let minimumFontSize: CGFloat = 8
    static let maximumFontSize: CGFloat = 200
    static let defaultFontSize: CGFloat = 36
    static let minimumLineSpacingMultiplier: CGFloat = 1.0
    static let maximumLineSpacingMultiplier: CGFloat = 2.0
    static let defaultLineSpacingMultiplier: CGFloat = 1.0

    static let `default` = FontPreviewTextStyle()

    var fontSize: CGFloat
    var lineSpacingMultiplier: CGFloat
    var foregroundColor: NSColor?
    var backgroundColor: NSColor?

    init(
        fontSize: CGFloat = FontPreviewTextStyle.defaultFontSize,
        lineSpacingMultiplier: CGFloat = FontPreviewTextStyle.defaultLineSpacingMultiplier,
        foregroundColor: NSColor? = nil,
        backgroundColor: NSColor? = nil
    ) {
        self.fontSize = Self.normalizedFontSize(fontSize)
        self.lineSpacingMultiplier = Self.normalizedLineSpacingMultiplier(lineSpacingMultiplier)
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    var resolvedForegroundColor: NSColor {
        foregroundColor ?? .labelColor
    }

    var resolvedBackgroundColor: NSColor {
        backgroundColor ?? .clear
    }

    static func normalizedFontSize(_ value: CGFloat) -> CGFloat {
        let clampedValue = min(max(value, minimumFontSize), maximumFontSize)
        return clampedValue.rounded()
    }

    static func normalizedLineSpacingMultiplier(_ value: CGFloat) -> CGFloat {
        let clampedValue = min(max(value, minimumLineSpacingMultiplier), maximumLineSpacingMultiplier)
        return (clampedValue * 10).rounded() / 10
    }

    static func == (lhs: FontPreviewTextStyle, rhs: FontPreviewTextStyle) -> Bool {
        lhs.fontSize == rhs.fontSize
            && lhs.lineSpacingMultiplier == rhs.lineSpacingMultiplier
            && colorsEqual(lhs.foregroundColor, rhs.foregroundColor)
            && colorsEqual(lhs.backgroundColor, rhs.backgroundColor)
    }

    private static func colorsEqual(_ lhs: NSColor?, _ rhs: NSColor?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhsColor?, rhsColor?):
            return lhsColor.isEqual(rhsColor)
        default:
            return false
        }
    }
}
