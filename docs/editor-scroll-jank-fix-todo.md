# Editor Scroll Jank Fix TODO

Goal: reduce visible stutter while scrolling the editor by removing per-scroll-tick main-thread state churn, deduplicating viewport publications, and deferring persistence work until scrolling settles.

## Current Diagnosis

- Primary hot path:
  - `Packages/EditorService/Sources/EditorService/Editor/ScrollCoordinator.swift`
  - `publishViewportObservation` runs on every `NSView.boundsDidChangeNotification`.
  - Each scroll tick calls `EditorState.applyScrollObservation`, computes `visibleTextRange`, maps offsets to lines, and publishes viewport ranges.
- State amplification:
  - `EditorState.applyScrollObservation` goes through `applyInteractionUpdate -> syncActiveSessionState`.
  - `syncActiveSessionState` builds an `EditorSession` snapshot and may call `currentFoldingState`.
  - `currentFoldingState` rebuilds `LineOffsetTable(content: $0.string)` while scrolling when folding is enabled.
- Duplicate scroll propagation:
  - `TextViewController+Lifecycle.swift` posts `scrollPositionDidUpdateNotification` on every scroll.
  - `SourceEditor+Coordinator.swift` writes the same scroll position back through `SourceEditorState`.
  - `ScrollCoordinator` also writes scroll state into `EditorState`, so one scroll event has two state paths.
- Viewport/highlight churn:
  - `VisibleRangeProvider.visibleTextChanged` rebuilds visible `IndexSet` on each scroll event and triggers highlight invalid range checks.
  - `SourceEditorView` reacts to `viewportRenderLineRange` changes and clears transient runtime providers.
- LSP scheduling overhead:
  - `LSPCoordinator.installViewportObservers` creates a MainActor task on every bounds/frame notification, even though actual semantic refresh is debounced.

## Phase 0: Baseline And Instrumentation

- [ ] Add temporary signposts around editor scroll paths:
  - [ ] `ScrollCoordinator.publishViewportObservation`.
  - [ ] `EditorState.applyScrollObservation`.
  - [ ] `EditorState.applyViewportObservation`.
  - [ ] `EditorState.syncActiveSessionState`.
  - [ ] `EditorState.currentFoldingState`.
  - [ ] `VisibleRangeProvider.visibleTextChanged`.
  - [ ] `SourceEditor.Coordinator.textControllerScrollDidChange`.
- [ ] Profile with Instruments Time Profiler while scrolling:
  - [ ] Small file, minimap off, folding off.
  - [ ] Small file, minimap on, folding on.
  - [ ] Medium file over 1 MB.
  - [ ] Large file over 10 MB.
  - [ ] File with many folds and diagnostics.
- [ ] Record baseline metrics:
  - [ ] Main-thread time per scroll tick.
  - [ ] Number of `activeSession.applySnapshot` calls per second while scrolling.
  - [ ] Number of `viewportRenderLineRange` publishes per second.
  - [ ] Number of `LineOffsetTable` rebuilds per second.
  - [ ] Number of semantic-token viewport tasks created per second.

## Phase 1: Remove Duplicate Scroll State Path

- [ ] Decide single owner for editor scroll persistence.
  - Preferred: `ScrollCoordinator` owns viewport observation and scroll persistence.
  - `SourceEditorState.scrollPosition` remains for programmatic restore only, not continuous live scroll mirroring.
- [ ] Stop posting `TextViewController.scrollPositionDidUpdateNotification` for every `boundsDidChange`.
  - Keep notification only for explicit programmatic scroll or remove listener if unused.
- [ ] Update `SourceEditor.Coordinator.textControllerScrollDidChange` so it no longer writes every scroll point into `SourceEditorState`.
- [ ] Verify session restore still restores scroll position via `EditorSessionController.restoreScrollState`.
- [ ] Add tests or targeted assertions for:
  - [ ] Manual scrolling does not mutate `SourceEditorState.scrollPosition` every tick.
  - [ ] Session restore still applies stored scroll origin.
  - [ ] Programmatic scroll-to-find or scroll-to-cursor behavior still works.

