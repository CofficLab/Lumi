# Plugin Observer-Only Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make plugin entry points the sole owners of plugin-level external observers, with each observer implemented under the plugin's `Observers` directory.

**Architecture:** A plugin resolves external Providers in its lifecycle method, constructs the corresponding observer, and stores it until shutdown. Observer types own subscription handles and expose only domain callbacks to the plugin. SwiftUI views and view models may retain local UI state, but they do not register plugin-level external listeners. Platform notifications remain permitted only as private inputs inside an Observer.

**Tech Stack:** Swift 6, SwiftUI, Combine, Foundation, KernelCore Provider protocols, XCTest/Swift Testing.

---

### Task 1: Inventory and guardrails (completed)

- Enumerate plugin-level `NotificationCenter`, `objectWillChange`, and direct Provider observer registrations.
- Separate platform-event ingress from plugin-state notification channels.
- Keep the generated package-local `Package.resolved` ignored.

### Task 2: Move observer ownership to plugin entry points (completed for the migrated plugins)

- Add or reuse `Observers` directories for plugins that listen to external state.
- Move observer construction out of View/ViewModel initializers into `onBoot`/`onReady`.
- Store observer instances on the plugin and cancel them in `onShutdown`.

### Task 3: Replace plugin-owned notification channels (in progress)

- Add typed event/observer handles to plugin-owned mutable services where needed.
- Replace plugin-to-plugin state broadcasts through `NotificationCenter` with typed callbacks.
- Keep command-style compatibility notifications separate from state-change observation until their callers are migrated.
- Migrated Story Writer, Clipboard Manager, Goal Task, Idle Time, and conversation-list state channels to typed local/provider-owned centers.
- Remaining compatibility bridges (for example app-update commands and legacy manager integrations) are intentionally tracked separately from plugin state observers.

### Task 4: Verify

- Run focused package tests for every changed package.
- Run the Lumi macOS app build.
- Run repository searches to confirm no new plugin-level external listener bypasses the plugin entry point.
