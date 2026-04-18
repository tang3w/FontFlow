# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

FontFlow is a macOS desktop application for font management. Built with Swift 5 and AppKit (Cocoa), targeting macOS 26.2.

- **Bundle ID**: tips.tty.FontFlow
- **UI**: Programmatic AppKit (all UI built in code). `Main.storyboard` is retained only for the menu bar/menus. Not SwiftUI.
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

- **AppDelegate** (`FontFlow/App/AppDelegate.swift`): App lifecycle, Core Data stack setup, undo/redo management, save-on-terminate
- **MainSplitViewController** (`FontFlow/Features/Main/MainSplitViewController.swift`): Top-level three-pane split view (sidebar / browser / detail) and toolbar host
- **UI approach**: All views and view controllers are created programmatically (no Interface Builder for UI layout). `Main.storyboard` exists solely for the main menu bar.
- **Tests**: Unit tests use Swift Testing framework (`import Testing`); UI tests use XCTest with `XCUIApplication`
- No external dependencies (no SPM, CocoaPods, or Carthage)

## Source Layout

The Xcode project uses synchronized file-system groups, so folders on disk are mirrored in the Project Navigator automatically.

```
FontFlow/
  App/                # App lifecycle and entitlements
  Resources/          # Assets, storyboard (menu bar only), Core Data model, sample text data
  Models/             # Domain types and Core Data extensions
  Services/           # Non-UI services: import, parsing, file access, hashing, sorting
  Features/
    Main/             # Top-level split view controller and shared host views
    Sidebar/          # Library sidebar
    FontBrowser/      # Browser view controller plus grid and list child controllers / cells
    FontDetail/       # Detail panel view controller
    FontPreview/      # Reusable font preview rendering and the text-style popover
    Toolbar/          # Custom toolbar controls (e.g. font size)

FontFlowTests/
  Models/             # Core Data, predicate, and selection-state tests
  Services/           # Tests for import / loader / metadata / sorting services
  Resources/          # Test fixtures

FontFlowUITests/      # XCUIApplication-based smoke and launch tests
```
