# EditorPanelPlugin

Editor **UI shell** for Lumi: workspace layout, tabs, breadcrumb, file tree rail, bottom panels, preview, and Xcode integration.

## Architecture layers

| Layer | Responsibility | Location |
|-------|----------------|----------|
| Kernel | Editor state, extension registry, `LSPService` | `Packages/EditorService` |
| UI shell | Workspace chrome, rails, bottom panels | `EditorPanelPlugin` (this package) |
| Language plugins | Grammar, LSP config, language-specific UI | `EditorGoPlugin`, `EditorVuePlugin`, `EditorJSPlugin`, … |
| LSP feature plugins | Cross-language LSP contributors | `LSP*EditorPlugin` packages |

Language and LSP plugins register into `EditorExtensionRegistry` at runtime. This package must not embed language or LSP infrastructure sources.

## Features

- **Code editing** — source code editor integration
- **File info banner** — display current file information
- **Command palette** — quick access to editor commands
- **State views** — loading, empty, and error states for file editing
- **Drag & drop preview** — visual feedback for drag and drop operations
- **Source editor bridge** — bridge between native and editor view

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [EditorCodeEditLanguages](../../Packages/EditorCodeEditLanguages) | Code editing language support |
| [EditorCodeEditSourceEditor](../../Packages/EditorCodeEditSourceEditor) | Source code editor component |
| [EditorCodeEditTextView](../../Packages/EditorCodeEditTextView) | Text view component |
| [EditorOverlayKit](../../Packages/EditorOverlayKit) | Editor overlay utilities |
| [EditorService](../../Packages/EditorService) | Editor service framework |
| [FilePreviewKit](../../Packages/FilePreviewKit) | File preview utilities |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiUI](../../Packages/LumiUI) | UI components |
| [MarkdownKit](../../Packages/MarkdownKit) | Markdown rendering |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **Editor Panel View** — main editor interface
- **Source Editor View** — core editing component
- **Command Palette View** — search and execute commands
- **State Views** — handling empty, loading, and error states

### Project Structure

```
Resources/
└── Localizable.xcstrings             # Localization strings
Sources/
├── EditorPanelPlugin.swift           # Plugin entry point
├── Coordinators/
│   ├── EditorPanelCoordinator.swift  # Main coordinator
│   └── SourceEditorViewBridge.swift  # Editor view bridge
├── Guide/
│   ├── EditorEmptyStateView.swift
│   ├── EditorLoadingStateView.swift
│   ├── EditorLoadFailureView.swift
│   ├── EditorEmptyContentStateView.swift
│   └── DragPreview.swift
├── Services/
│   └── EditorPanelService.swift      # Editor panel service
├── Views/
│   ├── EditorPanelView.swift         # Main view
│   ├── SourceEditorView.swift        # Source editor
│   ├── FileInfoBannerView.swift      # File info display
│   ├── EditorCommandPaletteView.swift# Command palette
│   └── EditorUnsupportedFileView.swift
Tests/
└── EditorPanelPluginTests/           # Unit tests
```

## License

Proprietary. All rights reserved.
