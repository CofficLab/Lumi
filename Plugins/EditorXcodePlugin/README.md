# EditorXcodePlugin

Xcode project integration: `.xcodeproj` / `.xcworkspace` support, build & run, and Xcode-specific editor context.

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)  ← 本 Package
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
| **层级** | 插件扩展层 — Panel 子插件 |
| **职责** | Xcode 工程集成：项目上下文、构建/运行、Xcode 专属编辑器能力 |
| **注册目标** | `EditorExtensionRegistry`（经 `LumiPluginRegistry` → `EditorExtensionsBootstrap`） |
| **上游依赖** | `EditorService`、`XcodeKit`、`LumiCoreKit`（详见 `Package.swift`） |
| **边界** | 不得依赖其他 Plugin 实现；通过 `SuperEditor*` 协议贡献能力 |
