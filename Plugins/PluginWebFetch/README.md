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

This package builds and tests independently, and the app discovers it through the generated package plugin registry.

## App Integration Checklist

1. Keep the `PluginWebFetch` product available to the Lumi app target.
2. Verify `PluginWebFetch.WebFetchPlugin` is included in `LumiApp/Core/Generated/GeneratedPluginRegistry.swift`.
3. Keep plugin logic in this package.
4. Verify the Agent tool list still exposes `web_fetch`.
