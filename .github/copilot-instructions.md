# Copilot Instructions

## Project Overview

FontFlow is a macOS desktop application for font management. Built with Swift 5 and AppKit (Cocoa), targeting macOS 26.2.

- **Bundle ID**: `tips.tty.FontFlow`
- **UI**: Programmatic AppKit (all UI built in code). `Main.storyboard` is retained only for the menu bar/menus. Not SwiftUI.
- **Persistence**: Core Data (model in `FontFlow.xcdatamodeld`)
- **No external dependencies** — no SPM, CocoaPods, or Carthage

## Build & Test Commands

```bash
# Build
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -configuration Debug build

# Run all unit tests
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -configuration Debug test

# Run a specific test class
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -only-testing:FontFlowTests/FontFlowTests test

# Run UI tests
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow -only-testing:FontFlowUITests test

# Clean build
xcodebuild -project FontFlow.xcodeproj -scheme FontFlow clean
```

## Architecture

- **AppDelegate** (`FontFlow/AppDelegate.swift`): App lifecycle, Core Data stack (`NSPersistentContainer`), undo/redo management, save-on-terminate with user confirmation dialog.
- **ViewController** (`FontFlow/ViewController.swift`): Main view controller (`NSViewController`).
- **UI approach**: All views and view controllers are created programmatically (no Interface Builder for UI layout). `Main.storyboard` exists solely for the main menu bar.

## Testing Conventions

- **Unit tests** use Swift Testing framework (`import Testing`, `@Test`, `#expect(...)`).
- **UI tests** use XCTest (`XCUIApplication`). UI test methods must be annotated `@MainActor`.
