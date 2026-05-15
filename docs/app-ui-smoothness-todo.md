# App UI Smoothness TODO

Goal: make Lumi feel smoother in high-frequency UI paths, especially typing, chat streaming, panel switching, and theme/layout refreshes.

## Priority 0: Baseline And Measurement

- [ ] Run Instruments with SwiftUI + Time Profiler in these scenarios:
  - [ ] Quickly type slash commands in the chat input, for example `/`, `/r`, `/run`.
  - [ ] Stream a long assistant reply containing Markdown, code blocks, and tables.
  - [ ] Scroll a long chat while the last assistant message is still updating.
  - [ ] Switch ActivityBar panels, Rail tabs, BottomPanel tabs, and right sidebar sections.
  - [ ] Resize the main window and switch themes.
- [ ] Add or reuse `UIPerformanceSignpost` around these paths:
  - [ ] `CommandSuggestionVM.updateSuggestions`.
  - [ ] `MessageListView` display row construction.
  - [ ] Markdown parse and code highlight cache misses.
  - [ ] Plugin UI contribution cache invalidation/rebuild.
- [ ] Record baseline metrics:
  - [ ] Main-thread time per input keystroke.
  - [ ] Main-thread time per streaming message update.
  - [ ] SwiftUI body update hot spots.
  - [ ] Number of plugin contribution views rebuilt per panel/theme/settings change.

## Priority 1: Input Slash Command Suggestions

- [ ] Inspect `LumiApp/Plugins/ChatInputPlugin/Views/InputAreaView.swift`.
  - Risk: every text change calls `commandSuggestionViewModel.updateSuggestions(for:)`.
- [ ] Inspect `LumiApp/Core/ViewModels/CommandSuggestionVM.swift`.
  - Risk: every slash-prefixed input starts a new `Task` and awaits dynamic suggestions without canceling older tasks.
  - Risk: stale results can still publish after newer input has arrived.
  - Risk: verbose logging is enabled on a high-frequency typing path.
- [ ] Add a cancelable suggestion task.
- [ ] Add a 150-250 ms debounce before dynamic command lookup.
- [ ] Track the latest input token and discard stale async results.
- [ ] Avoid publishing `suggestions`, `isVisible`, and `selectedIndex` when the values are unchanged.
- [ ] Turn verbose logging off by default or guard it behind debug/performance logging.
- [ ] Verify:
  - [ ] Fast typing stays responsive.
  - [ ] Suggestions are correct after rapid input and deletion.
  - [ ] Keyboard navigation still works.
  - [ ] Command insertion still restores input focus.

## Priority 2: Streaming Markdown Rendering

- [ ] Inspect `Packages/MarkdownKit/Views/MarkdownBlockRenderer.swift`.
  - Risk: `.task(id: markdown)` reparses the whole changing string during streaming.
  - Existing cache helps stable content, but streaming produces many unique strings.
- [ ] Inspect `Packages/MarkdownKit/Views/HighlightedCodeView.swift`.
  - Risk: code highlight task id includes full code content, so changing code blocks can trigger repeated highlight work.
- [ ] Add a streaming-specific render mode for the active assistant message:
  - [ ] Render incomplete trailing content as plain text or lightly formatted text.
  - [ ] Parse stable completed blocks only.
  - [ ] Run full Markdown parse/highlight when the message is finalized.
- [ ] Consider chunk-level cache keys instead of full-message keys.
- [ ] Skip code highlighting while a code fence is still open.
- [ ] Verify:
  - [ ] Long Markdown streams no longer stutter.
  - [ ] Final rendered Markdown matches current output.
  - [ ] Mermaid/code/table rendering still works after completion.

## Priority 3: Chat List Derived State

- [ ] Inspect `LumiApp/Plugins/AgentChatPlugin/Chat/MessageListView.swift`.
  - Risk: body rebuilds windowed rows, display rows, last-row token, and tool-output mapping during frequent message updates.
- [ ] Move display row construction into `ChatTimelineViewModel` or a small derived-state cache.
- [ ] Update derived rows only when persisted messages, status row, loaded tool outputs, or history window limit changes.
- [ ] Keep the active streaming row isolated so the full visible row list is not rebuilt for every token.
- [ ] Avoid recomputing `toolOutputs(for:)` for rows whose tool call state has not changed.
- [ ] Verify:
  - [ ] Initial load still scrolls to bottom.
  - [ ] Manual scroll-up disables auto-follow.
  - [ ] Streaming at bottom follows without animation jitter.
  - [ ] `Load More` prepends older rows without unexpected jumps.

