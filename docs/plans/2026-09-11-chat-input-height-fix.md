# Chat Input Height Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent the Lumi chat input from temporarily expanding when its initial AppKit layout width is not ready.

**Architecture:** The representable will measure height only after the hosting scroll view reports a valid content width. A zero-width provisional layout will be ignored, and a regression test will cover that guard.

**Tech Stack:** Swift, AppKit, SwiftUI `NSViewRepresentable`, Swift Testing.

---

### Task 1: Guard provisional height measurements

**Files:**
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/Editor/ChatInputEditorView.swift`
- Test: `Packages/PluginConversationInput/Tests/PluginConversationInputTests/ChatInputEditorViewTests.swift`

**Steps:**

1. Add a test asserting that a zero-width layout cannot produce a height binding update, while a valid width still clamps the measured height normally.
2. Run the focused test and verify it fails before the implementation exists.
3. Add a valid-width gate to height calculation and trigger measurement when the custom scroll view receives its first non-zero layout width.
4. Run the focused test and the package test suite.
5. Review the diff and working-tree status; do not commit unrelated files.
