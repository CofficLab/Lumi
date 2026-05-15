# CodeReview Plugin TODO

## Goal

Build a Lumi plugin that reviews current Git changes, reports actionable issues, and later helps generate PR descriptions or apply safe fixes.

## Phase 0: Scope and Integration

- [x] Confirm MVP review scopes:
  - [x] staged changes
  - [x] unstaged changes
  - [x] all uncommitted changes
- [x] Defer branch comparison until the MVP is stable.
- [ ] Reuse existing plugin extension points:
  - [x] `agentToolFactories()` for review tools
  - [ ] `addStatusBarTrailingView(activeIcon:)` for the status entry
  - [ ] SwiftUI popover for the report view
- [x] Reuse existing Git infrastructure instead of shelling out first:
  - [x] Prefer `GitService.getDiff(path:staged:file:)`
  - [x] Add missing GitService support only if required by review scope
- [x] Reuse existing LLM infrastructure:
  - [ ] Use `RootContainer.shared.llmService` from UI/service flows
  - [x] Use `SuperAgentToolEnvironment.llmService` from tool flows
  - [x] Use `RootContainer.shared.agentSessionConfig.getCurrentConfig()` for the active model config

## Phase 1: Models

- [x] Create `LumiApp/Plugins/CodeReviewPlugin/Models/ReviewReport.swift`.
- [x] Define `ReviewReport`:
  - [x] `id`
  - [x] `repositoryPath`
  - [x] `scope`
  - [x] `baseCommitHash`
  - [x] `diffStats`
  - [x] `overallScore`
  - [x] `summary`
  - [x] `issues`
  - [x] `suggestions`
  - [x] `createdAt`
- [x] Define `ReviewIssue`:
  - [x] `id`
  - [x] `severity`
  - [x] `category`
  - [x] `file`
  - [x] `line`
  - [x] `range`
  - [x] `description`
  - [x] `rationale`
  - [x] `fixSuggestion`
  - [x] `suggestedPatch`
  - [x] `confidence`
- [x] Define `ReviewSeverity`:
  - [x] `critical`
  - [x] `warning`
  - [x] `info`
- [x] Define `ReviewCategory`:
  - [x] bug
  - [x] security
  - [x] performance
  - [x] style
  - [x] test
  - [x] maintainability
- [x] Define `ReviewScope`:
  - [x] staged
  - [x] unstaged
  - [x] allUncommitted
- [x] Define `DiffStats`:
  - [x] files changed
  - [x] insertions
  - [x] deletions

## Phase 2: Diff Analysis

- [x] Create `LumiApp/Plugins/CodeReviewPlugin/Services/ReviewAnalyzer.swift`.
- [ ] Resolve the active project path from `ProjectVM` in UI flows.
- [x] Accept an explicit path argument in tool flows.
- [x] Detect non-Git repositories and return a user-facing error.
- [x] Load staged diff through `GitService`.
- [x] Load unstaged diff through `GitService`.
- [x] Merge staged and unstaged summaries for `allUncommitted`.
- [x] Compute diff stats.
- [x] Collect changed file paths.
- [x] Collect project context:
  - [x] primary languages
  - [x] detected frameworks
  - [ ] test framework hints
  - [x] relevant package manifests
- [x] Load project rules:
  - [x] `.agent/rules/`
  - [x] `.agents/rules/` if present
  - [ ] other existing Lumi agent rules if applicable
- [ ] Add diff size limits:
  - [x] maximum total diff lines
  - [ ] maximum per-file diff lines
  - [x] truncation summary
  - [x] skipped file list

## Phase 3: Review Engine

- [x] Create `LumiApp/Plugins/CodeReviewPlugin/Services/ReviewEngine.swift`.
- [x] Build a deterministic review prompt.
- [x] Include project context, rules, diff stats, and diff content.
- [x] Ask the model for strict JSON output.
- [x] Require every issue to include:
  - [x] severity
  - [x] category
  - [x] file
  - [x] line or range when possible
  - [x] concrete rationale
  - [x] actionable fix suggestion
  - [x] confidence score
- [x] Parse the LLM response into `ReviewReport`.
- [x] Validate parsed issues:
  - [x] known severity
  - [x] known category
  - [x] file exists in changed files
  - [x] confidence is within range
- [x] Downgrade low-confidence findings to `info`.
- [x] Handle malformed model output with a recoverable error.
- [ ] Add cancellation support for long reviews.
- [x] Add a no-changes result.

## Phase 4: Report Store

- [x] Create `LumiApp/Plugins/CodeReviewPlugin/Services/ReviewReportStore.swift`.
- [x] Implement the store as an actor.
- [x] Persist reports as JSON cache.
- [x] Use a stable cache location under app support or existing Lumi cache conventions.
- [x] Keep latest report per repository and scope.
- [ ] Add cleanup for old reports.
- [x] Expose state needed by UI:
  - [x] idle
  - [x] reviewing
  - [x] completed
  - [x] failed
  - [x] issue counts by severity

## Phase 5: Agent Tools

