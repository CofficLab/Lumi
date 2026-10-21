# TestPlan — PluginNetto

## 包概述

NettoPlugin Manage network permissions for macOS applications.

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 54

核心组件（源码目录）:
- `Bridge/`
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `NettoPlugin`
- `IPCConnection`
- `AppSetting`
- `FirewallEvent`
- `SmartApp`
- `NettoObserver`
- `AppSettingRepo`
- `FilterStatus`
- `NettoViewModel`
- `NettoAboutView`
- `NettoDashboardView`
- `NettoManualView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **NettoModelAndRepo**（25 条）：由 `loadsEmptyWhenFileMissing`、`loadsPersistedSettings`、`preservesCorruptFile` 等用例锁定；改动该模块时优先跑对应测试文件。
- **NettoPluginLifecycle**（14 条）：由 `registerAddsDocsEntries`、`registerWithoutDocsProviderIsNoop`、`bootHidesHeaderAndSetsContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **NettoViewModel**（10 条）：由 `initialState`、`appliesServiceState`、`appliesSettings` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（5 条）：由 `v2PluginPreservesDisabledFirewallCatalogPolicy`、`corruptSettingsFileIsPreservedBeforeSavingNewSettings`、`loadSettingsKeepsPersistedAllowRules` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | NettoModelAndRepo | 文件不存在时设置保持为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `loadsEmptyWhenFileMissing` |
| 2 | NettoModelAndRepo | 合法 JSON 被还原成按 appId 索引的设置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsPersistedSettings` |
| 3 | NettoModelAndRepo | 损坏的文件被移为 .corrupt 且设置清空 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `preservesCorruptFile` |
| 4 | NettoModelAndRepo | 重复损坏时旧的 .corrupt 备份被覆盖 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `overwritesExistingCorruptBackup` |
| 5 | NettoModelAndRepo | 保存后能再次读回同样的设置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `savesAndReloads` |
| 6 | NettoModelAndRepo | 保存会创建缺失的目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsMissingDirectory` |
| 7 | NettoModelAndRepo | 更新设置会覆盖同 appId 的旧值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateReplacesExisting` |
| 8 | NettoModelAndRepo | 未配置的应用默认放行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultsToAllowed` |
| 9 | NettoModelAndRepo | 已配置的应用按设置返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isAllowedReflectsSetting` |
| 10 | NettoModelAndRepo | 延迟加载时不主动读盘 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supportsDeferringLoad` |
| 11 | NettoModelAndRepo | 应用设置的 id 就是 appId | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appSettingIdentity` |
| 12 | NettoModelAndRepo | 应用设置可编解码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appSettingCodable` |
| 13 | NettoModelAndRepo | 防火墙事件描述地址与端口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firewallEventDescription` |
| 14 | NettoModelAndRepo | 被拦截的事件状态为 Blocked | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `firewallEventRejected` |
| 15 | NettoModelAndRepo | 防火墙事件默认带 id 与时间 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `firewallEventDefaults` |
| 16 | NettoModelAndRepo | 两个事件默认 id 互不相同 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firewallEventUniqueIdentifiers` |
| 17 | NettoModelAndRepo | 智能应用的派生属性 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smartAppDerivedProperties` |
| 18 | NettoModelAndRepo | 智能应用的相等性按字段比较 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smartAppEquatable` |
| 19 | NettoModelAndRepo | 未知应用回退为用 id 命名的条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smartAppFromUnknownId` |
| 20 | NettoModelAndRepo | 已知代理应用被识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsKnownProxyApps` |
| 21 | NettoModelAndRepo | 含代理关键词的 bundle id 被识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsProxyByBundleIdentifierKeyword` |
| 22 | NettoModelAndRepo | 只匹配应用名称也能识别代理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsProxyByNameKeyword` |
| 23 | NettoModelAndRepo | 普通应用不被识别为代理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresRegularApps` |
| 24 | NettoModelAndRepo | 状态带可读文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `statusDescriptions` |
| 25 | NettoModelAndRepo | 状态可枚举 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusIsCaseIterable` |
| 26 | NettoPluginLifecycle | 注册时写入关于与说明书文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerAddsDocsEntries` |
| 27 | NettoPluginLifecycle | 缺少文档 Provider 时注册不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerWithoutDocsProviderIsNoop` |
| 28 | NettoPluginLifecycle | 启动后隐藏内容头部并设置内容视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootHidesHeaderAndSetsContent` |
| 29 | NettoPluginLifecycle | 缺少根视图 Provider 时启动不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutRootViewProviderIsNoop` |
| 30 | NettoPluginLifecycle | 关闭时恢复内容头部并清空内容视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRestoresChrome` |
| 31 | NettoPluginLifecycle | 注销时移除文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregisterRemovesDocsEntries` |
| 32 | NettoPluginLifecycle | 插件元数据保持稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 33 | NettoPluginLifecycle | 提示文案包含应用标识与访问目标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageContainsAppAndEndpoint` |
| 34 | NettoPluginLifecycle | 端口为空时只展示主机名 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `omitsEmptyPort` |
| 35 | NettoPluginLifecycle | 不同方向给出不同提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `directionsDiffer` |
| 36 | NettoPluginLifecycle | Provider 侧的注册回调直接返回成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerRegisterSucceeds` |
| 37 | NettoPluginLifecycle | 缺少 Mach 服务名时不会创建监听器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startListenerWithoutMachServiceName` |
| 38 | NettoPluginLifecycle | 初始状态没有活动连接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hasNoCurrentConnection` |
| 39 | NettoPluginLifecycle | 扩展日志与审批请求不会抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extensionHooksAreSafe` |
| 40 | NettoViewModel | 初始状态为未定且没有事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initialState` |
| 41 | NettoViewModel | 同步服务状态后拿到状态与事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appliesServiceState` |
| 42 | NettoViewModel | 同步设置后拿到按 appId 索引的设置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appliesSettings` |
| 43 | NettoViewModel | 未配置的应用默认放行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `isAllowedDefaultsToTrue` |
| 44 | NettoViewModel | 已配置的应用按设置返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isAllowedReflectsSettings` |
| 45 | NettoViewModel | 设置放行状态会写回仓库并刷新视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setAllowedWritesBack` |
| 46 | NettoViewModel | 初始化时立即同步服务状态与设置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `syncsOnInit` |
| 47 | NettoViewModel | 服务状态变化后视图跟着刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshesOnServiceChange` |
| 48 | NettoViewModel | 设置变化后视图跟着刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshesOnRepoChange` |
| 49 | NettoViewModel | 取消后不再跟随服务状态变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsUpdatingAfterCancel` |
| 50 | 综合 | v2PluginPreservesDisabledFirewallCatalogPolicy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginPreservesDisabledFirewallCatalogPolicy` |
| 51 | 综合 | corruptSettingsFileIsPreservedBeforeSavingNewSettings | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `corruptSettingsFileIsPreservedBeforeSavingNewSettings` |
| 52 | 综合 | loadSettingsKeepsPersistedAllowRules | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadSettingsKeepsPersistedAllowRules` |
| 53 | 综合 | loadSettingsHandlesDuplicateAppIdsWithoutCrashing | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadSettingsHandlesDuplicateAppIdsWithoutCrashing` |
| 54 | 综合 | connectionPromptMessageIncludesDecisionContext | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `connectionPromptMessageIncludesDecisionContext` |

> 说明：全部 **54 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 41 / 41
- P2: 已覆盖 8 / 8
- **合计: 54 / 54**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（41 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 54 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginNetto
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
