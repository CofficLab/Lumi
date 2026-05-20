# StringCatalogKit

可复用的 Xcode String Catalog (`.xcstrings`) 解析与维护工具包。将 JSON 解码、语言统计、占位符扫描与废弃条目清理提取到独立的 Swift Package，供任意 macOS 宿主应用或插件复用。

## Package

- Product: `StringCatalogKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- **String Catalog 解码**：解析 `.xcstrings` JSON，输出稳定的 `StringCatalog` 数据模型。
- **语言统计**：收集 source language 与所有 localized language，并计算每种语言的翻译完成度。
- **条目展示数据**：保留 key、extraction state、string unit state 与本地化文本，供宿主 UI 直接渲染。
- **Variation 取值**：支持从 plural / device 等 variation 树中提取可展示的 string unit。
- **占位符扫描**：识别 `%@`、`%1$@`、`%lld`、`%.2f` 等格式化占位符，供 UI 高亮。
- **废弃条目清理**：删除 `extractionState == "stale"` 的字符串条目，并返回删除数量。

## 依赖与集成

在 `Package.swift` 中添加本地或远程依赖：

```swift
dependencies: [
    .package(path: "../StringCatalogKit"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["StringCatalogKit"]
    ),
]
```

## 基本用法

### 解析字符串目录

```swift
import StringCatalogKit

let url = URL(fileURLWithPath: "Localizable.xcstrings")
let source = try String(contentsOf: url, encoding: .utf8)

let catalog = try StringCatalogParser.parse(source)
let languages = catalog.languages
let entries = catalog.entries
let staleCount = catalog.staleEntryCount
```

### 扫描占位符

```swift
let placeholders = StringCatalogPlaceholderScanner.placeholders(
    in: "Build %1$@ %2$@"
)
// placeholders[].range, placeholders[].value
```

### 删除废弃条目

```swift
let result = try StringCatalogCleaner.removingStaleEntries(from: source)
let cleanedSource = result.source
let removed = result.removedCount
```

## 核心类型

| 类型 | 说明 |
|------|------|
| `StringCatalog` | 解析后的目录（源语言、语言列表、条目列表） |
| `StringCatalog.Language` | 语言 ID、显示名、完成度与翻译计数 |
| `StringCatalog.Entry` | 单条字符串 key 及各语言的 `Value` |
| `StringCatalogParser` | 从 `String` 或 `Data` 解析 `.xcstrings` |
| `StringCatalogPlaceholderScanner` | 在本地化文本中查找格式化占位符 |
| `StringCatalogCleaner` | 移除 `stale` 条目并返回更新后的 JSON 源码 |
| `StringCatalogCleanResult` | 清理后的源码与删除数量 |

## Testing

From this package directory:

```sh
swift test
```

Tests cover parsing, language completion, placeholder detection, and stale-entry removal.
