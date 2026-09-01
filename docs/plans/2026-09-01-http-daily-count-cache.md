# HTTP Daily Count Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Cache historical daily HTTP exchange counts so the activity chart only queries the current day during normal refreshes.

**Architecture:** Keep a small JSON cache beside the HTTP exchange database. Historical day entries are reused, the current day is always recomputed, and retention cleanup invalidates cached days because the record-count cap can delete historical exchanges. Cache access is synchronized and version-aware so a concurrent write cannot incorrectly mark a stale query result as clean.

**Tech Stack:** Swift 6, SwiftData, Foundation, SwiftUI, Swift Testing.

---

### Task 1: Add the synchronized daily-count cache

**Files:**
- Create: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Support/HTTPExchangeDailyCountCache.swift`
- Test: `Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests/PluginNetworkManagerTests.swift`

Implement a small Codable cache containing day-key/count pairs and dirty keys. Protect in-memory state with a lock, persist atomically, and expose snapshot/update/invalidate operations. Updates must compare per-day versions so a write racing with a database read leaves that day dirty.

### Task 2: Integrate cache invalidation with writes and retention

**Files:**
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Services/HTTPExchangeStore.swift`

Initialize the cache beside `http-exchanges.sqlite`. Mark the request's start day dirty after successful inserts. When retention removes records, invalidate all cached days. Keep body storage and request recording behavior unchanged.

### Task 3: Read the activity series from cache

**Files:**
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Services/HTTPExchangeStore.swift`

For the 14-day window, reuse clean historical entries and always query the current day. For missing or dirty historical days, fetch only `startedAt` over the affected range and group in memory, avoiding request/response bodies and avoiding one count query per day. Fill missing days with zeroes and persist refreshed historical counts.

### Task 4: Verify behavior and regressions

**Files:**
- Test: `Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests/PluginNetworkManagerTests.swift`

Test cache persistence, invalidation, concurrent-write version protection, and daily-series correctness. Run `git diff --check` and `swift test` for the package.
