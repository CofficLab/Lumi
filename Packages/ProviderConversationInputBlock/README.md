# ProviderConversationInputBlock

跨插件递交「折叠内容块」的 Provider 契约。

## Package

- Product: `ProviderConversationInputBlock`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

让生产方（如 `PluginCodeEditor` 把选区发送到对话）把一段内容交给对话输入框，
由输入插件决定是折叠成一行 chip 还是按纯文本插入。生产方只描述内容，不关心渲染。

- `ConversationInputBlock`：待插入的内容（全文 + chip 标题 + 图标 + 折叠阈值）
- `ConversationInputBlockProviding`：`submit(_:)` 与 `addObserver(_:)`
- `DefaultConversationInputBlockProvider`：内存实现，首个观察者注册前提交的内容会缓冲并在注册时补投

消费方（`PluginConversationInput`）按 `collapseThreshold` 决定折叠，
发送时仍提交完整原文。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../ProviderConversationInputBlock"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["ProviderConversationInputBlock"]),
]
```

## Testing

From this package directory:

```sh
swift test
```