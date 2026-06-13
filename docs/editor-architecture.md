# Lumi 代码编辑器技术架构

## 概述

Lumi 代码编辑器采用**分层 + 插件扩展**架构。底层负责文本渲染与语法高亮，中层承载无 UI 的编辑逻辑与服务门面，上层通过插件贡献命令、LSP 能力、面板与工作区 UI。依赖方向严格自下而上，内核不依赖插件，插件之间不互相依赖。

## 分层架构

```text
┌─────────────────────────────────────────────────────────────────┐
│ 应用装配层 (LumiApp)                                             │
│  EditorCoreService / EditorCore — 启动、扩展注册、主题同步        │
│  LumiPluginRegistry — EditorExtensionsBootstrap 聚合编辑器插件    │
└────────────────────────────┬────────────────────────────────────┘
                             │ 装配 & 注入
┌────────────────────────────▼────────────────────────────────────┐
│ 插件扩展层 (Plugins/)                                            │
│  ┌─ UI Shell ───────────────────────────────────────────────┐  │
│  │ EditorPanelPlugin — 工作区布局、SourceEditor、Overlay     │  │
│  │ EditorTabStrip / Breadcrumb / Rail* / Bottom* — 面板子插件  │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌─ 语言插件 ───────────────────────────────────────────────┐  │
│  │ EditorGo / Vue / JS / Swift / Markdown / HTML / CSS …    │  │
│  │ 注册 LSP 配置（LSPConfig.registerServerConfig）、高亮、    │  │
│  │ 语言专属命令与项目上下文                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌─ LSP 功能插件 ───────────────────────────────────────────┐  │
│  │ LSPCodeAction / LSPFolding / LSPHover / LSPInlayHint …   │  │
│  │ 跨语言的 LSP 贡献者（completion、hover、signature 等）      │  │
│  └──────────────────────────────────────────────────────────┘  │
│  通过 SuperEditor* 协议向 EditorExtensionRegistry 注册贡献点     │
└────────────────────────────┬────────────────────────────────────┘
                             │ 注册 & 查询
┌────────────────────────────▼────────────────────────────────────┐
│ 服务门面层 — EditorService                                       │
│  EditorService — 编辑器子系统唯一对外 Facade（含 files/sessions/editing 等子门面）│
│  EditorExtensionRegistry — 扩展点聚合、解析与去重                   │
│  EditorState / EditorSessionStore — 文件、光标、面板运行时状态    │
│  LSP 集成 — LanguageClient、请求管线、语义能力桥接                │
│  SourceEditorAdapter — 连接 EditorSource 视图与内核控制器         │
└──────────────┬─────────────────────────────┬──────────────────────┘
               │ 视图绑定                     │ 纯逻辑调用
┌──────────────▼──────────────┐  ┌──────────▼──────────────────────┐
│ 视图层 — EditorSource          │  │ 内核逻辑层 — EditorKernel        │
│  SourceEditor SwiftUI 组件     │  │  无 UI 依赖的编辑域逻辑           │
│  Tree-sitter 语法高亮管线        │  │  按领域子目录：Selection / Save  │
│  缩进、配对、Symbols.xcassets    │  │  FindReplace / Command / LSP …  │
└──────────────┬──────────────┘  └─────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ 渲染基础层                                                        │
│  EditorTextView — 高性能 NSView 文本渲染、布局与输入               │
│  EditorLanguageRuntime — tree-sitter 查询缓存与语言注册表          │
└─────────────────────────────────────────────────────────────────┘
```

## 邻接模块

与主编辑链路相邻、但不属于核心分层的 Package：

| Package | 职责 | 使用方 |
|---------|------|--------|
| `EditorChatInputKit` | 聊天输入框编辑器（高度、键盘、拖放） | `ChatInputPlugin` |

## 扩展点（EditorService / Proto）

插件通过 `EditorExtensionRegistry` 注册各类贡献者，主要协议包括：

| 协议族 | 示例能力 |
|--------|----------|
| `SuperEditorCompletionContributor` | 补全 |
| `SuperEditorHoverContributor` | 悬停提示 |
| `SuperEditorCodeActionContributor` | 代码动作 |
| `SuperEditorHighlightProviderContributor` | 语义/自定义高亮 |
| `SuperEditorCommandContributor` | 编辑器命令 |
| `SuperEditorPanelContributor` | 面板（Rail / Bottom / Header） |
| `SuperEditorLanguageIntegrationCapability` | LSP 初始化与 workspace 配置 |
| `SuperEditorProjectContextCapability` | 项目上下文同步 |
| `SuperEditorThemeContributor` | 语法主题 |

完整协议定义见 `Packages/EditorService/Sources/Proto/`。

## EditorService 子门面

`EditorService` 核心类（约 170 行）负责初始化与子门面组装；业务 API 按职责拆分如下：

| 属性 | 类型 | 职责 |
|------|------|------|
| `files` | `EditorFileService` | 文件加载、保存、大文件模式 |
| `sessions` | `EditorSessionService` | 会话/标签页、导航历史 |
| `editing` | `EditorEditingService` | 光标、多光标、查找替换 |
| `navigation` | `EditorNavigationService` | 跳转定义/引用、Peek、内联重命名 |
| `commands` | `EditorCommandService` | 命令系统、Quick Open |
| `panel` | `EditorPanelService` | 面板操作、工作区搜索 |
| `theme` | `EditorThemeService` | 主题与外观配置 |
| `lsp` | `EditorLSPService` | LSP 能力、诊断、格式化 |

