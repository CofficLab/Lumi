# project rag idle indexing implementation plan

> **For Codex:** implement this plan task-by-task with verification after each task.

**Goal:** Upgrade `ProjectRAGPlugin` into a production-grade background indexer that incrementally indexes known inactive projects during predicted idle windows without blocking foreground search or losing recoverable progress.

**Architecture:** Keep one serialized SQLite writer and one background indexing worker, but introduce an explicit scheduler that owns project selection, idle admission, time budgets, cancellation, retries, and lifecycle. Index work is divided into cancellable file-level slices; the current project is protected from inactive-project work, and semantic search only yields when the same project is being indexed. Existing SQLite state remains the source of truth, while scheduler state is persisted for retry/backoff and restart recovery.

**Tech Stack:** Swift 6, Swift Concurrency actors/tasks, `LumiKernel` `IdleTimeProviding`, SQLite/sqlite-vec, Swift Testing.

---

### task 1: define scheduler state and policy

**Files:**
- Create: `Plugins/ProjectRAGPlugin/Sources/Models/RAGIndexScheduling.swift`
- Create: `Plugins/ProjectRAGPlugin/Sources/Services/RAGIndexScheduler.swift`
- Test: `Plugins/ProjectRAGPlugin/Tests/RAGIndexSchedulingTests.swift`

Define value types for scheduler configuration, project candidates, retry state, and scheduling decisions. Defaults must include one worker, a 10-minute idle admission window, a bounded work slice, exponential retry backoff with a cap, and no more than one active project. Candidate ordering is: no index, stale index, oldest index, then stable path ordering. Normalize and deduplicate paths before selection, exclude the current project, reject missing/non-directory paths, and never schedule a path outside the known project list.

Write pure tests for ordering, current-project exclusion, invalid paths, retry backoff, and deterministic tie-breaking before implementing the scheduler.

### task 2: persist scheduler retry and progress metadata

**Files:**
- Modify: `Plugins/ProjectRAGPlugin/Sources/Models/RAGIndexScheduling.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGSQLiteStore.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGStore.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGService.swift`
- Test: `Plugins/ProjectRAGPlugin/Tests/ProjectRAGPluginTests.swift`

Add a small scheduler-state table keyed by normalized project path with last attempt, last success, failure count, next eligible date, and an optional interrupted marker. Migrations must be idempotent. Failed tasks must update retry state; successful indexing clears failure state. On startup, interrupted work is treated as retryable and never presented as completed. Add store tests for round-trip state, migration repeatability, and retry reset.

### task 3: make index work cancellable at file boundaries

**Files:**
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGIndexer.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGService.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Models/RAGIndexModels.swift`
- Test: `Plugins/ProjectRAGPlugin/Tests/RAGIndexerTests.swift`

Refactor the file loop to accept a bounded work budget and cancellation/checkpoint callback. Check cancellation before reading, before embedding, after embedding, and after each SQLite file transaction. Stop cleanly at a checkpoint when the budget expires; preserve completed file states and avoid updating project completion metadata for an incomplete slice. Return a result that distinguishes completed, paused, cancelled, and failed work. Add tests proving cancellation leaves completed files valid and does not mark an incomplete project as fresh.

### task 4: isolate foreground search from unrelated background indexing

**Files:**
- Modify: `Plugins/ProjectRAGPlugin/Sources/Tools/RAGCodeSearchTool.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGService.swift`
- Test: `Plugins/ProjectRAGPlugin/Tests/ProjectRAGPluginTests.swift`

Replace the global `isAnyIndexing` semantic-search guard with a same-project guard. Preserve a fast non-actor registry lookup. Ensure an inactive project being indexed does not suppress current-project keyword or semantic search. Add tests for same-project suppression and unrelated-project search availability. Keep the single SQLite writer invariant explicit; do not add concurrent database writers.

### task 5: implement the idle-aware scheduler

**Files:**
- Create: `Plugins/ProjectRAGPlugin/Sources/Services/RAGIndexScheduler.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Core/RAGPluginService.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Hooks/OnReady.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Core/RAGPluginRuntime.swift`
- Test: `Plugins/ProjectRAGPlugin/Tests/RAGIndexSchedulerTests.swift`

Implement a lifecycle-owned scheduler task. It initializes after the current-project bootstrap, snapshots known projects on each scheduling pass, and selects one inactive candidate. Before every slice it asks `IdleTimeProviding` for the configured future idle window; if the provider is unavailable, uncertain, below confidence, or returns fallback, inactive indexing is deferred. Run at utility priority, with one project at a time. Re-check current project and pause/cancellation state before every slice. On success advance to the next candidate; on failure apply persisted backoff; on cancellation preserve retryable state.

The scheduler must be cancelled on plugin reconfiguration, manual pause, and plugin teardown. Resuming must create exactly one scheduler task. Current-project startup indexing remains separate and is never blocked on an idle prediction.

### task 6: handle project changes and foreground return safely

**Files:**
- Modify: `Plugins/ProjectRAGPlugin/Sources/Hooks/OnReady.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGIndexScheduler.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Services/RAGService.swift`
- Test: `Plugins/ProjectRAGPlugin/Tests/RAGIndexSchedulerTests.swift`

Observe current-project and project-list changes, invalidate the candidate snapshot, and exclude the newly active project immediately. If a background slice is running for a project that becomes current, cancel at the next file checkpoint and prioritize the current project through the existing foreground path. Keep app activation/manual pause cancellation explicit; the idle prediction remains an admission signal, not a claim of real-time certainty.

### task 7: expose robust status and diagnostics

**Files:**
- Modify: `Plugins/ProjectRAGPlugin/Sources/Models/RAGIndexModels.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Events/RAGIndexEvents.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Views/SettingsView.swift`
- Modify: `Plugins/ProjectRAGPlugin/Sources/Views/ProjectSectionView.swift`
- Modify: `Plugins/ProjectRAGPlugin/Resources/Localizable.xcstrings`

Expose active project, scheduler state, paused state, last decision, next retry, and failure information without claiming that a project is up to date while a slice is incomplete. Keep progress notifications path-scoped. Add user-visible status for waiting for idle time, paused, retrying, interrupted, indexing, and completed.

### task 8: integration and regression verification

**Files:**
- Modify: `Plugins/ProjectRAGPlugin/Tests/ProjectRAGPluginTests.swift`
- Modify: `Plugins/ProjectRAGPlugin/Tests/RAGPureLogicTests.swift`

Add integration coverage for: current-project exclusion, inactive-project selection, no idle provider, uncertain prediction, manual pause/resume, cancellation and retry, project switch during indexing, unrelated-project semantic search, restart recovery, and stale-index ordering. Run `swift test` for `Packages/LumiKernel` and `Plugins/ProjectRAGPlugin`, then run `git diff --check` and review the final diff for scope and concurrency hazards.