- [x] Create `LumiApp/Plugins/CodeReviewPlugin/Tools/RunReviewTool.swift`.
- [x] Register `run_review`.
- [x] Support arguments:
  - [x] `path`
  - [x] `scope`
  - [x] optional `file`
- [x] Return a structured text summary with:
  - [x] score
  - [x] issue counts
  - [x] critical issues
  - [x] warnings
  - [x] report id
- [x] Mark `run_review` as low-risk/read-only.
- [ ] Create `LumiApp/Plugins/CodeReviewPlugin/Tools/ApplySuggestionTool.swift` later.
- [ ] For `apply_suggestion`, require:
  - [ ] report id
  - [ ] suggestion id
  - [ ] file context validation
  - [ ] patch preview
  - [ ] explicit user permission
- [ ] Do not enable automatic patch application in MVP.

## Phase 6: Status Bar UI

- [ ] Create `LumiApp/Plugins/CodeReviewPlugin/Views/ReviewStatusBarView.swift`.
- [ ] Show nothing when no project or no Git repository is active.
- [ ] Show review entry when there are uncommitted changes.
- [ ] Show reviewing state while analysis is running.
- [ ] Show issue count after review completes.
- [ ] Use severity color states:
  - [ ] critical
  - [ ] warning
  - [ ] info
  - [ ] clean
- [ ] Keep layout consistent with existing status bar plugins.
- [ ] Use `StatusBarHoverContainer` for the popover.

## Phase 7: Report Popover

- [ ] Create `LumiApp/Plugins/CodeReviewPlugin/Views/ReviewReportPopover.swift`.
- [ ] Show report summary and score.
- [ ] Show diff stats.
- [ ] Group findings by severity.
- [ ] Show file and line metadata for every issue.
- [ ] Show fix suggestions in a readable format.
- [ ] Add a rerun review action.
- [ ] Add copy report action.
- [ ] Add open file action if existing editor navigation APIs are available.
- [ ] Add apply fix UI only after safe patch validation exists.

## Phase 8: Plugin Entry

- [x] Create `LumiApp/Plugins/CodeReviewPlugin/CodeReviewPlugin.swift`.
- [x] Define plugin metadata:
  - [x] id
  - [x] display name
  - [x] description
  - [x] icon
  - [x] order
  - [x] enabled/configurable behavior
- [x] Register tool factory.
- [ ] Register status bar view.
- [x] Initialize shared store/service dependencies.
- [ ] Add localization file if user-facing strings need localization.

## Phase 9: PR Description Support

- [ ] Decide whether PR description generation belongs in CodeReviewPlugin or GitHub tools.
- [ ] Generate PR title and body from:
  - [ ] diff
  - [ ] commit log
  - [ ] review report
  - [ ] project rules
- [ ] Support conventional sections:
  - [ ] summary
  - [ ] changes
  - [ ] tests
  - [ ] risks
  - [ ] review notes
- [ ] Keep GitHub API integration out of MVP unless reused from existing GitHub tools.

## Phase 10: Tests

- [ ] Add unit tests for review models.
- [ ] Add unit tests for LLM JSON parsing.
- [ ] Add unit tests for confidence downgrading.
- [ ] Add unit tests for diff size truncation.
- [ ] Add tool tests for `run_review`.
- [ ] Add store persistence tests.
- [ ] Add UI smoke tests if the project has existing SwiftUI test patterns.
- [ ] Add regression test for no changes.
- [ ] Add regression test for malformed LLM output.

## Technical Decisions

- [ ] Prefer existing `GitService` and `LibGit2Swift` over direct `git diff` process calls.
- [ ] Limit MVP review scope to current uncommitted changes.
- [ ] Store reports in local JSON cache.
- [ ] Build LLM context from diff, project rules, and detected tech stack.
- [ ] Treat automatic fix application as high-risk and ship it after review/reporting is stable.

## Risks

- [ ] Large diff can exceed model context.
  - [ ] Add file and total diff limits.
  - [ ] Add truncation summaries.
  - [ ] Consider chunked review later.
- [ ] Model may produce false positives.
  - [ ] Add confidence scoring.
  - [ ] Downgrade low-confidence issues.
  - [ ] Make every finding explainable and actionable.
- [ ] Patch application can corrupt user changes.
  - [ ] Require context validation.
  - [ ] Require preview.
  - [ ] Require explicit permission.
- [ ] Privacy expectations can be unclear.
  - [ ] Clearly indicate that configured LLM providers may receive diff content.
  - [ ] Add a local-only mode only if local model support is good enough.

## MVP Done Criteria

- [ ] User can run code review for staged or unstaged changes.
- [ ] The review uses the active Lumi model configuration.
- [ ] The review report is parsed into structured Swift models.
- [ ] The latest report is persisted locally.
- [ ] The status bar shows review state and issue counts.
- [ ] The popover displays grouped, actionable findings.
- [ ] No automatic code modification happens without explicit confirmation.
- [ ] Tests cover parsing, diff handling, and the read-only tool path.
