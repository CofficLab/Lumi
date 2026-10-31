# TestPlan — FactoryLumi

## 包概述

FactoryLumi Lumi 的**装配根**（Composition Root）：将 KernelCore 内核、全部 Provider 默认实现、 100+ 插件与视图组装集中在一个包中完成接线，是 Lumi 主应用启动的唯一入口。 ## 职责 FactoryLumi 不包含业务逻辑，只负责**把正确的事情在正确的时机做对**： | 职责 | 实现 | 说明 | | --- | --- | --- | | 内核创建 | `KernelFactory` | 创建 `KernelCoreContainer`，装配 Provider，启动插件 | | Provider 工厂 | `DefaultProviderFactory` | 产出 30+ 个 Provider 默认实现并按依赖顺序注册 | | Plugin 工厂 | `DefaultPluginFactory` | 产出 100+ 个插件，统一校验、排序、原子启动 | | View 工厂 | `DefaultViewFactory` | 用内核 Provider 组装主视图与设置视图 | | 菜单集成 | `AppCommands` | 把 `CommandProviding` 贡献映射到 macOS 系统菜单 | | 主题桥接 | `PaletteChromeTheme` | 把新版 `LumiThemePalette` 适配回 LumiUI 旧版 chrome 主题 | ## 三大工厂协议 ```swift /// 产出全部插件。宿主可实现该协议覆盖插件列表。 protocol PluginFactory {

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 45

