# PluginMemory

`PluginMemory` is the package-based Memory plugin for Lumi.

The package exposes the plugin adapter, tools, and services:

- `MemoryPlugin`: Lumi plugin entry point
- `MemoryPluginConfig`: Configuration injected by the app layer (DB path, thresholds)
- 4 Agent Tools: `SaveMemoryTool`, `RecallMemoryTool`, `ListMemoriesTool`, `DeleteMemoryTool`
- `MemoryStorageService`: Wrapper around MemoryKit for file-based memory CRUD + indexing
- `MemoryRetrievalService`: Wrapper around MemoryKit for keyword-based memory retrieval
- `Resources/Memory.xcstrings`: plugin-owned localization catalog

## Architecture

```
PluginMemory (this package)
  ├── Tools (4 agent tools)
  ├── Services (thin wrappers around MemoryKit)
  └── MemoryPluginConfig (injected by app)

MemoryKit (dependency)
  └── Core storage & retrieval logic (no app dependencies)
```

The `MemoryContextSuperSendMiddleware` remains in the app layer because it depends on `WindowProjectVM` for project path and language preference.

## Structure

```text
PluginMemory
  Package.swift
  Sources/PluginMemory
    Resources/Memory.xcstrings
    Models/
      MemoryToolError.swift
    Services/
      MemoryStorageService.swift
      MemoryRetrievalService.swift
    Tools/
      SaveMemoryTool.swift
      RecallMemoryTool.swift
      ListMemoriesTool.swift
      DeleteMemoryTool.swift
    MemoryPlugin.swift
    MemoryPluginConfig.swift
  Tests/PluginMemoryTests
    MemoryPluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/PluginMemory/Resources/Memory.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginMemoryLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.

## App Integration

The app layer must set `MemoryPlugin.config` with the correct `memoryRootURL` before the plugin is used:

```swift
MemoryPlugin.config = MemoryPluginConfig(
    memoryRootURL: AppConfig.getDBFolderURL().appendingPathComponent("Memory")
)
```
