# Project RAG Resource Optimization Plan

## 1. Purpose

This document analyzes the CPU, memory, and disk costs of `ProjectRAGPlugin` during application startup and proposes a low-impact indexing architecture. The goals are incremental updates, on-demand semantic indexing, cancellation, and predictable resource usage.

This is a design document only; it does not implement the changes.

## 2. Current implementation

`ProjectRAGPlugin` is `.alwaysOn`. Its `onBoot` is empty; the work starts in `onReady`:

1. Store the kernel reference and configure the RAG database directory.
2. Initialize the local SQLite store and embedding provider.
3. Wait up to approximately five seconds for project paths to become available.
4. Collect the current project plus all entries in `kernel.project.projects`.
5. Create a background indexing task for every existing project path.

Relevant code:

- [`ProjectRAGPlugin.swift`](../Plugins/ProjectRAGPlugin/Sources/ProjectRAGPlugin.swift)
- [`OnReady.swift`](../Plugins/ProjectRAGPlugin/Sources/Hooks/OnReady.swift)
- [`RAGService.swift`](../Plugins/ProjectRAGPlugin/Sources/Services/RAGService.swift)
- [`RAGIndexer.swift`](../Plugins/ProjectRAGPlugin/Sources/Services/RAGIndexer.swift)

### 2.1 Concurrency model

`ensureIndexedBackground` creates a detached task for each project, but all tasks call the same `RAGService` actor. The expensive scan, chunking, embedding, and SQLite work is synchronous inside `ensureIndexed`, so the heavy indexing work is effectively serialized by that actor.

```text
Project A ─┐
Project B ─┼─> detached tasks ─> one RAGService actor ─> mostly serial indexing
Project C ─┘
```

This avoids stacking the full contents of multiple projects in memory, but a large indexing pass can delay other RAG actor operations, including queries.

### 2.2 Resource costs

CPU is spent on recursive directory enumeration, file reads, hashing, chunking, NaturalLanguage embedding, and SQLite/vector writes. The first index is the most expensive case.

Memory is bounded better than a whole-project load, but the current implementation still holds the project file-path list, indexed-file state map, one complete file, all chunks for that file, and all embeddings for that file. Files are limited to 1.5 MB and generated/build/dependency directories are excluded in [`RAGFileScanner.swift`](../Plugins/ProjectRAGPlugin/Sources/Utils/RAGFileScanner.swift).

The current design has six main weaknesses:

1. All saved projects are scheduled at startup instead of only the active project.
2. Changes are not driven by file events; stale projects require another directory scan.
3. Embeddings are generated eagerly for every chunk.
4. There is no idle, foreground, low-power, or system-pressure policy.
5. Pause, resume, cancellation, and resource budgets are not first-class concepts.
6. Indexing and querying share one actor, so long synchronous indexing can create queueing.

## 3. Patterns used by similar tools

