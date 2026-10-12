# PluginRootView

Lumi 的根布局插件。

本包不是公共 `ProviderRootView` Provider。公共协议与默认实现来自远程
`LumiProviders` 包，本包只提供 Lumi 专属的桌面布局、视图装配和
`RootViewPlugin` 生命周期适配。

## Package

- Product: `PluginRootView`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 提供什么

- `LumiRootViewProvider`：继承远程 `DefaultRootViewProviding` 的 Lumi 根布局实现。
- `RootViewPlugin`：在插件启动时向 Kernel 注册 `RootViewProviding`，关闭时撤销注册。
- macOS 与 iOS 共用的根布局装配能力；应用可以通过 `ProviderFactory` 返回自己的 Provider 覆盖默认实现。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginRootView"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginRootView"]),
]
```

公共 Provider 直接来自远程包：

```swift
.package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7")
```

## Testing

From this package directory:

```sh
swift test
```
