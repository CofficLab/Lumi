# PluginBrowser

Lumi's integrated WebKit browser workspace and conversation-scoped browser tools.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Features

- **Browser workspace** - a visible `WKWebView` in the main content area with Lumi's existing chat panel beside it
- **browser_open** - opens an HTTP or HTTPS page in the current conversation's isolated browser session
- **browser_read** - returns the page title, URL, bounded visible text, and references for visible links and controls
- **browser_interact** - clicks a referenced control or enters text into a field after Lumi's high-risk approval flow
- Each conversation has its own non-persistent website data store
- Local and private-network destinations require approval; the browser blocks redirects to unapproved local hosts

Browser sessions currently live for the app process. Closing Lumi clears the isolated website data.

## Structure

```text
    PluginBrowser
  Package.swift
    Sources/
      BrowserSuperPlugin.swift
      BrowserSession.swift
      BrowserTools.swift
      BrowserWorkspaceView.swift
      BrowserWebView.swift
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
