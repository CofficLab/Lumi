# BrewKit

Homebrew package management primitives for Lumi.

`BrewKit` is intended to hold reusable Homebrew-related models and services outside the app target. The current package exposes a small namespace and is ready for additional brew command, package, and cask management behavior.

## Package

- Product: `BrewKit`
- Platform: macOS 14+
- Swift tools: 5.9

## Current API

```swift
import BrewKit

let version = BrewKit.version
```

## Testing

From this package directory:

```sh
swift test
```

## App Integration

Keep UI, plugin registration, permissions, and app-specific workflows in the Lumi app target. Put reusable Homebrew command parsing, package metadata, and service logic in this package.
