# MessageListAppKitPlugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a new, fully native AppKit message-list plugin—including Markdown rendering—register it in `LumiFactory`, and ship it with `public let policy: LumiPluginPolicy = .disabled` until it passes parity and performance testing.

**Architecture:** Keep only the unavoidable `NSViewControllerRepresentable` bridge required by `ChatSectionItem`; everything below that bridge uses AppKit. An `NSTableView` provides cell reuse and bounded visible-row work, a narrow event-driven store produces immutable V1/V2 snapshots, and native TextKit/CoreText renderers handle Markdown, code, tables, Mermaid images, tools, errors, status, and user interaction without `NSHostingView` or SwiftUI message rows.

**Tech Stack:** Swift 6, macOS 14+, AppKit (`NSTableView`, `NSScrollView`, `NSTextView`, TextKit/CoreText), Combine/NotificationCenter, LumiKernel, MarkdownKitCore, BeautifulMermaid, Swift Testing/XCTest, Instruments/signposts.

---

## 1. Scope and acceptance criteria

### Functional requirements

- Add a new package at `Plugins/MessageListAppKitPlugin` without modifying or depending on `MessageListPlugin`.
- Register `MessageListAppKitPlugin()` in `Packages/LumiFactory` while keeping:

  ```swift
  public let policy: LumiPluginPolicy = .disabled
  ```

- Preserve both presentation modes:
  - V1/brief: completed AgentTurn conclusions plus at most one live status row; no process messages or streaming body.
  - V2/standard/detailed: complete message history, tool activity, transient status, and streaming tail.
- Preserve conversation switching, first-page loading, earlier-page loading, bottom following, scroll-anchor preservation, empty/loading states, selection, copying, links, context menus, and theme changes.
- Provide native AppKit renderers for user, assistant, system, status, error, tool result, tool-call group, attachments, `ask_user`, and fallback messages.
- Render Markdown natively: paragraphs, headings, emphasis, links, unordered/ordered/task lists, quotes, thematic breaks, fenced code, tables, and Mermaid.
- Never create `NSHostingView` inside the plugin. `SwiftUI` is allowed only in the plugin entry point and the single AppKit bridge required by `ChatSectionItem`.
- Keep existing SwiftUI `MessageListPlugin` and `MessageRendererPlugin` unchanged during development.

### Non-functional requirements

- With 300 mixed Markdown rows, scrolling must sustain:
  - 60 Hz gate: p95 frame time under 16.7 ms, p99 under 33 ms, zero hitches over 100 ms during a 10-second automated scroll.
  - 120 Hz stretch goal: p95 frame time under 8.3 ms on supported hardware.
- Only visible rows plus a small prefetch margin may own live AppKit row views; target fewer than 30 configured cells for a normal chat viewport.
- Repeated scrolling must not reparse unchanged Markdown or recompute unchanged row heights.
- A 1,000-row stress fixture must keep incremental plugin memory below 250 MB and must not grow after three top-to-bottom scroll cycles.
- Applying one status/streaming update must update one row rather than call `reloadData()` for the whole table.
- Width, theme, verbosity, and content changes must invalidate only the affected height/layout cache entries.
- All message/database reads and Markdown parsing must remain off the main actor where safe; AppKit view mutation remains on the main actor.

### Explicit non-goals for the first disabled build

- Do not remove the old plugin.
- Do not change the old plugin policy.
- Do not add a runtime feature flag to `LumiKernel`.
- Do not embed existing SwiftUI provider-specific renderers as a fallback. Unsupported provider render kinds must use the native generic error/fallback renderer.
- Do not introduce WebKit or JavaScript for Markdown/Mermaid.

## 2. High-level architecture

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

The controller must not observe the entire `LumiKernel`. It receives service references once, subscribes only to the selected conversation and relevant message/streaming events, and applies immutable snapshots with stable row IDs.

## 3. Architecture decision record

### ADR-001: Use a native AppKit table and native Markdown pipeline

**Status:** Proposed until performance and parity gates pass.

