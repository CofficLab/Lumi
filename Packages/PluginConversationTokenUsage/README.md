# PluginConversationTokenUsage

在 Chat header 栏右侧显示当前对话的**总 token 数**；点击后弹出 popover 展示输入 / 输出拆分。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginConversationTokenUsage`
- Platform: macOS 14+, iOS 17+
- Swift tools: 6.0

## 提供什么

- `ChatSectionBarItem(placement: .headerTrailing)` 贡献项：header 栏右侧的 token 用量指示器。
- `TokenUsageStats`：从会话消息聚合输入 / 输出 token 数。
- `TokenUsageObserver`：转发会话选择与消息变化事件。

### 数据口径

- 只统计 **assistant** 消息：user / tool 消息没有服务端上报的用量。
- 输入 token 优先取 `cacheTotalInputTokenCount`（缓存型端点的真实总输入），
  缺失时才退回 `inputTokenCount`。
- 供应商未上报 usage 的响应（输入与输出都为 0）不计入请求数。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginConversationTokenUsage"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginConversationTokenUsage"]),
]
```

宿主还需要把它加进 `DefaultPluginFactory.makePlugins()` 的插件列表，
并在 `Package.swift` 的 `FactoryLumi` target 依赖里声明 product。

## Testing

From this package directory:

```sh
swift test
```
