# Message List Empty Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move the message-list empty states into one independently bootable `PluginMessageListEmpty` package without making the three verbosity-specific message-list plugins depend on it.

**Architecture:** The new plugin owns the empty-state UI, its guide/project/prompt-suggestion state, and a conditional `ChatSectionItem`. The three message-list plugins keep only their own list implementations and register their item when a conversation is selected and their verbosity matches. `ProviderChatSection` gains an exclusive stack group so the empty item and the active message-list item can coexist as independent plugins while only the lowest-priority active contributor renders.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, `ProviderChatSection`, `ProviderConversation`, `ProviderMessage`, `ProviderProject`, `ProviderPromptSuggestion`, `ProviderToolbar`.

---

### Task 1: Add exclusive ChatSection stack selection

**Files:** `Packages/ProviderChatSection/Sources/ProviderChatSection/ChatSectionItem.swift`, `Packages/ProviderChatSection/Sources/ProviderChatSection/DefaultChatSectionProviding.swift`

Add an optional exclusive group identifier to stack items and make the host render only the first item in each group, preserving existing behavior for ungrouped items.

**Test:** `swift test --package-path Packages/ProviderChatSection`.

### Task 2: Create the independent empty plugin

**Files:** Create `Packages/PluginMessageListEmpty/Package.swift` and its source files.

Move the guide UI and supporting state into the new package. The plugin observes selection and message changes, registering its empty item only when there is no selected conversation or the selected conversation has no non-tool messages.

**Test:** `swift build --package-path Packages/PluginMessageListEmpty`.

### Task 3: Remove empty-state ownership from V1/V2/V3

**Files:** `Packages/PluginMessageListBrief`, `Packages/PluginMessageListStandard`, `Packages/PluginMessageListDetailed`.

Remove duplicated guide views and guide-only state from the three list plugins. Keep loading and list-specific UI local, and require a selected conversation before registering each list item.

**Test:** Build all three message-list packages independently.

### Task 4: Register the fourth plugin in FactoryLumi

**Files:** `Packages/FactoryLumi/Package.swift`, `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`.

Add the package dependency, import, and plugin registration without introducing dependencies between the four message-list packages.

**Test:** `git diff --check`; build the affected packages and run available tests.
