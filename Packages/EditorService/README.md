# EditorService

可复用的 macOS 代码编辑器服务层。作为编辑器子系统的对外门面，协调 `EditorKernel` 纯逻辑与 `CodeEditSourceEditor` 视图实现，管理会话、标签页、LSP 交互与命令路由。

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

- `EditorKernel`, `LumiCodeEditSourceEditor`（`CodeEditSourceEditor`）
- `CodeEditTextView`, `CodeEditLanguages`, `SwiftTreeSitter`
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
