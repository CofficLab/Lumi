# LumiLocalizationKit

运行时本地化工具，专为 Lumi 的 Swift Package Manager plugin bundle 设计。

## 问题

Swift 标准的 `String(localized:bundle: .module)` 在 SPM plugin bundle 中无法正确读取编译后的 `.lproj` 资源，导致插件界面在多语言环境下显示异常。

## 解决方案

`LumiLocalization.string(...)` 提供两层查找：

1. 优先读取 bundle 内 `*.lproj/Localizable.strings`（或指定 table）
2. 回退到同 bundle 下的 `Localizable.xcstrings` catalog

若均未命中，则返回原始 key，避免 UI 空白。

## 使用

```swift
import LumiLocalizationKit

let text = LumiLocalization.string(
    "Welcome to Lumi",
    bundle: .module,
    table: "Localizable"
)
```

## 迁移计划

当前 `LumiPluginLocalization` 与 `EditorTextViewLocalization` 实现重复。后续将通过 **Forwarding Wrapper** 逐步迁移：

- **Phase 1**：新建本 Package，CoreKit/EditorTextView 保留透传，现有调用点不动
- **Phase 2**：新代码直接 `import LumiLocalizationKit`
- **Phase 3**：按模块渐进替换旧调用点

## 支持语言

- en
- zh-Hans
- zh-HK
- zh-TW
- zh-Hant
