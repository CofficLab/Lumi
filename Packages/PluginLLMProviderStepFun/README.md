# PluginLLMProviderStepFun

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginLLMProviderStepFun`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- `StepFunProvider`：Step Plan 通道，只暴露 `step-router-v1`。
- `StepFunPlatformProvider`：开放平台标准 Chat Completions 通道，提供 Step 5、Step 3.x 与 StepAudio Chat 模型。
- 两个 Provider 共享同一个 StepFun API Key，但使用独立端点，避免模型被发送到不兼容的通道。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginLLMProviderStepFun"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginLLMProviderStepFun"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
