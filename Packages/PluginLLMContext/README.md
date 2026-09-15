# PluginLLMContext

Lumi 编辑器插件。

## Package

- Product: `PluginLLMContext`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- 为每次 LLM 请求按模型窗口、输出预留、工具 schema 和安全余量计算输入预算。
- 后台生成滚动摘要，并在达到硬阈值时为请求准备压缩上下文。
- 在 ChatToolbar 显示当前模型上下文窗口和 LLMContext 的输入估算；两者使用同一条模型路由，输入估算与压缩逻辑共用校准后的 token 计数。
- 工具栏同时显示 LLMContext 的输入预算，便于区分模型总窗口与扣除输出、工具和安全预留后的可用输入空间。
- 上下文窗口弹窗内含使用趋势曲线：按每次请求实际上报的输入 token 绘制历史，并标出压缩发生的位置。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginLLMContext"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginLLMContext"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
