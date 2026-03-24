//
//  AdditionalSafeAreaHostingView.swift
//  FontFlow
//
//  Created on 2026/3/24.
//

import Cocoa

final class AdditionalSafeAreaHostingView: NSView {
    private let additionalInsets: NSEdgeInsets

    init(additionalInsets: NSEdgeInsets) {
        self.additionalInsets = additionalInsets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var safeAreaInsets: NSEdgeInsets {
        let insets = super.safeAreaInsets
        return NSEdgeInsets(
            top: insets.top + additionalInsets.top,
            left: insets.left + additionalInsets.left,
            bottom: insets.bottom + additionalInsets.bottom,
            right: insets.right + additionalInsets.right
        )
    }

    override var safeAreaRect: NSRect {
        let rect = super.safeAreaRect
        return NSRect(
            x: rect.minX + additionalInsets.left,
            y: rect.minY + additionalInsets.bottom,
            width: max(0, rect.width - additionalInsets.left - additionalInsets.right),
            height: max(0, rect.height - additionalInsets.top - additionalInsets.bottom)
        )
    }
}