**Context:** The current eager SwiftUI `VStack` creates and measures every retained row. Markdown rows contain many SwiftUI children and asynchronous attributed-text updates, while global observation and geometry preferences can invalidate the list during scrolling. Previous `LazyVStack` use also exposed an AttributeGraph lifecycle failure when a streaming tail became persisted history.

**Decision:** Implement a parallel plugin using `NSTableView` with explicit reuse, stable snapshot IDs, cached row heights, and native AppKit renderers. Use MarkdownKitCore only for pure Markdown block parsing; do not use `MarkdownBlockRenderer`, `NSHostingView`, or other SwiftUI row content.

**Positive consequences:** predictable reuse, bounded view count, direct clip-view scroll observation, controlled invalidation, native text selection/accessibility, and a measurable performance ceiling.

**Negative consequences:** a second rendering stack must be maintained during evaluation; custom SwiftUI renderer contributions cannot be reused; native table/code/Mermaid/interactive-tool parity requires substantial work.

**Alternatives rejected:**

- Optimize only the existing SwiftUI stack: lower cost, but does not satisfy the requested maximum native-performance direction.
- `NSTableView` with `NSHostingView` cells: improves virtualization but retains SwiftUI Markdown layout costs and lifecycle risk.
- Web-based Markdown: good HTML layout but adds WebKit process/memory/selection complexity and violates the native-rendering requirement.

## 4. Proposed package layout

```text
Plugins/MessageListAppKitPlugin/
├── Package.swift
├── README.md
├── Resources/Localizable.xcstrings
├── Sources/
│   ├── MessageListAppKitPlugin.swift
│   ├── Bridge/
│   │   └── MessageListAppKitBridge.swift
│   ├── Controllers/
│   │   └── AppKitMessageListViewController.swift
│   ├── Data/
│   │   ├── AppKitMessageListCoordinator.swift
│   │   ├── AppKitMessageListDataSource.swift
│   │   ├── AppKitMessagePagination.swift
│   │   └── AppKitSnapshotRefreshGate.swift
│   ├── Models/
│   │   ├── AppKitMessageListSnapshot.swift
│   │   ├── AppKitMessageRow.swift
│   │   ├── AppKitMessageTheme.swift
│   │   └── AppKitRowLayoutKey.swift
│   ├── Projection/
│   │   ├── BriefTurnProjector.swift
│   │   └── TimelineProjector.swift
│   ├── Table/
│   │   ├── AppKitMessageCellView.swift
│   │   ├── AppKitLoadEarlierCellView.swift
│   │   ├── AppKitMessageTableDelegate.swift
│   │   └── AppKitScrollAnchor.swift
│   ├── Rendering/
│   │   ├── AppKitMessageRenderer.swift
│   │   ├── AppKitMessageRendererRegistry.swift
│   │   ├── AppKitMessageLayoutCache.swift
│   │   ├── AppKitAssistantRenderer.swift
│   │   ├── AppKitUserRenderer.swift
│   │   ├── AppKitStatusRenderer.swift
│   │   ├── AppKitErrorRenderer.swift
│   │   ├── AppKitSystemRenderer.swift
│   │   ├── AppKitToolRenderer.swift
│   │   ├── AppKitToolGroupRenderer.swift
│   │   ├── AppKitAskUserRenderer.swift
│   │   ├── AppKitAttachmentRenderer.swift
│   │   └── AppKitFallbackRenderer.swift
│   ├── Markdown/
│   │   ├── AppKitMarkdownDocument.swift
│   │   ├── AppKitMarkdownParser.swift
│   │   ├── AppKitMarkdownView.swift
│   │   ├── AppKitInlineMarkdownFormatter.swift
│   │   ├── AppKitCodeBlockView.swift
│   │   ├── AppKitMarkdownTableView.swift
│   │   ├── AppKitMermaidView.swift
│   │   └── AppKitMermaidCache.swift
│   ├── Views/
│   │   ├── AppKitEmptyStateView.swift
│   │   ├── AppKitLoadingView.swift
│   │   ├── AppKitMessageHeaderView.swift
│   │   └── AppKitMessageContextMenu.swift
│   └── Diagnostics/
│       └── AppKitMessageListMetrics.swift
└── Tests/MessageListAppKitPluginTests/
    ├── BriefTurnProjectorTests.swift
    ├── TimelineProjectorTests.swift
    ├── SnapshotRefreshGateTests.swift
    ├── AppKitMarkdownParserTests.swift
    ├── AppKitMarkdownLayoutTests.swift
    ├── AppKitCellReuseTests.swift
    ├── AppKitScrollAnchorTests.swift
    ├── AppKitAskUserRendererTests.swift
    ├── AppKitMessageListIntegrationTests.swift
    └── AppKitMessageListPerformanceTests.swift
```

