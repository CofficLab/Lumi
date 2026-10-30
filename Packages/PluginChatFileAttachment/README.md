# PluginChatFileAttachment

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginChatFileAttachment`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginChatFileAttachment"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginChatFileAttachment"]),
]
```

## Testing

From this package directory:

```sh
swift test
```


## 能力边界

按钮原先直接持有 `KernelCoreContainer` 并在 `handle(_:)` 内部 `resolveProvider`，
把「组装」漏进了 View 层。现改为注入窄能力：

- `addFileAttachment(_:)` —— 追加待发送附件
- `presentLoadError(_:)` —— 读取失败时写入输入区错误提示

Adapter 在 `onBoot` 中解析 `MessageSendingProviding` 与 `ConversationInputProviding`
后构造，View 不再接触 kernel。
