# PluginDeveloperMode

Lumi 编辑器插件。

## Package

- Product: `PluginDeveloperMode`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginDeveloperMode"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginDeveloperMode"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
