# 🗄️ PluginHistoryDBStatusBar

A [Lumi](https://github.com/anth0nying/Lumi) plugin that provides a **History Database Browser** in the status bar, allowing you to browse message and conversation history directly from the Agent mode status bar popover.

## Features

- **Messages Tab** – Browse all historical messages in a sortable table view, showing conversation title, role, model, token count, timestamp, and content preview.
- **Conversations Tab** – Browse all historical conversations displayed as rich cards with title, project, provider/model, chat mode, and message count.
- **Pagination** – Navigate through large datasets with previous/next page controls.
- **Refresh** – Reload data on demand with the refresh button.

## Architecture

```
PluginHistoryDBStatusBar
├── HistoryDBStatusBarPlugin.swift   # Plugin entry point (SuperPlugin)
├── ViewModels/
│   └── HistoryDBBrowserViewModel.swift  # Data loading & pagination state
├── Models/
│   ├── HistoryDBViewMode.swift      # Tab mode enum (messages / conversations)
│   ├── HistoryMessageRow.swift      # Message row data model
│   └── HistoryConversationRow.swift # Conversation row data model
├── Views/
│   ├── HistoryDBStatusBarView.swift       # Status bar entry view
│   ├── HistoryDBDetailView.swift          # Main popover content with tabs & table
│   ├── HistoryConversationCardView.swift  # Conversation card component
│   └── HistoryDBToolbarButton.swift       # Toolbar button entry (alternative)
└── Resources/
    └── HistoryDBStatusBar.xcstrings       # Localized strings (en)
```

## Requirements

- **Swift Tools Version:** 6.0
- **Platform:** macOS 14+
- **Dependencies:**
  - [LumiCoreKit](../../Packages/LumiCoreKit) – Plugin protocol & core types
  - [LumiUI](../../Packages/LumiUI) – Shared UI components & theme system

## Policy

`.alwaysOn` – core history browser status bar plugin that is always registered and cannot be disabled by users.

## How It Works

The plugin registers as a `SuperPlugin` and provides a status bar trailing view when the Agent mode (code icon) is active. Clicking the status bar icon opens a popover with two tabs:

1. **Messages** – A `Table` view displaying `HistoryMessageRow` entries.
2. **Conversations** – A scrollable card list displaying `HistoryConversationRow` entries.

The `HistoryDBBrowserViewModel` manages pagination state (`currentPage`, `pageSize`, `offset`) and exposes `reload()` for data loading. The loader methods are currently stubbed (`totalCount = 0`) and await a concrete data source integration.

## Integration

This plugin is a local Swift Package within the Lumi monorepo. Add it to your Xcode project or another package's dependencies:

```swift
.package(path: "../../Plugins/HistoryDBStatusBarPlugin")
```

Then link the target:

```swift
.product(name: "HistoryDBStatusBarPlugin", package: "HistoryDBStatusBarPlugin")
```

## License

Part of the Lumi project.