## Priority 4: Plugin UI Contribution Invalidations

- [ ] Inspect `LumiApp/Core/ViewModels/PluginVM.swift`.
  - Existing caches cover toolbar, status bar, panel, rail, sidebar, bottom panel, and menu bar contribution views.
  - Risk: cache invalidation is broad when plugin settings change.
- [ ] Inspect `LumiApp/Core/Views/Layout/ContentView.swift`.
  - Risk: root layout reads toolbar/sidebar/rail contribution views from a global observed object.
- [ ] Split plugin contribution state by surface:
  - [ ] Toolbar projection.
  - [ ] Status bar projection.
  - [ ] Panel/Rail/Sidebar projection.
  - [ ] Menu bar projection.
- [ ] Add precise version keys for settings, active panel icon, and contribution surface.
- [ ] Avoid clearing unrelated surface caches when only one plugin setting changes.
- [ ] Consider moving from `AnyView` contribution callbacks toward stable descriptors in a later protocol migration.
- [ ] Verify:
  - [ ] Panel switching refreshes only the active surface.
  - [ ] Status bar updates do not force toolbar/sidebar rebuilds.
  - [ ] Plugin enable/disable still updates all affected views.

## Priority 5: Visual Effects And Theme Backgrounds

- [ ] Inspect theme `makeGlobalBackground(proxy:)` implementations.
  - Risk: large blurred radial shapes can be GPU-heavy during resize and theme refresh.
- [ ] Start with `LumiApp/Plugins/ThemeDraculaPlugin/DraculaTheme.swift`.
  - It uses large `Circle` views with blur radii around 110-130.
- [ ] Add a reduced-effects path or performance mode for global backgrounds.
- [ ] Consider rasterizing static theme backgrounds per window size bucket.
- [ ] Keep global backgrounds static during continuous resize, then refresh after resize settles.
- [ ] Verify:
  - [ ] Theme appearance remains acceptable.
  - [ ] Window resizing and theme switching feel smoother.
  - [ ] No visual artifacts in light/dark themes.

## Priority 6: High-Frequency Logging

- [ ] Audit `verbose: Bool = true` in UI and input paths.
- [ ] Turn verbose logging off by default for:
  - [ ] `CommandSuggestionVM`.
  - [ ] `InputAreaView`.
  - [ ] `MessageListView` adjacent streaming paths if any logging is added.
  - [ ] `PluginVM` status bar contribution lookup logs.
- [ ] Keep expensive log argument construction behind `if Self.verbose`.
- [ ] Verify Release builds do not emit high-frequency UI logs.

## Priority 7: Input Area Layout Animation

- [ ] Inspect `InputAreaView.macEditorView`.
  - Risk: editor height changes animate during multiline input.
- [ ] Animate only meaningful height changes, for example cross-line height changes above a small threshold.
- [ ] Disable height animation during rapid typing and re-enable on settle.
- [ ] Verify:
  - [ ] Multiline input still feels polished.
  - [ ] Focus is not lost.
  - [ ] Attachment strip and command suggestion overlay keep stable positions.

## Expected Fix Order

- [ ] First patch: debounce/cancel slash command suggestion work.
- [ ] Second patch: add measurement signposts and capture baseline.
- [ ] Third patch: add streaming-specific Markdown rendering behavior.
- [ ] Fourth patch: move chat display row construction out of `MessageListView.body`.
- [ ] Fifth patch: narrow plugin contribution invalidations by surface.
- [ ] Sixth patch: reduce expensive theme background effects during resize/theme refresh.
- [ ] Seventh patch: clean up high-frequency verbose logging and input height animation.

## Success Criteria

- [ ] Fast typing in the chat input does not visibly stall.
- [ ] Long assistant Markdown streams update smoothly.
- [ ] Chat auto-follow does not jitter while streaming.
- [ ] Panel switching feels immediate after caches are warm.
- [ ] Window resize and theme switching do not produce obvious frame drops.
- [ ] Instruments shows reduced main-thread work in input, chat streaming, and plugin contribution rebuild paths.

