# PluginAppStoreConnect

Current `KernelCore` implementation of the App Store Connect integration.

- Product/module: `PluginAppStoreConnect`
- Plugin id: `com.coffic.lumi.plugin.app-store-connect`
- Rail tab: `app-store-connect.sidebar`
- Enable policy: disabled by default

The plugin provides App Store Connect account, app/version, localization,
screenshot, release, and Xcode Cloud management through the workbench and
the `app_store_connect_*` Agent tools.

## Chat Toolbar 的版本入口

Chat 分区工具栏上有一个 ASC 胶囊按钮，点击后在 popover 中展示**当前项目
对应 App** 的 App Store 版本列表（按平台分组，显示版本号与状态）。

按钮只在当前项目能解析出 ASC App 绑定时出现；未绑定时工具栏不占位。

### 项目 → App 的绑定规则

按以下优先级解析（前者命中即停止）：

1. **项目配置文件**：`<project>/.lumi/app-store-connect/app.json`
   （读取时兼容历史目录 `.agent/app-store-connect/app.json`）。
2. **Xcode 工程自动识别**：扫描项目根目录的 `*.xcodeproj/project.pbxproj`，
   取其中不含变量占位符的 `PRODUCT_BUNDLE_IDENTIFIER`。

配置文件格式：

```json
{
  "appID": "6758871065",
  "bundleID": "com.example.myapp"
}
```

- `appID`：App Store Connect 的数字 App ID，命中后直接按 ID 读取。
- `bundleID`：目标 App 的 Bundle ID，命中后通过 `filter[bundleId]` 查询。
- 两者都可选；只提供其一即可。

纯 Swift Package 项目没有可发布的 App 目标，因此自动识别会失败——这类项目
需要显式写 `app.json`。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。