## 5. Implementation tasks

### Task 1: Record parity fixtures and baseline performance

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Tests/Fixtures/brief-turns.json`
- Create: `Plugins/MessageListAppKitPlugin/Tests/Fixtures/mixed-messages.json`
- Create: `Plugins/MessageListAppKitPlugin/Tests/Fixtures/markdown-showcase.md`
- Create: `Plugins/MessageListAppKitPlugin/Tests/Fixtures/ask-user.json`
- Create: `docs/performance/message-list-baseline.md`

**Steps:**

1. Capture fixtures covering all `LumiChatMessageRole` values, V1 completed/running/failed/suspended Turns, long prose, CJK, links, lists, code, tables, Mermaid, attachments, provider HTTP errors, tool groups, and `ask_user`.
2. Record current SwiftUI V1/V2 behavior and Instruments measurements on the same machine: initial load, 300-row scroll, status replacement, streaming, prepend, and conversation switch.
3. Write the acceptance table with absolute targets from section 1 and the measured SwiftUI baseline.
4. Commit fixtures and baseline separately:

   ```bash
   git add docs/performance/message-list-baseline.md Plugins/MessageListAppKitPlugin/Tests/Fixtures
   git commit -m "test(MessageListAppKit): add parity and performance fixtures"
   ```

### Task 2: Scaffold the disabled plugin package

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Package.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/MessageListAppKitPlugin.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Bridge/MessageListAppKitBridge.swift`
- Create: `Plugins/MessageListAppKitPlugin/Resources/Localizable.xcstrings`
- Create: `Plugins/MessageListAppKitPlugin/README.md`
- Create: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/PluginPolicyTests.swift`

**Steps:**

1. Write a failing test asserting the plugin ID, order, and `.disabled` policy.
2. Declare package dependencies on `LumiKernel`, `LumiUI`, `LocalizationKit`, `SuperLogKit`, and the local `MarkdownKit` package for `MarkdownKitCore`. Also declare `https://github.com/lukilabs/beautiful-mermaid-swift` from `1.0.0` directly so the target can import the `BeautifulMermaid` product. Do not depend on `MessageListPlugin`, the SwiftUI `MarkdownKit` product, or `MessageRendererPlugin`.
3. Implement the entry point with a unique ID such as `com.coffic.lumi.plugin.message-list-appkit`, order `82`, and exactly:

   ```swift
   public let policy: LumiPluginPolicy = .disabled
   ```

4. Return a `ChatSectionItem` whose content is the thin `MessageListAppKitBridge`; the bridge may conform to `NSViewControllerRepresentable`, but must contain no message rendering.
5. Run:

   ```bash
   swift test --package-path Plugins/MessageListAppKitPlugin
   ```

6. Add a source-boundary check that fails if `NSHostingView`, `MarkdownBlockRenderer`, or `MessageRowView` appears anywhere under this plugin.
7. Commit:

   ```bash
   git add Plugins/MessageListAppKitPlugin
   git commit -m "feat(MessageListAppKit): scaffold disabled native plugin"
   ```

### Task 3: Register the package in LumiFactory without enabling it

**Files:**
- Modify: `Packages/LumiFactory/Package.swift`
- Modify: `Packages/LumiFactory/Sources/LumiFactory/Services/PluginService.swift`

**Steps:**

