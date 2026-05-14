# UI Jank Investigation TODO

Goal: identify and verify code paths that may cause UI stalls, dropped frames, or sluggish interactions in Lumi.

## Priority 0: Establish Baseline

- [ ] Run the app with Instruments Time Profiler during these scenarios:
  - [ ] App launch with all default plugins enabled.
  - [ ] Open main workspace and switch activity bar panels.
  - [ ] Scroll a long chat with Markdown and code blocks.
  - [ ] Send a message and observe streaming/tool status updates.
  - [ ] Open menu bar popover while DeviceInfo/Network plugins are active.
- [ ] Record Main Thread Checker and SwiftUI body update hot spots.
- [ ] Add temporary signposts around high-risk paths before deeper changes.

## Priority 1: Main-Thread Database Work

- [x] Inspect `LumiApp/Core/Services/ChatHistoryService/ChatHistoryService.swift`.
  - Risk: whole service is `@MainActor`; fetch/save work runs on the UI thread.
- [ ] Profile `saveMessage(_:toConversationId:)` in `ChatHistoryMessages.swift`.
  - Risk: every save does conversation fetch, duplicate-message fetch, relationship sync, and `context.save()`.
- [x] Profile `getMessageCount(forConversationId:)`.
  - Risk: fetches message entities, converts all to `ChatMessage`, then filters in memory.
  - Fixed: replaced full fetch + conversion with SwiftData `fetchCount` filtered by conversation id and visible roles.
- [ ] Profile paginated loading and tool-output lookup.
  - Risk: large conversations or many tool outputs may block the main thread.
- [ ] Evaluate moving heavy SwiftData work to a dedicated actor/background `ModelContext`.

## Priority 2: Always-On Monitoring Timers

- [x] Inspect `Packages/DeviceMonitorKit/Sources/DeviceMonitorKit/Services/CPUService.swift`.
  - Risk: 1s timer updates CPU stats on `@MainActor`.
- [x] Inspect `Packages/DeviceMonitorKit/Sources/DeviceMonitorKit/Services/MemoryService.swift`.
  - Risk: 1s timer updates memory stats on `@MainActor`.
- [x] Inspect `Packages/DeviceMonitorKit/Sources/DeviceMonitorKit/Services/ProcessService.swift`.
  - Risk: 3s timer scans all processes on `@MainActor`.
  - Fixed: process enumeration and CPU calculations now run in a detached utility task; main actor only updates snapshots and publishes compact metrics.
- [x] Move CPU and memory sampling off the main actor.
  - Fixed: CPU tick snapshots and VM memory stats now sample in detached utility tasks; MainActor only stores snapshots and publishes values.
- [x] Inspect `LumiApp/Plugins/NetworkManagerPlugin/Services/NetworkService.swift`.
  - Risk: 1s timer samples interfaces and publishes several values on `@MainActor`.
- [x] Inspect `NetworkManagerViewModel`.
  - Risk: each view model instance owns its own slow-stats timer.
- [x] Deduplicate `NetworkManagerViewModel` instances used by network menu bar, popup, detail, dashboard, and controller.
  - Fixed: these entry points now observe a shared VM, so Wi-Fi, ping, local IP, and public IP refresh work no longer multiplies per view.
- [x] Move network interface counter sampling off the main actor.
  - Fixed: `NetworkService` now reads interface counters in a detached utility task and publishes compact speed totals on the main actor.
- [ ] Verify whether menu bar content starts monitoring even when no popover is open.
- [x] Prototype moving system sampling to background tasks and publishing only compact snapshots on main.
  - Done for `ProcessService`; CPU, memory, and network sampling remain to be measured before changing.

## Priority 3: Plugin View Aggregation In SwiftUI Body

- [x] Inspect `LumiApp/Core/ViewModels/PluginVM.swift`.
  - Risk: many `get...Views()` methods filter enabled plugins and recreate `AnyView`s repeatedly.
- [x] Inspect `ContentView.swift` toolbar and layout body.
  - Risk: toolbar, sidebar, rail, and panel availability are recomputed during body updates.