插件与 App 层应通过上表子门面访问业务 API（如 `editor.sessions.open(at:)`、`editor.files.currentFileURL`）。

根 `EditorService` 仍直接暴露的非子门面成员：`state`、`sessionStore`、`projectRootPath`、`refreshProjectContext`、`editorExtensions`、`isMarkdownPreviewMode` 等生命周期/装配相关 API。

### Proto 桥接层（插件依赖收敛）

插件**仅**依赖 `EditorService`，底层类型通过 Proto 桥接重导出：

| 文件 | 作用 |
|------|------|
| `EditorTypeBridge.swift` | LSP 请求生命周期、WorkspaceEdit 类型 |
| `EditorTextViewBridge.swift` | `@_exported import EditorSource/EditorTextView` |
| `EditorLanguageBridge.swift` | `@_exported import EditorLanguageRuntime` |
| `EditorHighlightProviderBridge.swift` | 在 EditorService 内构造 `HighlightProviding` 适配器 |

## 依赖规则

```text
允许:
  LumiApp → EditorService → EditorKernel / EditorSource → 基础层
  Plugins → EditorService, LumiCoreKit, LumiUI

禁止:
  EditorKernel / EditorService → 任何 Plugin
  Plugin A → Plugin B（实现类型）
  基础层 → EditorService / Plugins
```

## 数据流（打开文件 → 编辑）

```text
用户打开文件
  → EditorService.sessions.open(at:)
  → EditorSessionStore 创建/激活会话
  → EditorState 加载内容与语言 ID
  → EditorSourceEditorBindingController 绑定 SourceEditor
  → LanguageRegistry 选择已注册 grammar → 语法高亮
  → EditorExtensionRegistry 解析语言/LSP 贡献者
  → LSPService 发送 didOpen / 语义请求
  → EditorPanelPlugin 渲染工作区 UI 与 Overlay
```

## Package 索引

| Package | 层级 | 路径 |
|---------|------|------|
| `EditorTextView` | 渲染基础层 | `Packages/EditorTextView` |
| `EditorLanguageRuntime` | 渲染基础层（语言无关运行时） | `Packages/EditorLanguageRuntime` |
| `EditorSource` | 视图层（含 Symbols.xcassets） | `Packages/EditorSource` |
| `EditorKernel` | 内核逻辑层 | `Packages/EditorKernel` |
| `EditorService` | 服务门面层 | `Packages/EditorService` |
| `EditorChatInputKit` | 邻接（聊天输入） | `Packages/EditorChatInputKit` |
| `EditorPanelPlugin` | 插件 — UI Shell | `Plugins/EditorPanelPlugin` |

## LSP 配置注册机制

语言服务器的发现与配置通过**插件注册机制**实现，`EditorService` 不再硬编码任何语言特定逻辑。

### 注册流程

```text
语言插件加载
  → 插件调用 LSPConfig.registerServerConfig(for:languageId:config:)
  → LSPConfig 内部维护注册表 [languageId: ServerConfig]
  → LSPService 启动服务器时查询注册表
  → 获取 ServerConfig（execPath, arguments, env）
```

### 示例代码

```swift
// 在 EditorGoPlugin 中注册 Go 语言服务器
@MainActor
public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
    // 注册语言集成能力
    registry.registerLanguageIntegrationCapability(GoLanguageIntegrationCapability())
    
    // 注册 LSP 服务器配置
    if let goPath = GoEnvResolver.goplsPath {
        LSPConfig.registerServerConfig(
            for: "go",
            config: LSPConfig.ServerConfig(
                languageId: "go",
                execPath: goPath,
                arguments: ["serve"]
            )
        )
    }
}
```

### 设计原则

- **延迟发现**：语言插件在 `registerEditorExtensions` 阶段注册发现逻辑，而非立即执行路径查找
- **单一职责**：每种语言的 LSP 配置由对应的语言插件负责，`EditorService` 保持语言无关
- **可扩展性**：新增语言支持只需添加语言插件并在注册中心登记，无需修改 `EditorService`

## 新增语言插件

1. 在 `Plugins/` 下创建 `Editor{Lang}Plugin`（可参考 `Scripts/generate-language-plugins.py`）
2. 在插件中注册：
   - `registry.registerLanguage(EditorLanguageDescriptor(...))`
   - `registry.registerGrammarProvider(BundledGrammarProvider(...))`
   - 可选：`LSPConfig.registerServerProvider` 或 `SuperEditorLanguageIntegrationCapability.serverConfig`
3. 在 `EditorExtensionPluginRegistry.swift` 与 `LumiPluginRegistry/Package.swift` 登记插件
4. 运行 `python3 Scripts/generate-editor-extension-registry.py` 校验注册表

## 相关文档

- [插件 Package 化架构](./plugin-package-architecture.md)
- [内核与插件边界规范](../.agent/rules/core-plugin-boundary-rules.md)
- [编辑器性能分析](./editor-performance-analysis.md)
