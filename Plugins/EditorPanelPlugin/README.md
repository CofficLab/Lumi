# EditorPanelPlugin

Editor **UI shell** for Lumi: workspace layout, tabs, breadcrumb, file tree rail, bottom panels, preview, and Xcode integration.

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)
    │  EditorPanelPlugin  ← 本 Package（UI Shell）
    │  EditorTabStrip / Breadcrumb / Rail* / Bottom*（Panel 子插件）
    │  EditorGo / Vue / JS …（语言插件）
    │  LSP*EditorPlugin（LSP 功能插件）
    ↓ 注册 SuperEditor* 贡献者
服务门面层 (EditorService)
    ↓                    ↓
视图层 (EditorSource)   内核逻辑层 (EditorKernel)
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 插件扩展层 — UI Shell |
| **职责** | 工作区布局（`EditorPanelView`）、`SourceEditorView` 编辑区、Overlay（hover/peek/rename 等）、文件预览、命令面板、空/加载/错误状态 |
| **上游依赖** | `EditorService`、`EditorSource`、`EditorKernel`、`LumiCoreKit`、`LumiUI` |
| **下游消费者** | `LumiApp`（通过 `LumiPluginRegistry` 加载） |
| **边界** | 不内嵌语言或 LSP 基础设施源码；语言/LSP 能力由其他插件注册到 `EditorExtensionRegistry` |

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
| [EditorLanguages](../../Packages/EditorLanguages) | Code editing language support |
| [EditorSource](../../Packages/EditorSource) | Source code editor component |
| [EditorTextView](../../Packages/EditorTextView) | Text view component |
| [EditorService](../../Packages/EditorService) | Editor service framework |
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
├── Preview/
│   └── FilePreviewView.swift         # Binary file preview (image/PDF/QuickLook)
├── Overlay/
│   └── …                             # Editor overlay views (hover, peek, rename, etc.)
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
