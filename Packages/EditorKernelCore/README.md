# EditorKernelCore

Lumi 的编辑器“内核纯逻辑”模块（SwiftPM 包），尽量保持与 UI 解耦。

## 提供什么

- **编辑器核心状态/策略**：如选择集、多光标、查找替换、折叠、导航、保存流程等核心逻辑。
- **LSP 相关核心模型/管线**：对语言服务协议请求与数据模型做抽象（依赖 `LanguageServerProtocol`）。

## 依赖

- **LanguageServerProtocol**（见 `Package.swift`）

## 使用方式

在其他 SwiftPM 包的 `Package.swift` 中添加依赖：

```swift
.package(path: "../EditorKernelCore")
```

然后在目标依赖中引入：

```swift
.product(name: "EditorKernelCore", package: "EditorKernelCore")
```

## 运行测试

```bash
cd Packages/EditorKernelCore
swift test
```

