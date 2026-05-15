# StringCatalogKit

Lumi 内部的 Xcode String Catalog (`.xcstrings`) 解析工具包。

## 提供什么

- **String Catalog 解码**：解析 `.xcstrings` JSON，输出稳定的 `StringCatalog` 数据模型。
- **语言统计**：收集 source language 和所有 localized language，并计算每种语言的翻译完成度。
- **条目展示数据**：保留 key、extraction state、string unit state 和本地化文本，供预览 UI 直接渲染。
- **Variation 取值**：支持从 plural/device 等 variation 树里提取可展示的 string unit。
- **占位符扫描**：识别 `%@`、`%1$@`、`%lld`、`%.2f` 等格式化占位符，供 UI 高亮。
- **废弃条目清理**：删除 `extractionState == "stale"` 的字符串条目，并返回删除数量。

## 使用方式

在其他 SwiftPM 包的 `Package.swift` 中添加依赖：

```swift
.package(path: "../StringCatalogKit")
```

然后在目标依赖中引入：

```swift
.product(name: "StringCatalogKit", package: "StringCatalogKit")
```

解析字符串目录：

```swift
import StringCatalogKit

let catalog = try StringCatalogParser.parse(source)
let languages = catalog.languages
let entries = catalog.entries
```

扫描占位符：

```swift
let placeholders = StringCatalogPlaceholderScanner.placeholders(in: "Build %1$@ %2$@")
```

删除废弃条目：

```swift
let result = try StringCatalogCleaner.removingStaleEntries(from: source)
print(result.removedCount)
```

## 运行测试

```bash
cd Packages/StringCatalogKit
swift test
```
