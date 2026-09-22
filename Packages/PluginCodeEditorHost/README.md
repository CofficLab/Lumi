# PluginCodeEditorHost

Lumi 编辑器插件。

> **重要规则：运行时代码不依赖其他插件包，也不向其他插件包暴露内部实现。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配。集成测试可以直接依赖 Host 验证装配行为。

## Package

- Product: `PluginCodeEditorHost`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- 实现 `ProviderEditor` 定义的编辑器能力，并注册编辑器宿主服务。
- 承载编辑器视图、语言运行时、内核和服务门面之间的具体装配。
- 作为插件扩展接入编辑器的唯一具象宿主。

## 内部服务实现

`EditorService` 是本包内的内部 SwiftPM target，不是独立 package/product。它负责编辑器服务门面、工作台状态、LSP 协作与扩展注册；其他插件只能面向 `ProviderEditor` 协议扩展，不应依赖或导入此 target。

可复用的编辑器层分别归入 `KitEditorKernel`、`KitEditorSource`、`KitEditorTextView` 和 `KitEditorLanguageRuntime`。整体依赖与扩展边界见 [编辑器架构说明](../../docs/editor-architecture.md)。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginCodeEditorHost"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginCodeEditorHost"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
