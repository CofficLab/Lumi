# LumiCodeEditSymbols

本仓库内维护的第三方包（源自 CodeEditApp 的 `CodeEditSymbols`），用于提供编辑器相关的自定义图标资源（`Symbols.xcassets`）及便捷访问 API。

## 我们用它做什么

- **SwiftUI**：通过 `Image(symbol:)` 或静态属性（例如 `Image.vault`）创建图标
- **AppKit**：通过 `NSImage.symbol(named:)` 获取图标

## 使用方式

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

## 运行测试

本仓库不维护上游的 snapshot tests（它们对 Lumi 的功能无关键且容易受上游变更影响）。
我们只保留最小 smoke test 来保证包可被 SwiftPM 构建与引用。

```bash
cd Packages/LumiCodeEditSymbols
swift test
```
