# PluginOpenInXcode

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginOpenInXcode`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginOpenInXcode"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginOpenInXcode"]),
]
```

## Testing

From this package directory:

```sh
swift test
```

