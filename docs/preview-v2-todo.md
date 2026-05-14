# Preview V2 TODO

## Context

Preview V2 has already added project preview indexing, incremental index refresh, background prewarm, entry cache tracking, syntax preflight caching, and an incremental build path for preview start.

Further optimization should avoid blind tuning. The next work should make the real preview startup path measurable, then use those measurements to choose which part to improve.

## Priority 1: Startup Timing Diagnostics

- [x] Split one real Preview V2 start into timing stages:
  - syntax preflight
  - build planning
  - build or build cache reuse
  - preview entry cache lookup
  - preview entry generation
  - host acquire or warm host reuse
  - entry load in host
  - first frame/image availability
  - live window sync, when live mode is used
- [x] Store the latest timing breakdown on the preview session.
- [x] Surface the timing breakdown in V2 diagnostics.
- [x] Add logs that include preview id, source file, cache hit flags, and stage durations.
- [x] Use these timings to identify whether the bottleneck is build, entry generation, host startup, host load, or live window sync.

## Priority 2: Direct Prewarm Result Reuse

- [x] Track recent successful prewarm results by preview fingerprint.
- [x] Store enough metadata to attempt direct reuse:
  - entry URL
  - build strategy
  - entry variant
  - source file fingerprint
  - configuration fingerprint
- [x] On real Start, check the recent prewarm result before recalculating the entry path.
- [x] Fall back to the current cache lookup/build path if the prewarm result is stale or missing.
- [x] Record when Start was served by a direct prewarm result.

## Priority 3: Host Lifecycle Policy

- [ ] Define a clear V2 host lifecycle:
  - keep one warm host while Lumi is active
  - do not destroy the host when switching to files without previews
  - release host on project close, memory pressure, or long idle timeout
- [ ] Add an idle timeout policy for warm hosts.
- [ ] Add diagnostics for host state:
  - cold
  - warming
  - idle
  - acquired
  - recycled
- [ ] Verify Live preview does not appear above other apps while preserving embedded preview visibility inside Lumi.

## Priority 4: Project Preview Ranking

- [ ] Improve project prewarm candidate ordering with weighted signals:
  - current file
  - same directory as current file
  - recently opened files
  - recently successful preview files
  - files with frequent preview starts
- [ ] Persist lightweight recent-preview history per project.
- [ ] Avoid repeatedly prewarming previews that failed recently unless the source file changed.
- [ ] Add diagnostics that explain why a preview candidate was selected.

## Priority 5: Validation

- [ ] Add focused tests for prewarm result reuse and stale invalidation.
- [ ] Add tests for project preview ranking.
- [ ] Add tests for syntax preflight cache invalidation by file mtime/size.
- [ ] Manually verify these scenarios:
  - first Preview V2 start after Lumi launch
  - switching between two files with previews
  - switching from a preview file to a file without `#Preview`
  - editing without saving
  - saving after editing
  - returning to a recently prewarmed preview
