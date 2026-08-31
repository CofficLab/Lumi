# Git Status Pipe Deadlock Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent production Git status refreshes from hanging indefinitely when Git emits more output than a pipe can buffer.

**Architecture:** Keep the existing synchronous snapshot API and Git status semantics. Replace the wait-before-read process handling with concurrent stdout/stderr drains, add a bounded hard timeout, and terminate timed-out processes before returning control to the refresh task.

**Tech Stack:** Swift 6, Foundation `Process`/`Pipe`, Swift Testing, Swift Package Manager.

---

### Task 1: Add a large-output regression test

**Files:**
- Modify: `Packages/PluginProjectFileTree/Tests/ProjectFileTreePluginTests.swift`

Create a temporary Git repository containing thousands of untracked files and assert that `GitStatusProvider.captureSnapshot` returns all entries. The fixture must generate more than a pipe buffer so the old wait-before-read implementation would reproduce the deadlock.

### Task 2: Make Git process I/O non-blocking and bounded

**Files:**
- Modify: `Packages/PluginProjectFileTree/Sources/PluginProjectFileTree/Services/GitStatusProvider.swift`

Drain stdout and stderr concurrently while Git is running, cap retained output to avoid unbounded memory growth while continuing to drain the pipes, and add a hard timeout with termination/force-kill fallback. Preserve the existing status parsing and return `nil` for failed or truncated scans.

### Task 3: Verify

Run the focused `PluginProjectFileTree` tests, then build the package and inspect the diff for unrelated changes. Confirm no production database files are modified.
