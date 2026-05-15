# IdleTime Plugin Implementation Plan

## 1. Overview

### 1.1 Goal

IdleTimePlugin is a small infrastructure plugin that silently infers the user's usual rest window for the current machine and project. Other background plugins, such as bug finding or long-running code analysis, can use this window as a scheduling hint.

The first user-facing surface is intentionally narrow:

- Add an entry in the bottom status bar.
- Clicking or hovering the entry opens a popover.
- The popover shows the inferred rest time window, confidence, data coverage, and current collection status.
- No user configuration is required.

### 1.2 Non-goals

- Do not run bug scans in this plugin.
- Do not ask the user to configure working hours.
- Do not record editor content, command text, file paths, conversation content, or source code.
- Do not treat the inferred rest window as proof that the user is idle right now. It is only a scheduling hint.

### 1.3 Design Principles

- **Silent by default**: collect only minimal activity metadata.
- **Privacy preserving**: store event kind and timestamp, not content.
- **Adaptive**: recent activity affects the model more than old activity.
- **Conservative**: low confidence should produce a visible "learning" state instead of pretending the model is reliable.
- **Reusable**: expose a service API so future plugins can ask for the inferred rest window.

---

## 2. Product Behavior

### 2.1 Status Bar Entry

Contribute a trailing status bar view through `SuperPlugin.addStatusBarTrailingView(activeIcon:)`.

Suggested compact states:

| State | Status bar text | Meaning |
| --- | --- | --- |
| Learning | `Idle learning` | Not enough data or low confidence |
| Ready | `Idle 23:30-07:30` | A confident rest window is available |
| Inferred but weak | `Idle ~23:30-07:30` | Window exists but confidence is medium |
| Disabled by missing project | hidden | No current project path |

Use an SF Symbol such as `moon.zzz` or `clock.badge.checkmark` with a short label. Keep the view consistent with existing status bar plugins like `GitPluginStatusBarView`: small icon, 11 pt text, `StatusBarHoverContainer`, and a popover width around 420-520.

### 2.2 Popover

The popover should show:

- Inferred rest window, for example `23:30 - 07:30`.
- Confidence label: `High`, `Medium`, or `Learning`.
- Data coverage: observed days in the last 28 days.
- Last activity time.
- Current model type: `Weekday`, `Weekend`, or `Global fallback`.
- A compact 24-hour activity heat strip, optional for Phase 1 but useful for debugging.

No settings controls are shown. This plugin is intentionally zero configuration.

### 2.3 Empty and Learning States

When data is insufficient:

- Status bar: `Idle learning`
- Popover title: `Learning rest window`
- Detail: `Need several days of activity metadata before the estimate becomes reliable.`

The plugin can still return a fallback window internally, but the UI should clearly label it as fallback or learning.

---

## 3. Architecture

### 3.1 Component Diagram

```text
Editor / App / Project Events
          |
          v
┌──────────────────────┐
│ IdleActivityRecorder │
│ timestamp + kind only│
└──────────┬───────────┘
           v
┌──────────────────────┐
│ IdleActivityStore    │
│ JSON / SQLite actor  │
└──────────┬───────────┘
           v
┌──────────────────────┐
│ RestWindowInferencer │
│ 48 bucket model      │
└──────────┬───────────┘
           v
┌──────────────────────┐
│ IdleTimeService      │
│ public query API     │
└──────┬───────────────┘
       │
       ├──────────────► Future background plugins
       │
       v
┌──────────────────────┐
│ IdleStatusBarView    │
│ IdlePopoverView      │
└──────────────────────┘
```

### 3.2 Suggested Directory Structure

```text
LumiApp/Plugins/IdleTimePlugin/
├── IdleTimePlugin.swift
├── Models/
│   ├── IdleActivityEvent.swift
│   ├── RestWindow.swift
│   └── IdleInferenceSnapshot.swift
├── Services/
│   ├── IdleActivityRecorder.swift
│   ├── IdleActivityStore.swift
│   ├── RestWindowInferencer.swift
│   └── IdleTimeService.swift
├── Views/
│   ├── IdleStatusBarView.swift
│   ├── IdlePopoverView.swift
│   └── ActivityHeatStripView.swift
└── IdleTime.xcstrings
```

