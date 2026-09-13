# PluginToolbar

Lumi 插件。以自研 `ToolbarProvider` 替换 `DefaultProviderFactory` 预注册的
`DefaultToolbarProviding`，并提供完全自实现的工具栏渲染视图。

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