- [x] Inspect `StatusBar.swift`.
  - Verified: leading/center/trailing status views now read from `PluginVM` caches instead of recreating plugin contribution views in every body pass.
- [x] Inspect `PanelContentView.swift`, `RailView.swift`, and `BottomPanelBarView.swift`.
  - Verified: active panel, header, bottom tab, and rail content views now read from cached `PluginVM` contribution lookups.
- [x] Add caching keyed by plugin settings version and `activePanelIcon`.
  - Fixed: cached toolbar, status bar, side bar, panel, rail, bottom panel, and menu bar contribution views; caches invalidate on plugin settings changes, plugin discovery, and active panel icon changes.
- [ ] Prefer stable contribution descriptors over calling `addXXXView()` from body paths.

## Priority 4: Chat Rendering And Scrolling

- [x] Inspect `MessageListView.swift`.
  - Risk: `lastRowChangeToken` hashes last message content; streaming/status updates trigger scroll handling.
- [x] Inspect `ScrollPositionObserver`.
  - Risk: document frame changes emit metrics on every layout change.
- [x] Add dedupe/throttle to scroll metric callbacks.
  - Fixed: scroll metric callbacks now emit only when bottom/user-scroll state changes, reducing layout-change churn during streaming.
- [x] Verify whether programmatic scroll animations occur too often while streaming.
  - Fixed: same-row streaming content updates now follow the bottom without animation; new rows can still animate.
- [ ] Measure row creation cost for the 80-message window.

## Priority 5: Markdown And Code Highlighting

- [x] Inspect `MarkdownView.swift`.
  - Risk: content hash `.id(...)` forces native Markdown subtree rebuilds.
  - Fixed: removed content-hash `.id(...)` so streaming updates no longer force replacement of the entire Markdown subtree.
- [x] Inspect `MarkdownBlockRenderer.swift`.
  - Risk: `MarkdownParser.parse(markdown)` runs when Markdown changes.
- [x] Inspect `HighlightedCodeView.swift`.
  - Risk: `.task(id: "\(language):\(code)")` highlights on every changed code string.
- [x] Inspect `TreeSitterCodeHighlightProvider.swift`.
  - Risk: synchronous tree-sitter parse and `AttributedString` construction for code blocks.
- [x] Add cache keyed by content/code, language, and theme/provider id.
  - Fixed: Markdown parse results and syntax-highlighted code blocks now use bounded actor caches.
- [x] Move parsing/highlighting work off the main thread where possible.
  - Fixed: renderer tasks await cache actors instead of parsing/highlighting directly in the view update path.

## Priority 6: Root Overlays And Global Change Propagation

- [ ] Inspect root wrappers from plugins:
  - [x] `LayoutPlugin`
  - [x] `RecentProjectsPlugin`
    - Fixed: startup restore now reads recent/current project files in a utility task and only applies the snapshot on the main actor.
    - Fixed: adding a project updates `ProjectVM` from in-memory state instead of immediately reloading the recent-projects JSON on the main actor.
  - [x] `QuickFileSearchPlugin`
  - [x] `ThemeStatusBarPlugin`
  - [x] `AgentRAGPlugin`
  - [x] `ModelPreferencePlugin`
    - Fixed: project preference plist reads now run in a cancelable utility task and use a token/current-project guard before applying results.
  - [x] `LLMAvailabilityPlugin`
- [x] Verify root overlays do not trigger repeated restoration, file reads, or network/model checks.
  - Verified: `LayoutPlugin` and `ThemeStatusBarPlugin` use one-shot restore guards; `LLMAvailabilityPlugin` uses a one-shot initialization guard and background checks; `AgentRAGPlugin` now dedupes/cancels auto-index triggers; `RecentProjectsPlugin` and `ModelPreferencePlugin` now move root restore file reads off the main actor.
- [x] Inspect `RootViewContainer.swift` object-change forwarding.
  - Risk: forwarding many child VM changes may broaden SwiftUI invalidation.
  - Fixed: removed broad child `objectWillChange` forwarding from `RootViewContainer`; `RootView` now subscribes only to the concrete event publishers it needs.