1. Add `.package(path: "../../Plugins/MessageListAppKitPlugin")` and the corresponding product dependency.
2. Import `MessageListAppKitPlugin` in `PluginService.swift`.
3. Add `MessageListAppKitPlugin()` immediately after `MessageListPlugin()` so the relationship is obvious.
4. Verify that `PluginService.plugins` contains both plugins and that `PluginManager.effectiveEnabled(for:)` is false for the AppKit plugin.
5. Run:

   ```bash
   swift build --package-path Packages/LumiFactory
   swift test --package-path Plugins/MessageListAppKitPlugin
   ```

6. Confirm that the normal app still displays only the old message list.
7. Commit:

   ```bash
   git add Packages/LumiFactory
   git commit -m "build(LumiFactory): register disabled AppKit message list"
   ```

### Task 4: Define immutable row snapshots and V1/V2 projectors

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Models/AppKitMessageListSnapshot.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Models/AppKitMessageRow.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Projection/BriefTurnProjector.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Projection/TimelineProjector.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/BriefTurnProjectorTests.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/TimelineProjectorTests.swift`

**Steps:**

1. Write failing tests for stable row identity and deterministic ordering.
2. Lock V1 behavior in tests:
   - running/idle Turn emits no conclusion;
   - exactly one status row may follow historical conclusions;
   - completed emits the last non-tool assistant conclusion;
   - failed emits the last error;
   - suspended emits the interactive assistant message;
   - legacy messages without Turn identity emit only conclusion/error rows.
3. Lock V2 behavior in tests: preserve roles, merge status/streaming correctly, hide duplicate standalone tool rows only where current verbosity rules require it, and keep stable IDs when a streaming row becomes persisted history.
4. Implement `AppKitMessageRow` as a `Sendable`, `Equatable`, stable-ID value. Do not place `NSView`, `NSColor`, closures, or service objects in snapshots.
5. Run the two projector suites and commit.

### Task 5: Implement narrow subscriptions, pagination, and refresh coalescing

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Data/AppKitMessageListCoordinator.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Data/AppKitMessagePagination.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Data/AppKitSnapshotRefreshGate.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/SnapshotRefreshGateTests.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitMessageListIntegrationTests.swift`

**Steps:**

1. Write failing tests for conversation filtering, overlapping refresh collapse, stale conversation result rejection, prepend cursor behavior, and live-tail updates.
2. Capture only the needed services from `LumiKernel`: conversation manager/store, message manager, AgentTurn manager, message streaming, message sender, and tool manager.
3. Subscribe directly to selected-conversation changes and current streaming service changes; do not subscribe to `kernel.objectWillChange`.
4. Listen to scoped `messagesDidChange` and Turn-finished notifications. Coalesce bursts into one active refresh plus one trailing refresh.
5. Load pages off the main actor. Build immutable snapshots before returning to the controller.
6. Keep V1 and V2 pagination windows bounded. Set an initial page of 40 and a default retained cap of 300 rows; make both constructor-injectable for tests.
7. Verify cancellation on controller teardown and conversation switches.
8. Commit after the integration suite passes.

### Task 6: Build the native NSTableView shell and incremental data source

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Controllers/AppKitMessageListViewController.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Data/AppKitMessageListDataSource.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Table/AppKitMessageCellView.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Table/AppKitLoadEarlierCellView.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Table/AppKitMessageTableDelegate.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitCellReuseTests.swift`

**Steps:**

1. Write a failing reuse test: configure one cell with two incompatible row types and assert no stale subviews, constraints, selection, or actions remain.
2. Create one borderless `NSScrollView` containing a single-column, view-based `NSTableView`.
3. Disable implicit row animations during status/streaming refreshes.
4. Apply snapshot differences by stable ID using inserts, removals, moves, and targeted reloads. Reserve full `reloadData()` for conversation switches and unrecoverable snapshot mismatches.
5. Make reused cells own exactly one renderer root view at a time.
6. Add native loading and empty-state views.
7. Assert the number of instantiated cells stays near the visible row count in a 1,000-row test.
8. Commit.

### Task 7: Implement native scroll anchoring and bottom-follow behavior

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Table/AppKitScrollAnchor.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitScrollAnchorTests.swift`

**Steps:**

