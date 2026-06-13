# EditorService

可复用的 macOS 代码编辑器服务层。作为编辑器子系统的对外门面，协调 `EditorKernel` 纯逻辑与 `EditorSource` 视图实现，管理会话、标签页、LSP 交互与命令路由。

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)
    ↓
服务门面层 (EditorService)  ← 本 Package
    ↓                    ↓
视图层 (EditorSource)   内核逻辑层 (EditorKernel)
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 服务门面层 |
| **职责** | 编辑器子系统唯一对外 Facade；`EditorExtensionRegistry` 扩展点聚合；`EditorState` / `EditorSessionStore` 运行时状态；LSP 集成与 `SourceEditorAdapter` 视图桥接 |
| **上游依赖** | `EditorKernel`、`EditorSource`、`EditorTextView`、`EditorLanguages`、`EditorGoCore`、`LumiCoreKit` |
| **下游消费者** | `LumiApp`（`EditorCoreService`）、所有 `Editor*` / `LSP*` 插件 |
| **扩展点定义** | `Sources/Proto/SuperEditor*.swift` — 插件通过此目录下的协议注册贡献者 |
| **不得依赖** | 任何 Plugin 实现 |

## Package

- Product: `EditorService`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- **EditorService**：编辑器模块唯一对外入口（Facade）
- **Workbench**：会话、标签页、导航历史、打开/保存流程
- **Kernel 桥接**：选择集、多光标、查找替换、折叠、LSP 请求管线
- **扩展注册**：插件能力与主题贡献解析

## 依赖

- `EditorKernel`, `EditorSource`（`EditorSource`）
- `EditorTextView`, `EditorLanguages`, `SwiftTreeSitter`
- 见 `Package.swift` 了解完整依赖列表

## 依赖与集成

```swift
dependencies: [
    .package(path: "../EditorService"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["EditorService"]),
]
```

## 基本用法

```swift
import EditorService

// 在 SwiftUI 环境中注入
@EnvironmentObject private var editor: EditorService
```

内部状态（`EditorState`、`EditorSessionStore` 等）通过 `EditorService` 暴露；宿主应用不应直接依赖内部实现类型。

## Testing

From this package directory:

```sh
swift test
```

With coverage:

```sh
swift test --enable-code-coverage
```
