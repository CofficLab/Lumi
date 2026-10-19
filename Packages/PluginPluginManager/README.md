# PluginPluginManager

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginPluginManager`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginPluginManager"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginPluginManager"]),
]
```

## Testing

From this package directory:

```sh
swift test
```


## 能力边界

`PluginManagementViewModel` 原先直接持有 `any DocsViewProviding`，现改为只依赖
`PluginManagerDocsCapability`（`aboutEntry(for:)`），由
`PluginManagerDocsCapabilityAdapter` 收窄内核的 `DocsViewProviding`。

注册 / 移除 About 条目仍由插件入口负责（它们属于组装层职责），不需要进入窄协议。