1. Observe `NSClipView.boundsDidChangeNotification`; do not use SwiftUI `GeometryReader` or `PreferenceKey`.
2. Define “at bottom” using document height, clip bounds, and a 48-point tolerance.
3. Before prepend, capture the top visible stable row ID plus its pixel offset. Restore the same ID and offset after rows and heights are applied.
4. Follow status/streaming/final rows only when the user was already at the bottom.
5. Add tests for append, prepend, dynamic-height correction, and user-scrolled-away behavior.
6. Commit.

### Task 8: Build the native Markdown document and cache pipeline

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitMarkdownDocument.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitMarkdownParser.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitInlineMarkdownFormatter.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Rendering/AppKitMessageLayoutCache.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Models/AppKitRowLayoutKey.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitMarkdownParserTests.swift`

**Steps:**

1. Write fixture-driven parser tests for every supported Markdown block and inline style.
2. Use `MarkdownKitCore.MarkdownParser` for block parsing and a Foundation/Markdown inline formatter that emits native attributes—never SwiftUI `Text`.
3. Parse source into an immutable, Sendable document off the main actor.
4. Cache documents by content hash.
5. Cache measured layouts by message ID, content hash, available width, scale, theme revision, and verbosity.
6. Bound both caches with LRU eviction and expose hit/miss counters for diagnostics.
7. Add cancellation so an offscreen/reused cell cannot install a stale parsed result.
8. Commit.

### Task 9: Render prose Markdown with TextKit/AppKit

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitMarkdownView.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitMarkdownLayoutTests.swift`

**Steps:**

1. Write failing width/height tests for short text, long wrapped CJK, headings, lists, quotes, links, and selection.
2. Use non-scrolling `NSTextView`/TextKit containers for prose blocks with background drawing disabled and text-container padding controlled explicitly.
3. Support selectable text, link clicking, keyboard copy, VoiceOver labels, and native context menus.
4. Ensure changing width recomputes height once and returns the cached height thereafter.
5. Verify no nested vertical scroll view is created.
6. Commit.