## Phase 2: Throttle Session Scroll Persistence

- [ ] Split `ScrollCoordinator.publishViewportObservation` into two responsibilities:
  - [ ] Lightweight viewport line observation for features that need live visible line updates.
  - [ ] Debounced scroll persistence for session state.
- [ ] Add a scroll-settle debounce in `ScrollCoordinator`.
  - Suggested delay: 120-200 ms after last bounds change.
  - On settle, call a dedicated `EditorState.persistScrollObservation(viewportOrigin:)`.
- [ ] Make `EditorState.applyScrollObservation` cheap or replace it:
  - [ ] For live scroll, avoid `applyInteractionUpdate`.
  - [ ] For persisted scroll, update only `activeSession.scrollState` after debounce.
- [ ] Avoid rebuilding full session snapshots solely for scroll position.
  - [ ] Add a narrow method on `EditorSession` or `EditorSessionController` to update `scrollState`.
  - [ ] Fire `onActiveSessionChanged` only on debounced persisted scroll changes.
- [ ] Define equality tolerance for scroll origin.
  - Suggested: ignore changes below 0.5 px to avoid fractional churn.

## Phase 3: Deduplicate Viewport Line Publications

- [ ] Add cached last viewport observation to `ScrollCoordinator`:
  - [ ] Last visible text range.
  - [ ] Last visible line range.
  - [ ] Last render line range.
  - [ ] Last total line count.
- [ ] Only call `EditorState.applyViewportObservation` when line range or total line count changes.
- [ ] Add `EditorState.applyViewportObservation` guards:
  - [ ] Assign `viewportVisibleLineRange` only when changed.
  - [ ] Assign `viewportRenderLineRange` only when changed.
- [ ] Avoid calling `state.handleViewportRuntimeTransition` unless `viewportRenderLineRange` actually changes.
- [ ] Confirm `SourceEditorView.onChange(of: state.viewportRenderLineRange)` no longer fires for pure pixel scroll inside the same line band.
- [ ] Add tests for viewport dedupe:
  - [ ] Pixel scroll that does not cross line boundaries does not publish a new viewport range.
  - [ ] Scrolling across lines publishes exactly one changed range per line-band change.
  - [ ] Resize still publishes viewport changes.

## Phase 4: Remove Folding Work From Scroll Tick

- [ ] Stop calling `currentFoldingState()` from generic `syncActiveSessionState` during scroll-only updates.
- [ ] Capture folding state only on folding mutations and document/session changes:
  - [ ] Fold/unfold command.
  - [ ] Folding range provider update.
  - [ ] File switch.
  - [ ] Save/session persistence checkpoint.
- [ ] Cache `LineOffsetTable` per document content revision.
  - Reuse existing `contentLineTable` style where possible.
  - Invalidate only when `state.content` changes.
- [ ] Add a narrow scroll-state sync path that preserves existing `activeSession.foldingState`.
- [ ] Verify folded lines remain restored after:
  - [ ] Manual scroll.
  - [ ] File switch away and back.
  - [ ] App relaunch/session restore.

## Phase 5: Reduce Highlight Visible-Range Churn

- [ ] Add dedupe to `VisibleRangeProvider.visibleTextChanged`.
  - [ ] Skip delegate notification if computed `visibleSet` is unchanged.
  - [ ] Consider line-band or range-based comparison before constructing a large `IndexSet`.
- [ ] Avoid unioning minimap visible range when minimap is hidden or disabled by large-file policy.
- [ ] Consider throttling visible highlight refresh during continuous scroll.
  - Live syntax already exists for previously highlighted text; newly visible text can be highlighted after a short delay if needed.
- [ ] Verify no visual regressions:
  - [ ] New visible lines receive syntax highlighting after scroll.
  - [ ] Semantic token provider can still update visible text.
  - [ ] Document highlight overlays are cleared when cursor leaves rendered viewport.

