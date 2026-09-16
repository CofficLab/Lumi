# BrowserPlugin

Browser plugin for Lumi. Provides web page screenshots and browser automation tools.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

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