---

## 4. Data Model

### 4.1 Activity Event

Only store event kind and timestamp.

```swift
struct IdleActivityEvent: Codable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let kind: IdleActivityKind
}

enum IdleActivityKind: String, Codable, Sendable {
    case appBecameActive
    case editorInput
    case fileSave
    case terminalCommandStarted
    case agentMessageSent
    case projectChanged
}
```

Avoid storing:

- typed text
- file paths
- command text
- conversation content
- model prompts
- repository names

### 4.2 Rest Window

```swift
struct RestWindow: Codable, Sendable, Equatable {
    let startMinuteOfDay: Int
    let endMinuteOfDay: Int
    let confidence: Double
    let source: RestWindowSource
    let generatedAt: Date
}

enum RestWindowSource: String, Codable, Sendable {
    case weekday
    case weekend
    case globalFallback
    case defaultFallback
}
```

The window may cross midnight. For example:

- `startMinuteOfDay = 1410` means `23:30`
- `endMinuteOfDay = 450` means `07:30`

### 4.3 Inference Snapshot

```swift
struct IdleInferenceSnapshot: Codable, Sendable, Equatable {
    let restWindow: RestWindow?
    let observedDayCount: Int
    let eventCount: Int
    let lastActivityAt: Date?
    let bucketScores: [Double]
    let confidenceBreakdown: ConfidenceBreakdown
}

struct ConfidenceBreakdown: Codable, Sendable, Equatable {
    let dataCoverage: Double
    let contrast: Double
    let stability: Double
}
```

---

## 5. Activity Collection

### 5.1 Event Sources

Start with signals that already exist or are cheap to wire:

| Source | Event kind | Notes |
| --- | --- | --- |
| App activation | `appBecameActive` | Use app lifecycle notifications |
| Project switch | `projectChanged` | Record when `ProjectVM.currentProjectPath` changes |
| Message send | `agentMessageSent` | Record user-originated message send, not content |
| File save | `fileSave` | Record save event only |
| Editor input | `editorInput` | Throttle heavily |
| Terminal command | `terminalCommandStarted` | Record command start only, not command text |

Phase 1 can ship with app activation, project switch, message send, and file save. Editor input and terminal command signals can be added after their event hooks are confirmed.

### 5.2 Throttling

Do not write an event for every keystroke. Coalesce repeated events:

```swift
struct IdleActivityThrottlePolicy {
    static let editorInputMinimumInterval: TimeInterval = 60
    static let appActiveMinimumInterval: TimeInterval = 300
    static let fileSaveMinimumInterval: TimeInterval = 30
}
```

The recorder should keep an in-memory `lastRecordedAtByKind` dictionary and ignore events that arrive too frequently.

### 5.3 Retention

Keep only recent data:

- Raw events: 35 days.
- Inference snapshots: latest snapshot only, plus optional 7-day debug history.

Prune during startup and after each daily inference.

---

## 6. Inference Algorithm

### 6.1 Bucket Model

Split a day into 48 half-hour buckets:

```swift
let bucketsPerDay = 48
let bucketMinutes = 30
```

Each event contributes to one bucket using local time.

Suggested event weights:

| Event kind | Weight |
| --- | ---: |
| `editorInput` | 3.0 |
| `agentMessageSent` | 3.0 |
| `fileSave` | 2.0 |
| `terminalCommandStarted` | 2.0 |
| `projectChanged` | 1.5 |
| `appBecameActive` | 1.0 |

Apply recency decay:

```swift
let recencyWeight = exp(-daysAgo / 14.0)
bucketScore[bucket] += eventWeight * recencyWeight
```

Use the user's current calendar and time zone when bucketing. If the time zone changes, future events use the new time zone; old timestamps remain absolute dates and are re-bucketed during inference using the current calendar.

### 6.2 Separate Models

Maintain three views of the data:

- Weekday model: Monday-Friday.
- Weekend model: Saturday-Sunday.
- Global model: all days.

At query time:

