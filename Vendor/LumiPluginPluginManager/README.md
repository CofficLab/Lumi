# LumiPluginPluginManager

Lumi 插件管理器插件的**共享远程包**，供 Lumi / Cisum / GameFactory / GitOK / Kuzee / Wakey
等 CofficLab 兄弟应用共同消费。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Manifest 包名：`LumiPluginPluginManager`（与仓库名一致，符合远程插件包命名规范）
- Product / Target：`PluginPluginManager`（不带 `Lumi` 前缀）
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 命名规范

CofficLab 的远程插件包统一遵循：

| 仓库名 | manifest `name:` | product / target |
| --- | --- | --- |
| `LumiPluginPluginManager` | `LumiPluginPluginManager` | `PluginPluginManager` |
| `LumiPluginActivityBar` | `LumiPluginActivityBar` | `PluginActivityBar` |
| `LumiPluginToast` | `LumiPluginToast` | `PluginToast` |

理由：Xcode 的包依赖列表显示的是上游 manifest 里的 `Package(name:)`，不是仓库名。
manifest 包名不带 `Lumi` 前缀会让用户在 Xcode 里看不到前缀。仓库名保持与包名一致，
消费方 `.product(name:package:)` 的 `package:` 参数按 URL basename 匹配，必须写仓库名。

## 提供什么

- 插件管理入口：浏览插件列表、启用 / 禁用单个插件、跳转到插件设置详情
- 插件 About / 手册页面贡献（通过 `ProviderDocsView`）
- 「浏览插件」快捷建议注册（通过 `ProviderPromptSuggestion`）

## 启停失败反馈

启用 / 停用插件失败时，页面会用 `AppErrorBanner` 展示失败原因，而不是让开关
静默停留在与实际不一致的位置。

失败原因来自底层 `PluginControlling.lastErrorDescription`（经
`PluginManagementCapability` 透出），成功一次即清空。

## 响应式布局

| 宽度 | 布局 |
| --- | --- |
| 常规（macOS / iPad） | 左侧插件列表 + 右侧详情面板的贴边分栏 |
| 紧凑（iPhone） | 插件列表，点击后 `NavigationLink` 推入详情面板 |

分栏形态是设置页的基准（列表栏 300、详情栏内边距 22、贴边无外框），
紧凑形态只改容器排布，列表行与详情面板本身保持一致。

## 依赖与集成

```swift
dependencies: [
    .package(url: "https://github.com/CofficLab/LumiPluginPluginManager.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "PluginPluginManager", package: "LumiPluginPluginManager"),
        ],
    ),
]
```

注意 `package:` 必须是仓库名 `LumiPluginPluginManager`，不是 product 名。

## 品牌化：注入自己的插件 id

宿主应用可以用自己的品牌 id 复用本包（与 `PluginSettingView` / `PluginStorage` /
`PluginToast` 的做法一致）。不传参时使用默认的 `com.coffic.lumi.plugin.plugin-manager`。

```swift
PluginPluginManager(id: "com.coffic.wakey.plugin.plugin-manager")
```

注入后以下三处同步跟随：

| 位置 | 取值 |
| --- | --- |
| `PluginPluginManager.id` | 注入的 id |
| `PluginPluginManager.metadata.id` | 注入的 id |
| 日志 subsystem（`Logger`） | 注入的 id |

设置入口 id 恒为 `"plugin-manager"`（与品牌无关，供设置深链使用）；
提示建议 id 为 `"\(id).browse"`。

> 更换 id 会同时更换插件的启用状态存储键：宿主切换 id 前需确认历史状态是否需要迁移。

## 入口可见性：无可配置插件时隐藏入口

插件管理页只列出**用户可配置**的插件（`PluginEnablePolicy.isConfigurable`，
即 `enabledByDefault` / `disabledByDefault`）。

若宿主的插件策略全是 `required` / `alwaysOn`（`isConfigurable` 为 false），
这个页面必然是一个永远为空的列表 —— 这样的入口对用户没有意义，反而让人以为
功能坏了。

**默认行为就是隐藏**：宿主零配置即可得到正确结果，无需在 Factory 里写任何
参数。宿主将来加入可配置插件时，入口会自动出现。

| 策略 | 行为 |
| --- | --- |
| `.onlyWhenConfigurablePluginsExist`（默认） | 仅当宿主存在用户可配置的插件时注册入口 |
| `.always` | 始终注册「插件管理」入口 |

绝大多数宿主不需要显式传任何值：

```swift
PluginPluginManager()   // 零配置：无可配置插件时不显示入口
```

仅在宿主明知自己没有可配置插件、却仍要保留这个入口时才显式覆盖：

```swift
PluginPluginManager(entryVisibility: .always)
```

> 判断发生在 `onReady` 阶段（而非 `onBoot`）：`KernelCoreContainer.start` 先注册
> 全部插件、再逐个执行 `onBoot`，`onBoot` 阶段 order 更大的插件尚未注册，
> 据此判断会漏掉插件。

「浏览插件」提示建议跟随入口：入口不存在时不会注册该建议 —— 它的动作是
`openSettingsTab("plugin-manager")`，入口被撤掉后这个深链就是死路。

> 入口的可见性在启动时判定一次。当前插件目录是编译期固定的
> （`unloadPlugin` / `reloadPlugin` 在生产代码中未被调用），运行期插件列表
> 事实上不会变化，因此不需要监听插件列表变化事件。

## Testing

From this package directory:

```sh
swift test
```

## 能力边界

`PluginManagementViewModel` 原先直接持有 `any DocsViewProviding`，现改为只依赖
`PluginManagerDocsCapability`（`aboutEntry(for:)`），由
`PluginManagerDocsCapabilityAdapter` 收窄内核的 `DocsViewProviding`。

注册 / 移除 About 条目仍由插件入口负责（它们属于组装层职责），不需要进入窄协议。
