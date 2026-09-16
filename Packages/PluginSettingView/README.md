# PluginSettingView

设置视图管理器插件（KernelCore 生态）。

以自研 `SettingViewManager` 替换 `ProviderFactory` 预注册的 `DefaultSettingViewProviding`，
提供带结构化日志的 `SettingViewProviding` 实现。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。
