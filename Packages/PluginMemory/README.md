# PluginMemory

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginMemory`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginMemory"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginMemory"]),
]
```

## Testing

From this package directory:

```sh
swift test
```


## 能力边界

四个工具都只需要「当前项目路径」用于分域存取（`project` scope 的记忆按项目隔离），
因此共享 `MemoryProjectCapability`，由 `MemoryProjectCapabilityAdapter` 收窄内核的
`ProjectProviding`。工具层不再 import `ProviderProject`，也不直接持有 `any ProjectProviding`。

Adapter 在 `onBoot` 中构造一次并被四个工具共享。
