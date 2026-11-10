# MagicAlert

[![中文](https://img.shields.io/badge/中文-README-blue)](README_zh.md)

A SwiftUI-based toast notification system for iOS and macOS applications.

## Features

- **Toast Notifications**: Display temporary messages to users
- **Multiple Toast Types**: Success, error, warning, and info toasts
- **Customizable Styling**: Easily customize appearance and behavior
- **Error Handling**: Built-in error view component
- **SwiftUI Native**: Fully built with SwiftUI for modern apps

## Screenshots

![MagicAlert Demo](docs/hero.png)

## Installation

### Swift Package Manager

Add MagicAlert as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0")
]
```

Or add it directly in Xcode:

1. Go to File → Add Packages...
2. Enter the repository URL: `https://github.com/nookery/MagicAlert.git`
3. Choose the version you want to use

## Usage

Add the `.withMagicToast()` modifier to your root view and use global functions to display messages:

```swift
import SwiftUI
import MagicAlert

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Show Success") {
                alert_success("Operation successful")
            }

            Button("Show Error") {
                alert_error("Operation failed", autoDismiss: false)
            }

            Button("Show Info") {
                alert_info("This is an info message", subtitle: "More details")
            }

            Button("Show Warning") {
                alert_warning("Please be careful")
            }

            Button("Show Loading") {
                alert_loading("Processing...")
            }

            Button("Dismiss Loading") {
                alert_dismiss_loading()
            }

            Button("Dismiss All") {
                alert_dismiss_all()
            }
        }
        .withMagicToast() // Enable toast functionality
    }
}
```

**Available Global Functions:**

- `alert_info(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3.0)` - Show info toast
- `alert_success(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3.0)` - Show success toast
- `alert_warning(_ title: String, subtitle: String? = nil, duration: TimeInterval = 4.0)` - Show warning toast
- `alert_error(_ title: String, subtitle: String? = nil, duration: TimeInterval = 0, autoDismiss: Bool = false)` - Show error text
- `alert_error(_ error: Error, title: String? = nil, duration: TimeInterval = 0, autoDismiss: Bool = false)` - Show error object
- `alert_loading(_ title: String, subtitle: String? = nil)` - Show loading toast
- `alert_dismiss_loading()` - Dismiss loading toast
- `alert_dismiss_all()` - Dismiss all toasts

## Requirements

- iOS 17.0+
- macOS 14.0+
- Swift 5.9+

## License

This project is licensed under the MIT License - see the LICENSE file for details.
