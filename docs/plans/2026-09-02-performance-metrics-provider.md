# Performance Metrics Provider Implementation Plan

> **For the implementation:** keep the hot path synchronous and memory-only; all persistence and report generation must happen off the main actor.

**Goal:** Add a product-level performance metrics provider that plugins can report to, persists bounded local timing data in the background, and exposes a settings page for inspecting latency summaries.

**Architecture:** `ProviderPerformanceMetrics` owns the public contract, metric models, a lock-protected in-memory ring buffer, and a utility-QoS JSON persistence queue. `PluginPerformanceMetrics` registers the provider with KernelCore and contributes a settings entry. The conversation input plugin receives the optional provider and reports the Return-to-message-commit trace without including message content.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation, SwiftUI, KernelCore, ProviderSettingView, ProviderStorage.

## Design decisions

- Hot-path APIs are synchronous and never touch disk, SwiftUI, or an actor hop.
- The collector keeps a bounded event window and batches persistence after a short delay.
- Reports are computed from a snapshot and expose count, p50, p95, p99, and max latency per operation/stage.
- Data is local-only and contains operation/stage names, durations, timestamps, and bounded metadata; no message text or attachment bytes are accepted.
- `DispatchTime` is used for elapsed time so wall-clock changes cannot distort latency.
- The settings UI is intentionally read-only in this MVP except for clearing local metrics.

## Implementation steps

1. Add `ProviderPerformanceMetrics` with the protocol, trace/event/report models, thread-safe collector, bounded retention, and background JSON persistence.
2. Add `PluginPerformanceMetrics` with lifecycle registration and a settings page showing metric summaries and recent samples.
3. Add both packages to `FactoryLumi` and start the metrics plugin after `PluginSettingView` but before chat plugins.
4. Inject the optional provider into `ConversationInputView` and report the text-send and attachment-send commit traces.
5. Add focused tests for aggregation, retention, persistence, clear, and plugin registration; run package tests and the relevant host build if available.

## Verification

- Confirm `swift test` passes for both new packages.
- Confirm the input package still builds with the optional dependency.
- Confirm the provider is registered exactly once and the settings entry is present after plugin boot.
- Confirm no synchronous send-path operation performs file I/O.
