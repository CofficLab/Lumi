# PluginGitWorkspace

Lumi 编辑器插件。

## Package

- Product: `PluginGitWorkspace`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginGitWorkspace"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginGitWorkspace"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
