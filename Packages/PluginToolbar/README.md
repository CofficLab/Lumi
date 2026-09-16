# PluginToolbar

Lumi 插件。以自研 `ToolbarProvider` 替换 `DefaultProviderFactory` 预注册的
`DefaultToolbarProviding`，并提供完全自实现的工具栏渲染视图。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginToolbar`
- Platform: macOS 14+
- Swift tools: 6.0

## 执行顺序

`order = 0`：必须早于**所有**解析 `ToolbarProviding` 的插件。
`PluginChatPanel` 与 `PluginDeveloperMode`（均为 order=1）会把解析到的 toolbar
引用捕获进延迟闭包，在工作区切换时再次调用；若本插件晚于它们启动，这些调用
会打在被替换掉的旧实例上而静默失效。

## Testing

From this package directory:

```sh
swift test
```

