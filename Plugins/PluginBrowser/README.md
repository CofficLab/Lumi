# PluginBrowser

`PluginBrowser` is the package-based Browser plugin for Lumi.

The package exposes the plugin adapter and tool registration layer:

- `BrowserPlugin`: Lumi plugin entry point
- `BrowserScreenshotTool`: Agent tool adapter for `browser_screenshot` (WKWebView-based page rendering)
- `Resources/Browser.xcstrings`: plugin-owned localization catalog

## Structure

```text
PluginBrowser
  Package.swift
  Sources/PluginBrowser
    Resources/Browser.xcstrings
    BrowserPlugin.swift
    BrowserScreenshotTool.swift
  Tests/PluginBrowserTests
    BrowserPluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/PluginBrowser/Resources/Browser.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginBrowserLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.
