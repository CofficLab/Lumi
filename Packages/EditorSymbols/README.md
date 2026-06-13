# EditorSymbols

维护中的 CodeEdit 图标资源包（源自 CodeEditApp 的 `CodeEditSymbols`）。提供编辑器相关自定义图标（`Symbols.xcassets`）及便捷访问 API。

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)
    ↓
服务门面层 (EditorService)
    ↓                    ↓
视图层 (EditorSource)   内核逻辑层 (EditorKernel)
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
                                        ↑ 本 Package
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 渲染基础层（资源） |
| **职责** | 编辑器专用图标资源（`Symbols.xcassets`）及 SwiftUI/AppKit 访问 API |
| **上游依赖** | 无（纯资源 + 薄封装） |
| **下游消费者** | `EditorSource` |
| **不得依赖** | 编辑器服务层、内核、任何 Plugin |

## Package

- Product: `EditorSymbols`
- Platform: macOS 12+
- Swift tools: 5.5

## 用途

- **SwiftUI**：通过 `Image(symbol:)` 或静态属性（例如 `Image.vault`）创建图标
- **AppKit**：通过 `NSImage.symbol(named:)` 获取图标

## 依赖与集成

```swift
dependencies: [
    .package(path: "../EditorSymbols"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "EditorSymbols", package: "EditorSymbols"),
    ]),
]
```

## 基本用法

SwiftUI：

```swift
import SwiftUI
import EditorSymbols

let image = Image(symbol: "vault")
let image2 = Image.vault
```

AppKit：

```swift
import AppKit
import EditorSymbols

let nsImage = NSImage.symbol(named: "vault")
```

## 新增图标资源

把从 `SF Symbols.app` 导出的 `.svg` 放到：

- `Sources/EditorSymbols/Symbols.xcassets`

并在 `Sources/EditorSymbols/EditorSymbols.swift` 里补齐对应的静态属性（可选，但更易用）。

## Testing

本包不维护上游的 snapshot tests（易受上游变更影响）。仅保留最小 smoke test 以保证 SwiftPM 可构建与引用。

From this package directory:

```sh
swift test
```