1. Use weekday model on weekdays if coverage is sufficient.
2. Use weekend model on weekends if coverage is sufficient.
3. Otherwise use the global model.
4. If global confidence is too low, return a default fallback marked as `defaultFallback`.

### 6.3 Window Search

Search for the lowest-activity continuous window. Support crossing midnight by treating bucket indexes as circular.

Recommended constraints:

- Minimum duration: 6 hours, 12 buckets.
- Maximum duration: 10 hours, 20 buckets.
- Preferred duration: 8 hours, 16 buckets.

Objective:

```text
cost =
  averageActivityInside
  - contrastWeight * max(0, averageActivityOutside - averageActivityInside)
  + durationPenalty
```

Suggested constants:

```swift
let contrastWeight = 0.7
let durationPenaltyPerBucket = 0.05
```

Pick the window with the lowest cost.

### 6.4 Confidence

Compute confidence as a weighted score:

```swift
confidence = clamp01(
    dataCoverage * 0.35 +
    contrastScore * 0.45 +
    stabilityScore * 0.20
)
```

Definitions:

- `dataCoverage`: observed days divided by target days, capped at 1.0. Target 14 days for global and weekday, 6 days for weekend.
- `contrastScore`: how much quieter the window is than the rest of the day.
- `stabilityScore`: how close daily best windows are to the selected aggregate window.

Suggested labels:

| Confidence | Label | Behavior |
| --- | --- | --- |
| `< 0.45` | Learning | Show learning state, only return fallback internally |
| `0.45...0.70` | Medium | Show inferred window with `~` prefix |
| `>= 0.70` | High | Show inferred window normally |

### 6.5 Default Fallback

If there is not enough signal, return:

```text
22:30 - 07:30
confidence: 0.0
source: defaultFallback
```

The UI should not present this as learned behavior.

---

## 7. Service API

Future analysis plugins should not read the store directly. They should use `IdleTimeService`.

```swift
actor IdleTimeService {
    static let shared = IdleTimeService()

    func record(_ kind: IdleActivityKind, at date: Date = Date()) async

    func currentSnapshot(for date: Date = Date()) async -> IdleInferenceSnapshot

    func inferredRestWindow(for date: Date = Date()) async -> RestWindow?

    func isInLikelyRestWindow(
        at date: Date = Date(),
        minimumConfidence: Double = 0.70
    ) async -> Bool
}
```

`isInLikelyRestWindow` should only answer the schedule question. Heavy background jobs must still perform real-time checks such as recent input, file stability, active tasks, and CPU load.

---

## 8. UI Design

### 8.1 Plugin Entry

```swift
actor IdleTimePlugin: SuperPlugin, SuperLog {
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "IdleTime"
    static let displayName = String(localized: "Idle Time", table: "IdleTime")
    static let description = String(localized: "Infer rest windows for background scheduling", table: "IdleTime")
    static let iconName = "moon.zzz"
    static let isConfigurable = false
    static var order: Int { 96 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = IdleTimePlugin()

    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(IdleStatusBarView())
    }
}
```

### 8.2 Status Bar View

Use the existing pattern:

```swift
StatusBarHoverContainer(
    detailView: IdlePopoverView(),
    popoverWidth: 480,
    id: "idle-time-status"
) {
    HStack(spacing: 6) {
        Image(systemName: "moon.zzz")
            .font(.system(size: 10))
        Text(viewModel.compactLabel)
            .font(.system(size: 11))
            .lineLimit(1)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
}
```

The view model should refresh:

- on appear
- when app becomes active
- after `IdleTimeService` publishes an updated snapshot
- when `ProjectVM.currentProjectPath` changes

### 8.3 Popover Layout

Suggested layout:

```text
┌──────────────────────────────────────┐
│ Idle Time                            │
│ 23:30 - 07:30              High      │
│                                      │
│ Coverage     18 / 28 days            │
│ Events       426                     │
│ Last active  Today 17:42             │
│ Source       Weekday model           │
│                                      │
│ [24-hour heat strip]                 │
└──────────────────────────────────────┘
```

Keep it informational. Do not add manual override controls in this plugin.

---

## 9. Persistence

### 9.1 Storage Format

Use a plugin-local JSON file first. The data volume is small and the schema is simple.

