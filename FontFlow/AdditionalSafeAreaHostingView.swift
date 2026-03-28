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

    // Override only `safeAreaInsets` here. Once the window uses the standard
    // titlebar safe area, shrinking `safeAreaRect` as well can double-count the
    // top exclusion and push scroll/collection content downward.
    override var safeAreaInsets: NSEdgeInsets {
        let insets = super.safeAreaInsets
        return NSEdgeInsets(
            top: insets.top + additionalInsets.top,
            left: insets.left + additionalInsets.left,
            bottom: insets.bottom + additionalInsets.bottom,
            right: insets.right + additionalInsets.right
        )
    }
}
