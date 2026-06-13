# Lumi 代码编辑器技术架构

> 日期：2026-06-13
> 范围：`Packages/Editor*`、`Plugins/Editor*`、`Plugins/LSP*EditorPlugin`

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
│  │ 注册 LSP 配置、高亮、语言专属命令与项目上下文               │  │
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
│  EditorService — 编辑器子系统唯一对外 Facade                      │
│  EditorExtensionRegistry — 扩展点聚合、解析与去重                   │
│  EditorState / EditorSessionStore — 文件、光标、面板运行时状态    │
│  LSP 集成 — LanguageClient、请求管线、语义能力桥接                │
│  SourceEditorAdapter — 连接 EditorSource 视图与内核控制器         │
└──────────────┬─────────────────────────────┬──────────────────────┘
               │ 视图绑定                     │ 纯逻辑调用
┌──────────────▼──────────────┐  ┌──────────▼──────────────────────┐
│ 视图层 — EditorSource          │  │ 内核逻辑层 — EditorKernel        │
│  SourceEditor SwiftUI 组件     │  │  无 UI 依赖的编辑域逻辑           │
│  Tree-sitter 语法高亮管线        │  │  选择集、多光标、查找替换         │
│  缩进、配对、文本格式化规则       │  │  折叠、导航、保存、Peek          │
│                               │  │  LSP 请求模型、命令路由策略       │
└──────────────┬──────────────┘  └─────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ 渲染基础层                                                        │
│  EditorTextView — 高性能 NSView 文本渲染、布局与输入               │
│  EditorLanguages — tree-sitter 语法与 highlights 二进制框架        │
│  EditorSymbols — 编辑器专用图标资源 (Symbols.xcassets)             │
└─────────────────────────────────────────────────────────────────┘
```

## 邻接模块

与主编辑链路相邻、但不属于核心分层的 Package：

| Package | 职责 | 使用方 |
|---------|------|--------|
| `EditorGoCore` | Go 模块检测、工具链、构建/测试命令、轻量补全 | `EditorGoPlugin` |
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

## 依赖规则

```text
允许:
  LumiApp → EditorService → EditorKernel / EditorSource → 基础层
  Plugins → EditorService, LumiCoreKit, LumiUI
  语言插件 → 语言领域 Kit（如 EditorGoCore）

禁止:
  EditorKernel / EditorService → 任何 Plugin
  Plugin A → Plugin B（实现类型）
  基础层 → EditorService / Plugins
```

## 数据流（打开文件 → 编辑）

```text
用户打开文件
  → EditorService.open(at:)
  → EditorSessionStore 创建/激活会话
  → EditorState 加载内容与语言 ID
  → EditorSourceEditorBindingController 绑定 SourceEditor
  → EditorLanguages 选择 tree-sitter grammar → 语法高亮
  → EditorExtensionRegistry 解析语言/LSP 贡献者
  → LSPService 发送 didOpen / 语义请求
  → EditorPanelPlugin 渲染工作区 UI 与 Overlay
```

## Package 索引

| Package | 层级 | 路径 |
|---------|------|------|
| `EditorTextView` | 渲染基础层 | `Packages/EditorTextView` |
| `EditorLanguages` | 渲染基础层 | `Packages/EditorLanguages` |
| `EditorSymbols` | 渲染基础层 | `Packages/EditorSymbols` |
| `EditorSource` | 视图层 | `Packages/EditorSource` |
| `EditorKernel` | 内核逻辑层 | `Packages/EditorKernel` |
| `EditorService` | 服务门面层 | `Packages/EditorService` |
| `EditorGoCore` | 邻接（Go 领域） | `Packages/EditorGoCore` |
| `EditorChatInputKit` | 邻接（聊天输入） | `Packages/EditorChatInputKit` |
| `EditorPanelPlugin` | 插件 — UI Shell | `Plugins/EditorPanelPlugin` |

## 相关文档

- [插件 Package 化架构](./plugin-package-architecture.md)
- [内核与插件边界规范](../.agent/rules/core-plugin-boundary-rules.md)
- [编辑器性能分析](./editor-performance-analysis.md)