Suggested location:

```text
Application Support/Lumi/Plugins/IdleTime/activity.json
Application Support/Lumi/Plugins/IdleTime/snapshot.json
```

If Lumi already has a shared store abstraction for plugin-local data, use that instead of introducing a new persistence helper.

### 9.2 Concurrency

`IdleActivityStore` should be an actor:

```swift
actor IdleActivityStore {
    func append(_ event: IdleActivityEvent) async throws
    func loadRecentEvents(since cutoff: Date) async throws -> [IdleActivityEvent]
    func saveSnapshot(_ snapshot: IdleInferenceSnapshot) async throws
    func loadSnapshot() async throws -> IdleInferenceSnapshot?
    func prune(before cutoff: Date) async throws
}
```

All disk I/O stays off the main actor.

---

## 10. Scheduling

### 10.1 Inference Triggers

Run inference:

- on app startup after loading recent events
- after recording an event, debounced by at least 10 minutes
- when the date changes
- when the user opens the popover and the snapshot is stale

### 10.2 Staleness

A snapshot is stale when:

- it is older than 6 hours, or
- it was generated before the latest retained activity event, and at least 10 minutes have elapsed since the last inference.

---

## 11. Integration Plan

### Phase 1: Foundation

- [ ] Create `IdleTimePlugin` entry.
- [ ] Add models: `IdleActivityEvent`, `RestWindow`, `IdleInferenceSnapshot`.
- [ ] Implement `IdleActivityStore` with JSON persistence.
- [ ] Implement `RestWindowInferencer` with bucket scoring, circular window search, and confidence labels.
- [ ] Add unit tests for cross-midnight windows and low-data fallback.

### Phase 2: Event Recording

- [ ] Record app activation with throttling.
- [ ] Record project changes from `ProjectVM.currentProjectPath`.
- [ ] Record user message sends from the existing send pipeline or relevant view model hook.
- [ ] Record file saves if there is a stable editor save event.
- [ ] Prune old events.

### Phase 3: Status Bar UI

- [ ] Implement `IdleStatusBarView`.
- [ ] Implement `IdlePopoverView`.
- [ ] Add optional `ActivityHeatStripView`.
- [ ] Localize visible strings in `IdleTime.xcstrings`.

### Phase 4: Public API for Background Plugins

- [ ] Add `IdleTimeService.currentSnapshot`.
- [ ] Add `IdleTimeService.inferredRestWindow`.
- [ ] Add `IdleTimeService.isInLikelyRestWindow`.
- [ ] Document that callers must still perform real-time idle checks before heavy work.

---

## 12. Tests

### 12.1 Inferencer Tests

Use deterministic event sets:

- No events returns `defaultFallback` and confidence `0`.
- Daytime activity from `09:00-18:00` infers a night window crossing midnight.
- Night activity from `22:00-04:00` infers a daytime rest window.
- Sparse data remains in `Learning`.
- Weekend and weekday models can produce different windows.
- Recent events outweigh old events after recency decay.

### 12.2 Store Tests

- Append and reload events.
- Prune events older than 35 days.
- Corrupt JSON should not crash the app; rename the corrupt file and start fresh.
- Concurrent records should not lose events.

### 12.3 UI Tests / Preview Checks

- Status bar hidden when no project is active, if that behavior is selected.
- Learning label fits the 32 px status bar height.
- Long localized labels do not overflow the popover.
- Popover handles missing snapshot, medium confidence, and high confidence.

---

## 13. Privacy and Safety Notes

- The plugin stores activity timing metadata only.
- Raw activity events are local to the machine.
- No network call is needed.
- No content is sent to LLMs.
- Other plugins should receive only aggregated snapshots or a yes/no schedule answer, not raw activity history unless there is a clear local-only need.

---

## 14. Open Questions

- Which exact editor event should be used for `editorInput` without introducing high-frequency writes?
- Is there an existing plugin-local storage helper that should replace direct JSON files?
- Should the status bar entry hide when confidence is low, or show `Idle learning` to make the feature discoverable?
- Should the first implementation infer globally per machine, or per project? Recommended: per machine first, because rest windows are user behavior, not repository behavior.