核心组件（源码目录）:
- `Contracts/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppCommands`
- `KernelFactory`
- `PluginDataMigrationCoordinator`
- `BookletMakerChatVisibilityProxy`
- `DefaultProviderFactory`
- `DefaultViewFactory`
- `PluginFactory`
- `ProviderFactory`
- `ViewFactory`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationManagerReplacement**（2 条）：由 `replacesDefaultConversationManaging`、`resolvedProviderIsUsable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（37 条）：由 `defaultFactoryIncludesEditorPluginStack`、`defaultFactoryIncludesMailPlugin`、`selectedPluginFactoryFiltersTheCatalog` 等用例锁定；改动该模块时优先跑对应测试文件。
- **IdleTimeProvider**（1 条）：由 `makeIdleTimeProviderReturnsFullService` 等用例锁定；改动该模块时优先跑对应测试文件。
- **KernelFactoryInfrastructure**（3 条）：由 `startsAsyncPlugins`、`migratesPluginDataBeforeBoot`、`registersInfrastructureProviders` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListSlotArbitration**（2 条）：由 `persistedConversationDoesNotRenderEmptyState`、`emptyStateDoesNotClaimSlotWhileEvaluationPending` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationManagerReplacement | 插件注册且 ConversationManaging 被替换为 SwiftData 实现 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `replacesDefaultConversationManaging` |
| 2 | ConversationManagerReplacement | 替换后消费方可解析并使用持久化实现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedProviderIsUsable` |
| 3 | 综合 | 默认插件目录包含编辑器基础设施、语言包和可选工作区 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultFactoryIncludesEditorPluginStack` |
| 4 | 综合 | 默认目录包含邮件插件（disabledByDefault） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultFactoryIncludesMailPlugin` |
| 5 | 综合 | SelectedPluginFactory 仅产出白名单插件并保持原目录顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedPluginFactoryFiltersTheCatalog` |
| 6 | 综合 | makeKernel 启动 ModelSelectorPlugin 并注册 Action Bar 模型选择按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelRegistersModelSelectorActionBarButton` |
| 7 | 综合 | makeKernel 注册当前对话 HTML 导出按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelRegistersConversationExportToolbarButton` |
| 8 | 综合 | makeKernel 创建内核并注册默认 StorageProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultStorageProvider` |
| 9 | 综合 | makeKernel 注入插件启用状态持久化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelWiresPluginStateStore` |
| 10 | 综合 | makeKernel 创建内核并注册默认 ProjectProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultProjectProviding` |
| 11 | 综合 | makeKernel 创建内核并注册默认 ConversationManaging | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultConversationManaging` |
| 12 | 综合 | makeKernel 创建内核并注册默认 ToastProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultToastProviding` |
| 13 | 综合 | makeKernel 创建内核并注册默认 NetworkProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultNetworkProviding` |
| 14 | 综合 | makeKernel 创建内核并安装共享 PluginToolbar | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultToolbarProviding` |
| 15 | 综合 | makeKernel 创建内核并注册默认 RootViewProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultRootViewProviding` |
| 16 | 综合 | makeKernel 创建内核并注册默认 ActivityBarProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultActivityBarProviding` |
| 17 | 综合 | 默认内容插件注册 ActivityBar 入口且设备入口初始激活 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultContentPluginsRegisterActivityBarEntries` |
| 18 | 综合 | makeKernel 创建内核并注册默认 RailViewProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultRailViewProviding` |
| 19 | 综合 | makeKernel 创建内核并注册默认 SettingViewProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultSettingViewProviding` |
| 20 | 综合 | 内核可解析出 ProjectProviding 并正常使用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `kernelResolvesUsableProvider` |
| 21 | 综合 | ProviderFactory 产出默认 Provider 实现 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerFactoryMakesDefaults` |
| 22 | 综合 | makeMainView 返回可渲染的根视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeMainViewReturnsRootView` |
| 23 | 综合 | makeSettingsView 返回可渲染的设置视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeSettingsViewReturnsSettingsView` |
| 24 | 综合 | makeKernel 启动插件后设置视图含「通用」与「设备信息」入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelBootsPluginsAndRegistersEntries` |
| 25 | 综合 | 默认目录复刻旧版 Project RAG 插件与 search_code 工具 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultCatalogIncludesProjectRAG` |
| 26 | 综合 | makeKernel 启动 SettingsToolbarPlugin 后工具栏含设置按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelBootsToolbarSettingsPlugin` |
| 27 | 综合 | makeKernel 注册 DocsViewProviding 且 DevicePlugin 已贡献文档 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelRegistersDocsViewProviding` |
| 28 | 综合 | makeKernel 注册 MenuBarProviding 且 DevicePlugin 已贡献菜单栏 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelRegistersMenuBarProviding` |
| 29 | 综合 | makeKernel 创建内核并注册默认 LogoProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultLogoProviding` |
| 30 | 综合 | ProviderFactory 产出默认 LogoProviding 实现 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerFactoryMakesDefaultLogo` |
| 31 | 综合 | 装配后的 LogoProviding 注册 LogoCofficPlugin 贡献并可查询最高优先级 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `kernelLogoProviderRegistersAndQueries` |
| 32 | 综合 | makeKernel 启动 ThemePackPlugin 后注册全部复刻主题 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelBootsThemePackAndRegistersThemes` |
| 33 | 综合 | makeKernel 注册 ThemePackPlugin 外观设置入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelRegistersAppearanceSettingEntry` |
| 34 | 综合 | 宿主可注入附加插件而无需修改默认插件目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeKernelAcceptsAdditionalPlugins` |
| 35 | 综合 | 停止内核会撤回默认插件写入共享 Provider 的贡献并支持重启 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopWithdrawsContributionsAndSupportsRestart` |
| 36 | 综合 | makeKernel 注册默认 LLMManaging | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeKernelRegistersDefaultLLMProviderManager` |
| 37 | 综合 | ProviderFactory 产出默认 LLMManaging 实现 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerFactoryMakesDefaultLLMProviderManager` |
| 38 | 综合 | 内核装配后：注册供应商进管理器即可经管理器路由发送 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `kernelRoutesThroughRegisteredProvider` |
| 39 | 综合 | 设置窗口默认选中 order 最小的入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsSelectsFirstEntryByOrderOnBoot` |
| 40 | IdleTimeProvider | makeIdleTimeProvider 返回完整 IdleTimeService 并持久化到插件目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makeIdleTimeProviderReturnsFullService` |
| 41 | KernelFactoryInfrastructure | 异步 Factory 入口启动异步插件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startsAsyncPlugins` |
| 42 | KernelFactoryInfrastructure | KernelFactory 在插件启动前迁移全部旧版本目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `migratesPluginDataBeforeBoot` |
| 43 | KernelFactoryInfrastructure | Factory 注册可替换 WebServer 与真实 PluginControl | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersInfrastructureProviders` |
| 44 | MessageListSlotArbitration | 已落库消息的会话不应渲染空态 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `persistedConversationDoesNotRenderEmptyState` |
| 45 | MessageListSlotArbitration | 判定进行中空态不得抢占槽位 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyStateDoesNotClaimSlotWhileEvaluationPending` |

> 说明：全部 **45 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 23 / 23
- P2: 已覆盖 21 / 21
- **合计: 45 / 45**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（21 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 45 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/FactoryLumi
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
