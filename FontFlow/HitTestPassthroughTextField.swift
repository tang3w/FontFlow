//
//  HitTestPassthroughTextField.swift
//  FontFlow
//
//  Created on 2026/3/29.
//

import Cocoa

final class HitTestPassthroughTextField: NSTextField {

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