## Priority 7: File/System Scans Triggered By UI

- [x] Inspect `EditorRailFileTreePlugin` file tree services.
  - Fixed: file row icons no longer query file-system resource values during SwiftUI body evaluation.
  - Fixed: directory child loading tasks are now cancelable so refresh/appearance churn cannot publish older loads after newer requests.
- [x] Inspect `QuickFileSearchPlugin` file search services.
  - Fixed: `quickOpenResults` no longer synchronously scans the project on the main actor; stale/missing indexes rebuild in the background.
  - Fixed: query matching now runs in a detached task and publishes only final results on the main actor.
- [x] Inspect `AppManagerPlugin` app scan services.
  - Fixed: related-file scans are now cancelable and only publish results for the still-selected app, avoiding stale scan work and UI result churn during rapid selection changes.
- [x] Inspect `DiskManagerPlugin` views and scan view models.
  - Fixed: Xcode, cache, and project cleaner views now only auto-scan once on first appearance; manual scan controls still force a rescan.
- [x] Inspect `AgentRAGPlugin` auto-index overlay.
  - Fixed: auto-index overlay now loads recent projects off the main actor, cancels superseded trigger tasks, dedupes unchanged candidate sets, and stops work when the overlay disappears.
- [x] Confirm scans run off main and are not triggered repeatedly by view appearance.
  - Verified for `QuickFileSearchPlugin`, `AppManagerPlugin`, `DiskManagerPlugin`, `AgentRAGPlugin`, and `EditorRailFileTreePlugin`.

## Deliverables

- [ ] Instruments trace summary with top main-thread offenders.
- [x] Ranked issue list with file/line references.
- [x] Minimal fix plan grouped by risk and expected impact.
- [ ] Regression checklist for chat scrolling, menu bar popover, panel switching, and app launch.

## Execution Log

- [x] 2026-05-14: Optimized `ProcessService` process sampling off the main actor.
- [x] 2026-05-14: Optimized chat message count with `fetchCount`.
- [x] 2026-05-14: Added plugin contribution view caches in `PluginVM`.
- [x] 2026-05-14: Deduped chat scroll metric callbacks.
- [x] 2026-05-14: Verified `Packages/DeviceMonitorKit` with `swift test`.
- [ ] 2026-05-14: Full `Lumi` scheme build is blocked by screenshot feature changes: `ScreenshotOverlay.swift` uses unavailable `CGDisplayCreateImage` on macOS SDK 26.2; temporary exclusion then fails because `ChatToolbarView` depends on `ScreenshotState`.
- [x] 2026-05-14: Deduplicated network plugin view models and moved network counter sampling off the main actor.
- [x] 2026-05-14: Moved CPU and memory sampling off the main actor; verified `Packages/DeviceMonitorKit` with `swift test`.
- [x] 2026-05-14: Added bounded actor caches for Markdown parsing and code highlighting; verified `Packages/MarkdownKit` with `swift test`.
- [x] 2026-05-14: Removed Markdown subtree force-rebuild id and reduced streaming auto-scroll animation churn.
- [x] 2026-05-14: Removed broad `RootViewContainer` object-change forwarding and replaced it with narrow `RootView` event subscriptions.
- [x] 2026-05-14: Prevented repeated DiskManager auto-scans on view reappearance.
- [x] 2026-05-14: Moved QuickFileSearch project indexing/search matching out of synchronous main-actor paths.
- [x] 2026-05-14: Added cancellation and stale-result guards for AppManager related-file scans.
- [x] 2026-05-14: Reduced repeated RAG auto-index trigger work from root overlay appearances/project changes.
- [x] 2026-05-14: Reduced EditorRail file tree body-time file-system checks and canceled superseded directory loads.
- [x] 2026-05-14: Moved RecentProjects root restore file reads off the main actor.
- [x] 2026-05-14: Moved ModelPreference project preference reads off the main actor.
