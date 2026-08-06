# MessageListAppKitPlugin

A parallel, **native AppKit** implementation of the Lumi chat message list.

## Status

- **Policy:** `LumiPluginPolicy.disabled`
- Ships alongside the existing SwiftUI `MessageListPlugin`; the host app
  renders only the original SwiftUI message list until parity and
  performance gates pass.
- See `docs/plans/2026-08-06-message-list-appkit-plugin.md` for the full plan.

## Goal

Replace the eager SwiftUI `VStack` message list with an `NSTableView`-backed
native implementation that:

- Provides predictable cell reuse via `NSTableView`.
- Uses native TextKit/CoreText for Markdown, code, table, and Mermaid blocks.
- Never creates `NSHostingView` inside message renderers.
- Achieves the performance budget defined in the implementation plan.

## Non-goals (disabled-build)

- Does not remove or modify `MessageListPlugin` or `MessageRendererPlugin`.
- Does not change the existing message-list policy.
- Does not add runtime feature flags to `LumiKernel`.
- Does not embed SwiftUI provider renderers as a fallback.
- Does not introduce WebKit or JavaScript for Markdown/Mermaid.

## Layout

```
Sources/
├── MessageListAppKitPlugin.swift     # Entry point, .disabled policy
└── Bridge/
    └── MessageListAppKitBridge.swift # SwiftUI ↔ AppKit boundary (scaffold only)
```
