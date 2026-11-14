# PluginConversationElapsedTime

在 Chat header 栏右侧显示当前对话的**总模型工作时间**；点击后弹出 popover 展示等待首 token / 生成时长的拆分。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginConversationElapsedTime`
- Platform: macOS 14+, iOS 17+
- Swift tools: 6.0

## 提供什么

- `ChatSectionBarItem(placement: .headerTrailing)` 贡献项：header 栏右侧的模型用时指示器，排序紧挨 token 用量。
- `ElapsedTimeStats`：从会话消息聚合模型工作时间。
- `ElapsedTimeObserver`：转发会话选择与消息变化事件。

### 数据口径

- 只统计 **assistant** 消息：每条对应一次真实的模型请求。
- 主指标是 `latencyMs`（一次请求从发出到完整响应返回的端到端耗时）之和。
- **空闲不计入**：用户思考、等待输入的时段不产生 assistant 消息，
  因此不会出现在统计里。跑 10 分钟 + 空闲 20 分钟 + 再跑 10 分钟 = 20 分钟。
- 工具执行时间不计入：它属于工具调用，不是模型推理。
- 没有计时数据的老消息与失败后落下的空响应不参与统计（宁可少算，
  也不用 0 冒充一次请求）。

### 已知偏差

- **进行中的请求不计入**：计时在响应结束后才落库，模型正在跑的时候这个数字不动。
- **失败 / 空响应 / 被取消的请求耗时丢失**：这些不产生 assistant 消息，总量会略低于真实值。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginConversationElapsedTime"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginConversationElapsedTime"]),
]
```

宿主还需要把它加进 `DefaultPluginFactory.makePlugins()` 的插件列表，
并在 `Package.swift` 的 `FactoryLumi` target 依赖里声明 product。

## Testing

From this package directory:

```sh
swift test
```