### Task 10: Add native code, table, and Mermaid blocks

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitCodeBlockView.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitMarkdownTableView.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitMermaidView.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Markdown/AppKitMermaidCache.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitMarkdownLayoutTests.swift`

**Steps:**

1. Implement code blocks as a native horizontal `NSScrollView` plus non-wrapping `NSTextView`; forward vertical wheel deltas to the outer table scroll view.
2. Add language label, copy action, monospaced font, and cached syntax-highlighted `NSAttributedString` with a plain-text fallback.
3. Render tables with a custom AppKit view/CoreText drawing rather than a nested vertical table. Measure column widths once per layout key and support horizontal overflow.
4. Call `BeautifulMermaid.MermaidRenderer.renderImageAsync`, cache `NSImage` results, display with `NSImageView`, and provide a native `NSPopover` or panel for expansion.
5. Render failures as native diagnostic blocks containing the source and error.
6. Test wheel forwarding, deterministic heights, Mermaid reuse, cancellation, and error fallback.
7. Commit.

### Task 11: Add the native renderer registry and core message renderers

**Files:**
- Create: all files under `Sources/Rendering/` listed in section 4.
- Create: `Plugins/MessageListAppKitPlugin/Sources/Views/AppKitMessageHeaderView.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Views/AppKitMessageContextMenu.swift`

**Steps:**

1. Define `AppKitMessageRenderer` with pure matching plus native `makeView`, `configure`, `prepareForReuse`, and `measure` operations.
2. Registry priority must mirror semantic precedence: turn/status, error, tool, tool group, user, assistant, system, fallback.
3. Implement user/assistant/system renderers using the native Markdown pipeline.
4. Implement status with native text and `NSProgressIndicator`; replacing status must reload only that row.
5. Implement error rendering with summary, HTTP status/body, raw details, copy, and expandable native sections. All current provider-specific render kinds must preserve their diagnostic data through this generic renderer.
6. Implement native headers, timestamps, token counts, copy/resend actions, and message-info presentation for standard/detailed modes.
7. Make renderer matching and layout cache lookups measurable with signposts.
8. Commit core renderers before moving to tools.

### Task 12: Implement tools, attachments, and native ask_user interaction

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Rendering/AppKitToolRenderer.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Rendering/AppKitToolGroupRenderer.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Rendering/AppKitAttachmentRenderer.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Rendering/AppKitAskUserRenderer.swift`
- Test: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitAskUserRendererTests.swift`

**Steps:**

1. Render tool call state, description, duration, success/error, and expandable result using native controls.
2. Preserve V1 hiding/summary rules and V2 tool-group expansion rules.
3. Decode and display file/image attachments with native chips, Quick Look/open actions, and image previews.
4. Define a plugin-local Codable `AppKitAskUserPayload` matching the existing `ask_user` wire shape; do not import its SwiftUI views.
5. Implement native yes/no, choice, and free-text controls.
6. On submit, call `kernel.messageSender?.resumeTurn(in:request:)`, immediately disable controls, and restore state correctly after cell reuse.
7. Test duplicate-submit prevention, legacy payloads, conversation/tool-call IDs, resume requests, and reuse after response.
8. Commit.

### Task 13: Integrate streaming, status replacement, and dynamic heights

**Files:**
- Modify: `Sources/Data/AppKitMessageListCoordinator.swift`
- Modify: `Sources/Controllers/AppKitMessageListViewController.swift`
- Modify: `Sources/Rendering/AppKitMessageLayoutCache.swift`
- Test: `Tests/MessageListAppKitPluginTests/AppKitMessageListIntegrationTests.swift`

**Steps:**

1. V1 tests must prove that token chunks never update the table; only status changes and terminal conclusions do.
2. V2 must throttle streaming presentation to at most one update per display frame and reconfigure only the stable streaming row.
3. When streaming becomes persisted history, replace by stable snapshot IDs without duplicate content or a full reload.
4. If a visible row height changes, call targeted table height invalidation while preserving bottom/top anchors.
5. Cancel parse/highlight/Mermaid work for reused/offscreen rows.
6. Commit after status, streaming, and terminal Turn integration tests pass.

### Task 14: Theme, appearance, accessibility, and localization parity

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Models/AppKitMessageTheme.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Views/AppKitEmptyStateView.swift`
- Create: `Plugins/MessageListAppKitPlugin/Sources/Views/AppKitLoadingView.swift`
- Modify: `Plugins/MessageListAppKitPlugin/Resources/Localizable.xcstrings`

**Steps:**

1. Snapshot Lumi theme values into native `NSColor`, `NSFont`, spacing, and corner-radius values.
2. Observe the theme store directly. Increment a theme revision, invalidate theme-sensitive layout keys, and refresh only visible rows.
3. Support light/dark appearance, Dynamic Type/accessibility sizing where available, keyboard navigation, VoiceOver row labels, link descriptions, progress semantics, and focus restoration.
4. Localize all new UI and verify Chinese/English strings.
5. Add UI-level assertions for focus, accessibility roles, and theme invalidation.
6. Commit.

### Task 15: Add performance diagnostics and enforce gates

**Files:**
- Create: `Plugins/MessageListAppKitPlugin/Sources/Diagnostics/AppKitMessageListMetrics.swift`
- Create: `Plugins/MessageListAppKitPlugin/Tests/MessageListAppKitPluginTests/AppKitMessageListPerformanceTests.swift`
- Modify: `docs/performance/message-list-baseline.md`

**Steps:**

1. Add `os_signpost` intervals for snapshot build/apply, cell configure/reuse, Markdown parse, height measure, syntax highlight, Mermaid render, and scroll hitch.
2. Build deterministic 40-, 300-, and 1,000-row fixtures.
3. Measure initial load, continuous scroll, prepend, status replacement, V2 streaming, theme change, and conversation switch.
4. Record cell count, cache hit rate, parse count, height-measure count, main-thread time, frame time, and memory plateau.
5. Fail the performance test or release checklist when section 1 gates are missed. Do not “average away” hitches; report p95, p99, and maximum.
6. Run with Instruments using Time Profiler, Core Animation, Allocations, and Leaks.
7. Commit measurements separately from tuning changes.

