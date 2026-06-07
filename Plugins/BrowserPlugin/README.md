# BrowserPlugin

Browser plugin for Lumi. Provides web page screenshots and browser automation tools.

## Features

- **browser_screenshot** - WKWebView-based page rendering and screenshot capture
- **browser_agent** - browser automation via the `agent-browser` CLI

## Structure

```text
BrowserPlugin
  Package.swift
  Sources/
    BrowserPlugin.swift
    BrowserScreenshotTool.swift
    BrowserAgentTool.swift
  Resources/
    Localizable.xcstrings
  Tests/
    BrowserPluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Resources/Localizable.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginBrowserLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.
