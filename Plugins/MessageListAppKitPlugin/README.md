# MessageListAppKitPlugin

A parallel, **native AppKit** implementation of the Lumi chat message list.

## Status

- **Policy:** `LumiPluginPolicy.disabled`
- Ships alongside the existing SwiftUI `MessageListPlugin`; the host app
  renders only the original SwiftUI message list until parity and
  performance gates pass.
- See `docs/plans/2026-08-06-message-list-appkit-plugin.md` for the full plan.
- See `docs/performance/message-list-baseline.md` for performance measurements.

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

## Architecture

```text
ChatSectionItem (SwiftUI API boundary)
  └─ MessageListAppKitBridge : NSViewControllerRepresentable
       └─ AppKitMessageListViewController
            ├─ NSScrollView + NSTableView
            ├─ AppKitMessageListDataSource
            ├─ AppKitMessageListCoordinator
            │    ├─ selected-conversation narrow subscription
            │    ├─ messagesDidChange / turnFinished notifications
            │    ├─ MessageStreaming direct subscription (V2 only)
            │    └─ pagination + snapshot coalescing
            ├─ AppKitMessageProjection
            │    ├─ BriefTurnProjector
            │    └─ TimelineProjector
            ├─ AppKitMessageRendererRegistry
            │    ├─ native core renderers
            │    └─ native fallback renderer
            └─ AppKitMessageLayoutCache
                 ├─ Markdown AST/attributed-content cache
                 ├─ width/theme/verbosity-aware height cache
                 └─ Mermaid/code/table caches
```

## Layout

```text
Sources/
├── MessageListAppKitPlugin.swift     # Entry point, .disabled policy
├── Bridge/
│   └── MessageListAppKitBridge.swift # SwiftUI ↔ AppKit boundary
├── Controllers/
│   └── AppKitMessageListViewController.swift
├── Data/
│   ├── AppKitMessageListCoordinator.swift
│   ├── AppKitMessageListDataSource.swift
│   ├── AppKitMessagePagination.swift
│   └── AppKitSnapshotRefreshGate.swift
├── Diagnostics/
│   └── AppKitMessageListMetrics.swift  # os_signpost + counters
├── Markdown/
│   ├── AppKitMarkdownDocument.swift
│   ├── AppKitMarkdownView.swift
│   ├── AppKitCodeBlockView.swift
│   ├── AppKitMarkdownTableView.swift
│   ├── AppKitMermaidView.swift
│   └── AppKitMermaidCache.swift
├── Models/
│   ├── AppKitMessageRow.swift
│   ├── AppKitMessageListSnapshot.swift
│   ├── AppKitMessageTheme.swift
│   └── AppKitRowLayoutKey.swift
├── Projection/
│   ├── BriefTurnProjector.swift
│   └── TimelineProjector.swift
├── Rendering/
│   ├── AppKitMessageRenderer.swift
│   ├── AppKitMessageRendererRegistry.swift
│   ├── AppKitMessageLayoutCache.swift
│   ├── AppKitAssistantRenderer.swift
│   ├── AppKitCoreRenderers.swift
│   ├── AppKitToolRenderer.swift
│   ├── AppKitToolGroupRenderer.swift
│   ├── AppKitAskUserRenderer.swift
│   └── AppKitFallbackRenderer.swift
├── Table/
│   ├── AppKitMessageCellView.swift
│   ├── AppKitLoadEarlierCellView.swift
│   ├── AppKitMessageTableDelegate.swift
│   └── AppKitScrollAnchor.swift
└── Views/
    ├── AppKitListStateViews.swift
    └── AppKitMessageHeaderView.swift
```

## Renderers

| Renderer | Row kind | Description |
|---|---|---|
| `AppKitAssistantRenderer` | `.assistant` | User/assistant Markdown via native TextKit |
| `AppKitCoreRenderers` | `.user`, `.system`, `.status`, `.error`, `.conclusion` | Prose + status indicator |
| `AppKitToolRenderer` | `.tool` | Single tool call: icon, status, expandable result |
| `AppKitToolGroupRenderer` | `.toolStepGroup` | Collapsed summary of consecutive tool calls |
| `AppKitAskUserRenderer` | `.tool` (interactive) | `ask_user` payload: yes/no, choice, free-text |
| `AppKitFallbackRenderer` | `.fallback` | Generic diagnostic block for unknown kinds |

## Markdown pipeline

- Block parsing uses `MarkdownKitCore.MarkdownParser` (pure parsing, no SwiftUI).
- Inline formatting uses `AppKitInlineMarkdownFormatter` → native `NSAttributedString`.
- Prose blocks render in non-scrolling `NSTextView` (TextKit).
- Code blocks: horizontal `NSScrollView` + non-wrapping `NSTextView`.
- Tables: custom CoreText drawing (no nested table).
- Mermaid: `BeautifulMermaid.MermaidRenderer.renderImageAsync`, cached `NSImage`.

## Performance diagnostics

`AppKitMessageListMetrics` provides `os_signpost` intervals for:

- Snapshot build/apply
- Cell configure/reuse
- Markdown parse
- Height measure
- Syntax highlight / Mermaid render
- Scroll hitches

`AppKitMessageListPerformanceTests` automates gate checks: snapshot timings,
pagination bounds, layout cache hit rate, memory stability on repeated refresh,
and conversation switch latency.

## Localization

All user-facing strings go through `LumiPluginLocalization` with keys in
`Resources/Localizable.xcstrings` (English + zh-Hans + zh-Hant).

## Replacement checklist

See `docs/plans/2026-08-06-message-list-appkit-plugin.md` §6 for the
activation procedure. Replacement is authorized only when:

- All functional parity fixtures pass.
- `ask_user`, links, copy, attachments, errors, code, tables, Mermaid work natively.
- No `NSHostingView` exists in the plugin.
- Performance and memory gates pass.
- No scroll-position jumps during append/prepend/height correction.
- The user explicitly approves activation.