### Task 16: Complete disabled integration and replacement checklist

**Files:**
- Modify: `Plugins/MessageListAppKitPlugin/README.md`
- Modify: `docs/performance/message-list-baseline.md`
- Do not modify policies in the committed disabled-integration build.

**Steps:**

1. Run all package suites:

   ```bash
   swift test --package-path Plugins/MessageListAppKitPlugin
   swift test --package-path Plugins/MessageManagerPlugin
   swift build --package-path Plugins/AgentTurnRunnerPlugin
   swift build --package-path Packages/LumiFactory
   ```

2. Build the Lumi app with signing disabled and archive the build log.
3. Verify the architecture boundary:

   ```bash
   rg -n "NSHostingView|MarkdownBlockRenderer|MessageRowView" Plugins/MessageListAppKitPlugin
   ```

   Expected: no matches. `import SwiftUI` should occur only in `MessageListAppKitPlugin.swift` and `Bridge/MessageListAppKitBridge.swift`.
4. Confirm the committed new plugin policy remains `.disabled`; the old plugin remains `.alwaysOn`; normal users see no change.
5. For local manual evaluation only, make temporary uncommitted policy edits:
   - `MessageListAppKitPlugin`: `.alwaysOn`
   - `MessageListPlugin`: `.disabled`
   Never run with both chat-section plugins enabled because both use a full-height stack placement.
6. Execute the parity matrix and performance script on V1 and V2. Record every failure before replacement.
7. Replacement is authorized only when:
   - all functional parity fixtures pass;
   - `ask_user`, links, copy, attachments, errors, code, tables, and Mermaid work natively;
   - no `NSHostingView` exists;
   - performance and memory gates pass;
   - there are no scroll-position jumps during append/prepend/height correction;
   - the user explicitly approves activation.
8. Keep rollback trivial: restore old `.alwaysOn` and new `.disabled`.

## 6. Final activation plan (requires separate user approval)

After the disabled plugin has been tested and approved:

1. Change `MessageListAppKitPlugin.policy` from `.disabled` to `.alwaysOn`.
2. Change `MessageListPlugin.policy` from `.alwaysOn` to `.disabled` for one release/soak period; do not immediately delete it.
3. Run the entire test/build/performance matrix again.
4. Ship with a documented one-line policy rollback.
5. Only after a successful soak period, decide whether to remove the old package from `LumiFactory`. Removal is a separate cleanup task, not part of initial activation.

## 7. Primary risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Dynamic row heights jump during async parsing | Scroll position moves | Parse/prefetch before display, width-aware height cache, stable-ID pixel anchors |
| Reused cells install stale async results | Wrong content shown | Generation tokens/cancellation checked before every install |
| Native renderer loses provider-specific visuals | Reduced visual specialization | Preserve all diagnostics in generic error renderer; keep public native registry for future provider adapters |
| `ask_user` loses interactive behavior | Turn cannot resume | Treat native ask_user integration tests as a replacement blocker |
| Text selection conflicts with table selection | Poor UX | Non-selecting table rows, first-responder NSTextView, explicit keyboard/context-menu tests |
| Mermaid/code/table blocks dominate height work | Hitches | Dedicated bounded caches, cancellation, visible-row prefetch, signposts |
| Both plugins enabled | Two full-height message lists | Disabled committed policy and explicit manual test switch procedure |
| Theme change invalidates all content | Large synchronous relayout | Theme revision keys, offscreen cache invalidation, visible-row refresh first |

## 8. Definition of done for the disabled milestone

- `MessageListAppKitPlugin` is present in the repository and `LumiFactory` dependency graph.
- Its committed policy is `.disabled` and cannot be enabled through persisted plugin settings.
- The old plugin remains the only active message list.
- The new plugin has no `NSHostingView` and does not use the old SwiftUI message/Markdown renderers.
- All native parity, integration, reuse, layout, scroll-anchor, memory, and performance tests pass.
- Manual V1 and V2 evaluation is documented, including the exact hardware and measurements.
- Activating/replacing the old plugin remains a small, separately approved policy change.
