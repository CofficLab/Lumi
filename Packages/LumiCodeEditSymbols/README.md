# LumiCodeEditSymbols

维护中的 CodeEdit 图标资源包（源自 CodeEditApp 的 `CodeEditSymbols`）。提供编辑器相关自定义图标（`Symbols.xcassets`）及便捷访问 API。

## Package

- Product: `CodeEditSymbols`
- Platform: macOS 12+
- Swift tools: 5.5

## 用途

- **SwiftUI**：通过 `Image(symbol:)` 或静态属性（例如 `Image.vault`）创建图标
- **AppKit**：通过 `NSImage.symbol(named:)` 获取图标

## 依赖与集成

```swift
dependencies: [
    .package(path: "../LumiCodeEditSymbols"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "CodeEditSymbols", package: "LumiCodeEditSymbols"),
    ]),
]
```

## 基本用法

SwiftUI：

```swift
import SwiftUI
import CodeEditSymbols

let image = Image(symbol: "vault")
let image2 = Image.vault
```

AppKit：

```swift
import AppKit
import CodeEditSymbols

let nsImage = NSImage.symbol(named: "vault")
```

## 新增图标资源

把从 `SF Symbols.app` 导出的 `.svg` 放到：

- `Sources/CodeEditSymbols/Symbols.xcassets`

并在 `Sources/CodeEditSymbols/CodeEditSymbols.swift` 里补齐对应的静态属性（可选，但更易用）。

## Testing

本包不维护上游的 snapshot tests（易受上游变更影响）。仅保留最小 smoke test 以保证 SwiftPM 可构建与引用。

From this package directory:

```sh
swift test
```
