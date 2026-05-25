# PluginWebSearch

`PluginWebSearch` is the package-based Web Search plugin for Lumi.

The package exposes the plugin adapter and tool registration layer:

- `WebSearchPlugin`: Lumi plugin entry point
- `WebSearchTool`: Agent tool adapter for `web_search`
- `Resources/WebSearch.xcstrings`: plugin-owned localization catalog

This tool primarily exists to satisfy Function Calling requirements for models like Qwen
that require `web_search` to be present alongside `web_fetch`.

## Structure

```text
PluginWebSearch
  Package.swift
  Sources/PluginWebSearch
    Resources/WebSearch.xcstrings
    WebSearchPlugin.swift
    WebSearchTool.swift
  Tests/PluginWebSearchTests
    WebSearchPluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/PluginWebSearch/Resources/WebSearch.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginWebSearchLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.
