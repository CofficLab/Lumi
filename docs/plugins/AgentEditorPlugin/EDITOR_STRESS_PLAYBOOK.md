# AgentEditorPlugin Stress Playbook

## Purpose

This playbook defines repeatable manual validation scenarios for the editor kernel after structural changes. It is intentionally command- and scenario-oriented so the team can run the same checks before and after refactors.

## Preconditions

- Use the `Lumi` scheme.
- Prefer `DISABLE_SWIFTLINT=1` for regression/test runs unless SwiftLint package plugin behavior is explicitly under inspection.
- Run on macOS with a clean app launch when validating UI-heavy scenarios.

## Core Regression Commands

### Full regression

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO
```

### Kernel-focused suites

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/EditorSessionTests \
  -only-testing:LumiTests/EditorSessionStoreTests \
  -only-testing:LumiTests/EditorSelectionStabilityTests \
  -only-testing:LumiTests/EditorUndoManagerTests
```

### Runtime / large-file / viewport suites

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/LargeFileModeTests \
  -only-testing:LumiTests/LSPViewportSchedulerTests \
  -only-testing:LumiTests/EditorRuntimeModeControllerTests \
  -only-testing:LumiTests/EditorOverlayControllerTests
```

### Input / transaction / multi-cursor suites

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/EditorInputCommandControllerTests \
  -only-testing:LumiTests/EditorTextInputControllerTests \
  -only-testing:LumiTests/EditorTransactionControllerTests \
  -only-testing:LumiTests/EditorMultiCursorWorkflowControllerTests
```

### Bridge-layer suites

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/TextViewBridgeTests \
  -only-testing:LumiTests/SourceEditorAdapterTests \
  -only-testing:LumiTests/SourceEditorViewBridgeTests
```

## Manual Stress Scenarios

### 1. Large file open latency

- Open a small source file `< 1k lines`.
- Open a medium source file `10k-30k lines`.
- Open a large source file `100k+ lines` or a file that triggers truncation / large-file mode.
- Record:
  - time to first render
  - time to editable cursor
  - whether minimap/folding/highlighting were gated as expected

### 2. Long-line protection

- Open a file containing at least one very long line.
- Confirm syntax/highlight gating behavior changes predictably.
- Scroll across the long line and verify hover/code action/signature overlays do not thrash or stall.

### 3. Multi-session / restore

- Open at least 5 editor tabs.
- Set different selections / scroll positions / find queries in 3 of them.
- Close and reopen sessions or trigger restore paths.
- Verify:
  - selection restore
  - scroll restore
  - per-session find state
  - reference/problem panel state isolation

### 4. Multi-split workbench

- Create 2-way and 3-way splits.
- Move focus between split leaves.
- Trigger unsplit from a leaf and from an ancestor-adjacent path.
- Verify:
  - active editor correctness
  - session preservation in surviving leaf
  - no lost dirty state

### 5. Input stress

- Hold repeated typing for 10+ seconds in a normal file.
- Execute multi-cursor add-next / add-all flows on repeated tokens.
- Execute line move/copy/comment commands in succession.
- Verify:
  - no cursor loss
  - no duplicated edits
  - undo/redo preserves canonical selections

### 6. LSP stability

- Trigger hover, definition, references, rename, code action, signature help in quick succession.
- Move cursor or switch file before slow requests return.
- Verify stale responses are ignored and overlays/panels reflect only current session context.

## Recording Template

For each run, capture:

- commit or branch
- macOS version / hardware
- scenario name
- observed latency or qualitative result
- regression present: yes/no
- notes / screenshots if UI-specific

## Escalation Rule

If a structural refactor changes bridge, runtime gating, session restore, or transaction flow, run:

1. bridge-layer suites
2. kernel-focused suites
3. at least scenarios 3, 4, and 5 manually
