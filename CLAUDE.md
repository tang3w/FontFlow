# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FontFlow is a macOS desktop application for font management. Built with Swift 5 and AppKit (Cocoa), targeting macOS 26.2.

- **Bundle ID**: tips.tty.FontFlow
- **UI**: Storyboard-based (Main.storyboard), not SwiftUI
- **Persistence**: Core Data (model currently empty)

## Build & Test Commands

```bash
# Build
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -configuration Debug build

# Run unit tests
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -configuration Debug test

# Run a specific test class
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -only-testing:FontFlowTests/FontFlowTests test

# Run UI tests
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -only-testing:FontFlowUITests test

# Clean build
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow clean
```

## Architecture

- **AppDelegate** (`FontFlow/AppDelegate.swift`): App lifecycle, Core Data stack setup, undo/redo management, save-on-terminate
- **ViewController** (`FontFlow/ViewController.swift`): Main view controller (AppKit `NSViewController`)
- **Tests**: Unit tests use Swift Testing framework (`import Testing`); UI tests use XCTest with `XCUIApplication`
- No external dependencies (no SPM, CocoaPods, or Carthage)
