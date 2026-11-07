# LumiPluginIdleTime

Lumi 编辑器插件（空闲时间追踪）。

> 插件包契约：不对其它具体插件产生实现依赖，只消费 `LumiProviders` 提供的 `*Providing` 能力。

## Package

- Package: `LumiPluginIdleTime`
- Product: `PluginIdleTime`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 提供什么

空闲时间活动追踪插件。宿主在 `onBoot` 解析内核注册的 `IdleTimeProviding`：

- 监听应用激活、编辑器保存等活动事件，节流后喂给服务做休息窗口推断；
- 贡献关于文档与使用手册。

## 依赖与集成

```swift
dependencies: [
    .package(url: "https://github.com/CofficLab/LumiPluginIdleTime.git", from: "1.0.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "PluginIdleTime", package: "LumiPluginIdleTime"),
    ]),
]
```

宿主还需在 `PluginFactory` 中实例化 `IdleTimePlugin()`，并在 `ProviderFactory` 中注册
`IdleTimeProviding`（工厂已内置 `IdleTimeService` 默认实现）。

## Testing

```sh
swift test
```