## Phase 6: Reduce LSP Viewport Observer Overhead

- [ ] Replace per-notification `Task { @MainActor in scheduleViewportRefresh() }` in `LSPCoordinator` with a direct main-queue observer callback.
- [ ] Add viewport-change significance check before scheduling semantic token refresh.
  - Reuse `LSPViewportScheduler.hasSignificantViewportChange` or add a semantic-token-specific threshold.
- [ ] Ensure semantic token refresh is not scheduled when:
  - [ ] Semantic tokens are disabled by `largeFileMode`.
  - [ ] The visible line range did not significantly change.
  - [ ] The editor is not focused or document URI is nil.
- [ ] Add tests for scheduler behavior:
  - [ ] Rapid scroll cancels previous pending refresh.
  - [ ] Small pixel scroll does not schedule semantic refresh.
  - [ ] Scrolling to a new viewport schedules one refresh after debounce.

## Phase 7: Minimap And Gutter Follow-Up

- [ ] Measure gutter draw cost separately after state churn is reduced.
- [ ] If gutter remains hot:
  - [ ] Limit invalidation to the visible gutter rect instead of `needsDisplay = true`.
  - [ ] Cache CTLine instances for line numbers by digit string and font.
  - [ ] Avoid `updateWidthIfNeeded` on every display invalidation unless line count digit width changed.
- [ ] Measure minimap follow cost separately.
- [ ] If minimap remains hot:
  - [ ] Disable live minimap scroll syncing during fast scroll and update on animation frame or debounce.
  - [ ] Avoid minimap `layoutLines()` during scroll unless content or size changes.
  - [ ] Disable minimap automatically for medium files if profiling shows it is still expensive.

## Phase 8: Verification

- [ ] Run unit tests:
  - [ ] `swift test` in `Packages/EditorKernel`.
  - [ ] `swift test` in `Packages/EditorService` if package tests are available.
  - [ ] `swift test` in `Packages/LumiCodeEditSourceEditor` if dependencies resolve locally.
- [ ] Run targeted app verification:
  - [ ] Open a small Swift file and scroll with minimap on/off.
  - [ ] Open a medium file and scroll quickly.
  - [ ] Open a large file and verify large-file feature gates still apply.
  - [ ] Fold/unfold regions, scroll, switch files, and return.
  - [ ] Use find result navigation and verify scroll-to-result still works.
  - [ ] Use jump-to-definition and verify scroll/cursor restoration still works.
  - [ ] Verify hover, code action, diagnostics, semantic tokens, inlay hints, and document highlights still update after scrolling settles.
- [ ] Re-run Instruments after changes and compare against baseline.
- [ ] Remove temporary signposts or guard them behind the existing performance logging mechanism.

## Expected Fix Order

- [ ] First patch: remove duplicate `SourceEditorState.scrollPosition` live mirroring.
- [ ] Second patch: debounce session scroll persistence and avoid full session snapshot work on scroll.
- [ ] Third patch: dedupe viewport line/range publications.
- [ ] Fourth patch: remove folding-state capture from scroll-only updates and cache line tables.
- [ ] Fifth patch: dedupe highlight visible-range notifications.
- [ ] Sixth patch: reduce LSP observer task churn.
- [ ] Seventh patch: profile gutter/minimap and optimize only if they remain hot.

## Success Criteria

- [ ] Continuous editor scrolling no longer triggers `activeSession.applySnapshot` every frame.
- [ ] `LineOffsetTable(content:)` is not rebuilt from scroll-only events.
- [ ] `viewportRenderLineRange` publishes only when render line range changes.
- [ ] Semantic token viewport refresh scheduling is bounded during rapid scroll.
- [ ] Gutter/minimap updates remain visually correct.
- [ ] Scroll position restore still works after file switch and app relaunch.
- [ ] Fast scrolling feels smooth on normal and medium files.