VS Code/Copilot-style workspace search supports `.gitignore`, `files.exclude`, and `search.exclude`, while continuing to provide text search, grep, and language intelligence before semantic indexing finishes. Indexing is not a prerequisite for basic search. See [VS Code workspace context](https://code.visualstudio.com/docs/agents/reference/workspace-context).

IntelliJ supports excluded directories, unloading modules, pausing project analysis, and shared indexes for large projects. These controls reduce the amount of work done locally and let users trade completeness for responsiveness. See [IntelliJ project analysis](https://www.jetbrains.com/help/idea/project-analysis.html) and [shared indexes](https://www.jetbrains.com/help/idea/shared-indexes.html).

Common code-assistant patterns are:

- active-project-first indexing;
- user-configurable exclusions;
- filesystem-event-driven incremental updates;
- keyword/path/symbol search as a fallback;
- embedding only candidate files or chunks;
- one low-priority, cancellable background worker.

## 4. Target architecture

```text
Project opened
    │
    ├─ lightweight file manifest (path, size, mtime, hash)
    │
    ├─ filesystem watcher
    │       └─ dirty-file queue + debounce
    │
    ├─ low-priority IndexScheduler
    │       ├─ runs while idle
    │       ├─ pauses while typing or using tools
    │       ├─ pauses in low-power/background states
    │       └─ one worker + cancellation
    │
    ├─ lightweight retrieval
    │       ├─ path/file name
    │       ├─ keyword/grep
    │       └─ symbols
    │
    └─ semantic retrieval
            └─ embed only candidate files/chunks
```

## 5. Phased optimization plan

### Phase 0: Measure before changing behavior

Add metrics for each project: scan time, files discovered/read/skipped, chunks, embedding time, SQLite write time, peak batch size, and per-file duration. Log task start, pause, resume, cancellation, completion, and failure reasons. Expose the active task, progress, and index state in the RAG settings view.

Suggested baseline targets:

| Metric | Target |
|---|---:|
| Startup thread blocking | 0 ms |
| Default startup scope | One active project |
| Default embedding batch | 16 chunks |
| Cancellation interval | At most one batch |
| Query availability | Not blocked by a full index pass |

### Phase 1: Restrict startup scope

Default to the current project only. Queue other projects when the user switches to them, searches them, or explicitly selects “Build index”. Add settings for:

- index current project on launch (default on);
- index all known projects on launch (default off);
- enable background indexing (default on, subject to scheduling).

This is the highest-value, lowest-risk change.

### Phase 2: Add idle and low-priority scheduling

Introduce `RAGIndexScheduler` instead of creating detached tasks directly from `OnReady`:

1. Delay indexing 10–30 seconds after startup.
2. Start or resume after 3–5 seconds of user idle time.
3. Pause before starting a new batch while the user is typing, scrolling, or running an Agent tool.
4. Pause or reduce activity when the app is in the background.
5. Pause on low battery or high system pressure.
6. Use `.utility` task priority.
7. Keep one indexing worker by default.

Use an explicit state machine:

```text
idle → scheduled → running → paused
                         ├──→ cancelled
                         ├──→ completed
                         └──→ failed
```

### Phase 3: Make updates filesystem-driven

Use macOS filesystem events to maintain a dirty-file queue. Debounce events for 1–2 seconds, re-check mtime/size/hash, and process only affected files.

```text
filesystem event
  ↓
dirtyFiles
  ↓
1–2 second debounce
  ↓
mtime/size/hash validation
  ↓
index changed files only
```

Handle additions, modifications, deletions, and renames. Keep the existing mtime/content-hash check as a safety net for missed events and as a low-frequency reconciliation path.

### Phase 4: Bound embedding memory

The current flow is “all chunks for one file → all embeddings → one write”. Change it to small batches:

```text
read file
  ├─ create batch 1 (default 16 chunks)
  ├─ embed
  ├─ write SQLite
  ├─ check pause/cancellation
  └─ continue
```

The file must not be marked complete until all batches commit. Cancellation must roll back or remove the partial file index. The batch size should be configurable as an internal resource budget. Recommended defaults are 16 chunks per embedding batch and no more than 32 chunks retained in the active in-memory window.

### Phase 5: Use layered retrieval and lazy semantic indexing

Provide three retrieval layers:

1. file name, path, and extension matching;
2. keyword/grep search;
3. embedding search over candidate files or chunks.

This keeps the Agent useful while the semantic index is incomplete and changes startup behavior from “embed the entire project” to “embed only content needed for semantic search”.

### Phase 6: Decouple query and indexing paths

Long-term, separate responsibilities into:

- `RAGIndexStore`: index writes;
- `RAGQueryStore`: query reads;
- `RAGIndexScheduler`: prioritization and resource policy;
- `RAGService`: public API and lifecycle coordination.

The first iteration may keep one SQLite file, but query work should not wait behind a long synchronous project loop. Index work should yield between files or batches, query priority should be higher, and failed writes must not invalidate the last completed file index.

## 6. Resource budget

Make resource policy explicit instead of relying only on task priority:

| Resource | Default | Aggressive | Power saving |
|---|---|---|---|
| Projects | Current project | All projects | Active project area |
| Workers | 1 | 1 | 1 |
| Embedding batch | 16 | 32 | 4 |
| Startup delay | 15 s | 5 s | 60 s |
| File-event debounce | 1 s | 0.5 s | 3 s |
| Low battery | Pause new work | Continue | Pause |
| User activity | Pause batch | Continue | Pause |

Do not add workers simply to shorten first indexing. For local SQLite, NaturalLanguage embedding, and laptop hardware, one worker is easier to keep responsive and power-efficient.

## 7. Architecture decisions

### ADR-1: Index only the active project by default

**Decision:** Start with the active project; defer other projects until opened, searched, or explicitly requested.

**Reason:** Saved project lists can contain multiple large repositories, while startup indexing of inactive projects has no immediate user value.

**Trade-off:** The first search of another project may wait for indexing.

**Mitigation:** Provide keyword-search fallback and an explicit pre-index action.

### ADR-2: Use one background worker

**Decision:** Use one index worker by default.

**Reason:** It reduces CPU, disk, and SQLite contention, and matches the current actor-serialized implementation.

**Trade-off:** A full initial index may take longer.

**Mitigation:** Reduce the amount of work through filesystem events and lazy embeddings.

### ADR-3: Prefer filesystem events with reconciliation fallback

**Decision:** Use file events for the normal path; use low-frequency reconciliation scans after startup, event failures, or database recovery.

**Reason:** Avoid re-enumerating the whole project for every stale-index check.

**Trade-off:** Watcher lifecycle, missed events, bulk changes, and renames need careful handling.

**Mitigation:** Retain mtime/hash validation and provide manual rebuild.

### ADR-4: Embed and write in cancellable batches

**Decision:** Generate embeddings and write them in small batches, checking pause/cancellation after every batch.

**Reason:** Bound peak memory and let foreground work preempt background work quickly.

**Trade-off:** Transaction and partial-state handling become more complex.

**Mitigation:** Track file-level temporary state and commit final index state only after the file completes.

## 8. Risks and mitigations

### Missed filesystem events

Use low-frequency reconciliation, project-open validation, and a manual rebuild action.

### Crash during indexing

Use file-level transactions, temporary state, and startup cleanup so partial data is never reported as a complete index.

### Incomplete search results

Show index status and fall back to keyword/path search while semantic indexing is incomplete.

### Low task priority is not a hard CPU limit

Combine `.utility` priority with one worker, explicit pause rules, and small batches.

### Over-exclusion hides useful files

Make exclusions visible and editable. When results are empty, indicate whether matching paths may have been excluded.

## 9. Implementation order

### First release: low-risk improvements

1. Index only the current project by default.
2. Add startup delay and `.utility` priority.
3. Add pause/cancel state and settings.
4. Add CPU, memory, file-count, and duration metrics.

### Second release: reduce recurring work

1. Add filesystem watching.
2. Add dirty-file queue and debounce.
3. Change embedding to small batches.
4. Prevent long index passes from blocking queries.

### Third release: reduce first-index cost

1. Add keyword/symbol-first layered retrieval.
2. Make embeddings on-demand.
3. Add project and directory exclusion configuration.
4. Evaluate shared or pre-generated indexes.

## 10. Acceptance criteria

- Startup creates an index task only for the active project by default.
- No task is created when there is no valid project path.
- Background indexing does not noticeably block editing or the main UI.
- Users can pause, resume, and cancel indexing.
- Editing one file does not trigger project-wide embedding regeneration.
- Peak memory for a large file is bounded by the batch policy.
- Agent keyword/path search remains available before semantic indexing completes.
- Relaunching the app recovers or cleans up unfinished indexing work.
- Activity Monitor and internal logs expose CPU peak, memory peak, and indexing duration.

