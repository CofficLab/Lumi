# PluginShowImage

`PluginShowImage` is the package-based Show Image plugin for Lumi.

The package exposes the plugin adapter, tool, and overlay view:

- `ShowImagePlugin`: Lumi plugin entry point (provides `addRootView` for image overlay)
- `ShowImageTool`: Agent tool adapter for `show_image`
- `ShowImageOverlay`: SwiftUI overlay that renders images on top of the app content
- `ShowImageState`: @MainActor singleton for managing image display state
- `Resources/ShowImage.xcstrings`: plugin-owned localization catalog

## Structure

```text
PluginShowImage
  Package.swift
  Sources/PluginShowImage
    Resources/ShowImage.xcstrings
    ShowImagePlugin.swift
    ShowImageTool.swift
    ShowImageOverlay.swift
  Tests/PluginShowImageTests
    ShowImagePluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/PluginShowImage/Resources/ShowImage.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginShowImageLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.
