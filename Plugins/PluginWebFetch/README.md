# PluginWebFetch

`PluginWebFetch` is the package-based Web Fetch plugin prototype for Lumi.

The package exposes the plugin adapter and tool registration layer:

- `WebFetchPlugin`: Lumi plugin entry point
- `WebFetchTool`: Agent tool adapter for `web_fetch`
- `Resources/WebFetch.xcstrings`: plugin-owned localization catalog

The actual fetch and content extraction logic lives in `WebFetchKit`. This package should stay focused on plugin integration, tool schema, permissions, and package-level tests.

## Structure

```text
PluginWebFetch
  Package.swift
  Sources/PluginWebFetch
    Resources/WebFetch.xcstrings
    WebFetchPlugin.swift
    WebFetchTool.swift
  Tests/PluginWebFetchTests
    WebFetchPluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/PluginWebFetch/Resources/WebFetch.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginWebFetchLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.

## Current Status

This package is a migration prototype. It builds and tests independently, but the app still contains the legacy in-app WebFetch plugin implementation until the app target is wired to this package product.

## App Integration Checklist

1. Add the `PluginWebFetch` product to the Lumi app target.
2. Register `WebFetchPlugin.shared` from this package in the app plugin registry.
3. Remove or disable the legacy `LumiApp/Plugins/WebFetchPlugin` implementation.
4. Verify the Agent tool list still exposes `web_fetch`.
