# Menu Bar Popover Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the KernelCore/MenuBarExtra implementation visually and behaviorally indistinguishable from the legacy Lumi status-bar menu.

**Architecture:** Keep plugin-owned content views and telemetry models as the source of truth, but replace the new host shell with a compatibility renderer that owns legacy sizing, color-scheme bridging, localized application actions, ordering, separators, and interaction semantics. Add a narrow presentation model so `MenuBarExtra` always consumes a live snapshot of the provider instead of stale AnyView values.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Combine, KernelCore, ProviderMenuBar, LumiUI, Swift Testing.

---

### Task 1: Record the legacy contract as executable expectations

**Files:**
- Create: `Packages/ProviderMenuBar/Tests/ProviderMenuBarTests/MenuBarPresentationTests.swift`
- Modify: `Packages/ProviderMenuBar/Sources/ProviderMenuBar/DefaultMenuBarProviding.swift`

**Step 1: Write failing tests**

Cover stable ordering (`order`, then `id`), provider publication after add/remove/replace, and empty/non-empty popup snapshots.

**Step 2: Implement the smallest presentation snapshot API**

Expose ordered content and popup data from the provider without evaluating plugin views during registry mutation.

**Step 3: Run**

`swift test --package-path Packages/ProviderMenuBar`

### Task 2: Restore the legacy host Popover chrome

**Files:**
- Modify: `LumiApp/LumiApp2.swift`
- Modify: `Packages/LumiUI/Sources/Components/MenuBarActionRow.swift`
- Create: `Packages/LumiUI/Sources/Components/MenuBarPopoverScaffold.swift`

**Step 1: Build a dedicated compatibility scaffold**

Match the legacy 280-point width, vertical rhythm, separators, system appearance, popup background, and plugin-section composition. Keep the content API generic so every plugin remains self-contained.

**Step 2: Move host actions into the shared scaffold**

Use localized labels and the exact icon, tint, spacing, checkmark, and close-after-action behavior of the legacy `MenuBarPopupView` / `MenuBarActionRow`.

**Step 3: Replace the App-local ad-hoc rows**

Make `LumiApp2` only provide `showMainWindow`, update checking, and termination callbacks; it must not own visual constants or English copy.

**Step 4: Verify visually**

Launch the Lumi scheme, compare at 2× scale against the supplied screenshots, and capture the status-bar popover in both light and dark appearances.

### Task 3: Restore status-bar label parity and live refresh

**Files:**
- Modify: `LumiApp/LumiApp2.swift`
- Modify: `Packages/ProviderMenuBar/Sources/ProviderMenuBar/MenuBarProviding.swift`
- Modify: `Packages/ProviderMenuBar/Sources/ProviderMenuBar/DefaultMenuBarProviding.swift`
- Test: `Packages/ProviderMenuBar/Tests/ProviderMenuBarTests/MenuBarPresentationTests.swift`

**Step 1: Test dynamic contribution updates**

Assert that the provider publishes updates on plugin enable/disable and maintains the legacy label order.

**Step 2: Implement**

Render the selected Logo followed by ordered plugin content at the legacy 20/22-point geometry, with no fixed-width clipping and with menu-bar-appropriate appearance.

**Step 3: Verify**

Enable and disable Device, Network, Caffeinate, and Idle Time contributions and confirm label and popover changes occur without restarting the app.

### Task 4: Close remaining component-level parity gaps

**Files:**
- Modify only components whose source diff against `d4e968e1e^` proves a behavioral or visual gap under `Packages/PluginCaffeinate`, `Packages/PluginDevice`, `Packages/PluginNetworkManager`, and `Packages/PluginIdleTime`
- Test: the affected package test target(s)

**Step 1: Compare each rendered section against legacy**

Preserve exact durations, action modes, CPU/memory metrics, network chart rhythm, and Idle Time section behavior. Do not redesign the plugin UI or substitute placeholder content.

**Step 2: Add targeted regression tests**

Test the data and interaction contract for each altered plugin only.

**Step 3: Verify package and application build**

Run the changed package tests, then `xcodebuild -project Lumi.xcodeproj -scheme Lumi -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`.

### Task 5: Final visual acceptance and commit

**Files:**
- Modify: only files changed by Tasks 1–4

**Step 1: Acceptance checks**

Compare width, text language, section order, divider positions, control selection, icon colors, hover behavior, and action outcomes with the legacy reference.

**Step 2: Commit**

`git commit -m "feat(lumi-app): restore menu bar popover parity"`
