# PluginAppStoreConnect

Current `KernelCore` implementation of the App Store Connect integration.

- Product/module: `PluginAppStoreConnect`
- Plugin id: `com.coffic.lumi.plugin.app-store-connect`
- Rail tab: `app-store-connect.sidebar`
- Enable policy: disabled by default

The plugin provides App Store Connect account, app/version, localization,
screenshot, release, and Xcode Cloud management through the workbench and
the `app_store_connect_*` Agent tools.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。
