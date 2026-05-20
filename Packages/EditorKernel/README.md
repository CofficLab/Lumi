# EditorKernel

可复用的编辑器内核纯逻辑模块（SwiftPM 包），尽量与 UI 解耦。

## Package

- Product: `EditorKernel`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- **编辑器核心状态/策略**：选择集、多光标、查找替换、折叠、导航、保存流程等
- **LSP 相关核心模型/管线**：对 Language Server Protocol 请求与数据模型做抽象（依赖 `LanguageServerProtocol`）

## 依赖

- **LanguageServerProtocol**（见 `Package.swift`）

## 依赖与集成

```swift
dependencies: [
    .package(path: "../EditorKernel"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["EditorKernel"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
