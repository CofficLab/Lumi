# PluginOpenInGitOK

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginOpenInGitOK`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginOpenInGitOK"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginOpenInGitOK"]),
]
```

## Testing

From this package directory:

```sh
swift test
```


## 能力边界

标题栏 ViewModel 只关心「当前项目路径」和「项目切换事件」，因此插件声明自己的窄能力
`OpenInProjectCapability`，由 `OpenInProjectCapabilityAdapter` 收窄内核的 `ProjectProviding`：

- `currentProjectPath: String?`
- `addProjectObserver(_:)` → 返回插件自有的 `OpenInProjectObserverHandle`

内核的 `ProjectProvidingEvent` 与 `ProjectProvidingObserverHandle` 不泄漏给 ViewModel，
Adapter 内部把 `currentProjectChanged(ProjectInfo?, reason:)` 映射为
`OpenInProjectEvent.currentProjectChanged(String?)`。

Provider 允许为 `nil`（未注册项目能力时）；此时能力退化为「无项目」语义，标题栏按钮保持禁用。

Provider 解析与 Adapter 构造都在插件入口 `onBoot(kernel:)` 完成；ViewModel 以强引用持有
Adapter，`onDisappear` 时调用 `cancel()` 释放观察订阅。
