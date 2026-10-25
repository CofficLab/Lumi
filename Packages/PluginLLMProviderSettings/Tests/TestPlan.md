# TestPlan — PluginLLMProviderSettings

## 包概述

PluginLLMProviderSettings 的实现包，包含 14 个主要类型；当前测试覆盖 79 条用例。

平台: macOS 14+, iOS 17+
测试文件: 7 个，用例总数: 79

核心组件（源码目录）:
- `Capabilities/`
- `LLMProviders/`
- `Models/`
- `Observers/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `LLMProviderSettingsPlugin`
- `ModelDownloadCapability`
- `ProviderSettingsCapability`
- `UserDefinedCloudProviderStoreProviding`
- `CustomCloudProviderForm`
- `ProviderModelDownloadObserver`
- `ProviderSettingsAccessibility`
- `ProviderDetailViewModel`
- `ProviderModelDownloadViewModel`
- `ProviderSettingsPageViewModel`
- `ProviderSettingsScope`
- `CustomCloudProviderEditor`
- `ProviderDetailView`
- `ProviderModelDownloadView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CustomCloudProviderForm**（17 条）：由 `parsesModelIDsSeparatedByNewlines`、`parsesModelIDsSeparatedByCommas`、`parsesModelIDsSeparatedByMixedDelimiters` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LLMProviderSettingsPlugin**（6 条）：由 `pluginRegistersSettingEntries`、`pluginShutdownRemovesEntries`、`pluginBootWithoutManagerIsNoop` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderDetailModelRefresh**（8 条）：由 `exposesRefreshEntryOnlyForRemoteProviders`、`noRefreshEntryForUnregisteredProvider`、`refreshUpdatesModels` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderSettingsPageViewModel**（14 条）：由 `listsNewlyAddedCloudProvider`、`customProviderRevisionIncrementsOnStoreChange`、`newlyAddedProviderIsSearchable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderSettingsScopeViewModel**（4 条）：由 `defaultsToCloudScope`、`switchingScopeSwapsListAndSelection`、`scopesKeepIndependentSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UserDefinedCloudProviderConfiguration**（17 条）：由 `rejectsEmptyOrWhitespaceDisplayName`、`trimsDisplayName`、`rejectsEmptyIdentifier` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UserDefinedCloudProviderStore**（13 条）：由 `upsertPersistsAndRegistersProvider`、`upsertReplacesConfigurationWithSameIdentifier`、`upsertRejectsInvalidConfigurationWithoutSideEffects` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CustomCloudProviderForm | 模型 ID 按换行切分并保持顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesModelIDsSeparatedByNewlines` |
| 2 | CustomCloudProviderForm | 模型 ID 按逗号切分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesModelIDsSeparatedByCommas` |
| 3 | CustomCloudProviderForm | 模型 ID 混合换行与逗号切分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesModelIDsSeparatedByMixedDelimiters` |
| 4 | CustomCloudProviderForm | 模型 ID 去掉首尾空白并丢弃空项 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `trimsWhitespaceAndDropsEmptyModelIDs` |
| 5 | CustomCloudProviderForm | 模型 ID 解析保留重复项，交由校验层报错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `preservesDuplicateModelIDsForValidation` |
| 6 | CustomCloudProviderForm | 空白模型 ID 文本解析为空列表 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `parsesEmptyModelIDTextAsEmptyList` |
| 7 | CustomCloudProviderForm | 名称为空或全是空白时不允许保存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canSaveRequiresNonBlankDisplayName` |
| 8 | CustomCloudProviderForm | 新增配置使用注入的 ID 生成器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsConfigurationWithInjectedIdentifier` |
| 9 | CustomCloudProviderForm | 新增配置的默认 ID 带 user- 前缀且为小写 UUID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsConfigurationWithGeneratedIdentifier` |
| 10 | CustomCloudProviderForm | 编辑既有供应商时沿用原 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsConfigurationReusingExistingIdentifier` |
| 11 | CustomCloudProviderForm | 配置构造把第一个模型设为默认模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `buildsConfigurationDefaultingToFirstModel` |
| 12 | CustomCloudProviderForm | 配置构造保留选定的 API 协议格式 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsConfigurationPreservingAPIFormat` |
| 13 | CustomCloudProviderForm | 编辑时按模型 ID 继承既有模型元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsConfigurationInheritingExistingModelMetadata` |
| 14 | CustomCloudProviderForm | 官网为空串时配置为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsConfigurationWithNilWebsiteWhenBlank` |
| 15 | CustomCloudProviderForm | 官网去掉首尾空白后存储 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsConfigurationTrimmingWebsiteURL` |
| 16 | CustomCloudProviderForm | 由既有配置回填表单时模型逐行展开 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formIsSeededFromExistingConfiguration` |
| 17 | CustomCloudProviderForm | 回填后再构造配置保持模型顺序与元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reseededFormRebuildsEquivalentConfiguration` |
| 18 | LLMProviderSettingsPlugin | onBoot 注册一个合并的供应商设置入口（云端 / 本地共用一页） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersSettingEntries` |
| 19 | LLMProviderSettingsPlugin | onShutdown 撤回设置入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginShutdownRemovesEntries` |
| 20 | LLMProviderSettingsPlugin | 无管理器时 onBoot 静默跳过 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginBootWithoutManagerIsNoop` |
| 21 | LLMProviderSettingsPlugin | 设置页数据源来自管理器注册表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsPageReadsManagerRegistry` |
| 22 | LLMProviderSettingsPlugin | 自定义供应商保存后可恢复并自动注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customProviderPersistsAndRestores` |
| 23 | LLMProviderSettingsPlugin | 删除自定义供应商会注销运行时实例并更新磁盘配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removingCustomProviderUnregistersAndPersists` |
| 24 | ProviderDetailModelRefresh | 远程模型源供应商显示刷新入口，静态供应商不显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exposesRefreshEntryOnlyForRemoteProviders` |
| 25 | ProviderDetailModelRefresh | 未注册的供应商没有刷新入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noRefreshEntryForUnregisteredProvider` |
| 26 | ProviderDetailModelRefresh | 刷新成功后模型列表同步为新的动态模型池 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshUpdatesModels` |
| 27 | ProviderDetailModelRefresh | 刷新失败时保留旧模型池并展示错误原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshFailureKeepsOldModels` |
| 28 | ProviderDetailModelRefresh | 刷新成功后清空上一次的错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshSuccessClearsPreviousError` |
| 29 | ProviderDetailModelRefresh | 不支持远程模型列表的供应商不触发刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotRefreshStaticProvider` |
| 30 | ProviderDetailModelRefresh | 刷新成功会广播 modelsRefreshed 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshBroadcastsModelsRefreshedEvent` |
| 31 | ProviderDetailModelRefresh | 刷新失败不广播 modelsRefreshed 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshFailureDoesNotBroadcastEvent` |
| 32 | ProviderSettingsPageViewModel | 新增自定义供应商后立即出现在云端供应商列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listsNewlyAddedCloudProvider` |
| 33 | ProviderSettingsPageViewModel | 新增自定义供应商会刷新自定义供应商修订号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customProviderRevisionIncrementsOnStoreChange` |
| 34 | ProviderSettingsPageViewModel | 新增后可以按名称搜索到该供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `newlyAddedProviderIsSearchable` |
| 35 | ProviderSettingsPageViewModel | 新增后供应商计数标签同步更新 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerCountLabelReflectsAddedProvider` |
| 36 | ProviderSettingsPageViewModel | 新增后选中态自动落到新供应商并显示其模型数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectsNewlyAddedProviderAndReportsModelCount` |
| 37 | ProviderSettingsPageViewModel | 删除自定义供应商后列表同步移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesProviderFromListAfterDeletion` |
| 38 | ProviderSettingsPageViewModel | 新增供应商可生成空白编辑器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makesNewCustomProviderEditor` |
| 39 | ProviderSettingsPageViewModel | 没有自定义供应商 Store 时不生成编辑器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makesNoEditorWithoutStore` |
| 40 | ProviderSettingsPageViewModel | 云端页与本地页各自只显示对应作用域的供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scopesProvidersByLocalFlag` |
| 41 | ProviderSettingsPageViewModel | 搜索匹配名称、描述与 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersProvidersBySearchText` |
| 42 | ProviderSettingsPageViewModel | 没有选中项时自动选中第一个供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `synchronizeSelectionSelectsFirstProvider` |
| 43 | ProviderSettingsPageViewModel | 选中项仍然有效时保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `synchronizeSelectionKeepsValidSelection` |
| 44 | ProviderSettingsPageViewModel | 选中项被删除后回退到仍然存在的供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `synchronizeSelectionFallsBackWhenSelectedProviderDisappears` |
| 45 | ProviderSettingsPageViewModel | 列表为空时没有选中项 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `synchronizeSelectionClearsWhenListEmpty` |
| 46 | ProviderSettingsScopeViewModel | 合并页默认停在云端，列表里只有云端供应商 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultsToCloudScope` |
| 47 | ProviderSettingsScopeViewModel | 切到本地后列表与详情换成本地供应商，并自动选中第一项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `switchingScopeSwapsListAndSelection` |
| 48 | ProviderSettingsScopeViewModel | 两个范围各自记住自己的选中项，来回切不互相污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scopesKeepIndependentSelection` |
| 49 | ProviderSettingsScopeViewModel | 范围枚举提供云端 / 本地两个页签标题与图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `scopeExposesTitlesAndIcons` |
| 50 | UserDefinedCloudProviderConfiguration | 名称为空或全是空白时校验失败（空串与空白串） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyOrWhitespaceDisplayName` |
| 51 | UserDefinedCloudProviderConfiguration | 校验通过后名称去掉首尾空白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsDisplayName` |
| 52 | UserDefinedCloudProviderConfiguration | ID 为空时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyIdentifier` |
| 53 | UserDefinedCloudProviderConfiguration | Base URL 非法时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidBaseURL` |
| 54 | UserDefinedCloudProviderConfiguration | HTTP 与 HTTPS 的 Base URL 都合法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsHTTPAndHTTPSBaseURL` |
| 55 | UserDefinedCloudProviderConfiguration | 校验通过后 Base URL 去掉首尾空白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsBaseURL` |
| 56 | UserDefinedCloudProviderConfiguration | 模型列表为空时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyModelList` |
| 57 | UserDefinedCloudProviderConfiguration | 模型 ID 重复时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsDuplicateModelIDs` |
| 58 | UserDefinedCloudProviderConfiguration | 模型 ID 为空白时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsBlankModelID` |
| 59 | UserDefinedCloudProviderConfiguration | 默认模型不在列表中时回退到第一个模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackToFirstModelWhenDefaultMissing` |
| 60 | UserDefinedCloudProviderConfiguration | 默认模型在列表中时保持不变 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsDefaultModelWhenPresent` |
| 61 | UserDefinedCloudProviderConfiguration | Responses 格式关闭工具调用能力 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesFormatDisablesToolSupport` |
| 62 | UserDefinedCloudProviderConfiguration | OpenAI 与 Anthropic 格式保留工具调用能力 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherFormatsKeepToolSupport` |
| 63 | UserDefinedCloudProviderConfiguration | 未知的 API 格式原始值回退到 OpenAI | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownAPIFormatFallsBackToOpenAI` |
| 64 | UserDefinedCloudProviderConfiguration | API Key 存储键按供应商 ID 隔离 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyStorageKeyIsScopedByProviderID` |
| 65 | UserDefinedCloudProviderConfiguration | 官网为空串时解析为 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `websiteURLIsNilWhenEmpty` |
| 66 | UserDefinedCloudProviderConfiguration | 错误描述非空且为中文提示 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `errorDescriptionsAreNotEmpty` |
| 67 | UserDefinedCloudProviderStore | 新增供应商后配置落盘并注册到管理器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertPersistsAndRegistersProvider` |
| 68 | UserDefinedCloudProviderStore | 同一 ID 再次新增是覆盖而不是追加 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertReplacesConfigurationWithSameIdentifier` |
| 69 | UserDefinedCloudProviderStore | 配置非法时新增失败且不落盘不注册 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `upsertRejectsInvalidConfigurationWithoutSideEffects` |
| 70 | UserDefinedCloudProviderStore | 未装配管理器时新增失败并报持久化错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertFailsWhenManagerNotAttached` |
| 71 | UserDefinedCloudProviderStore | 删除供应商会注销运行时实例并更新磁盘配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeUnregistersProviderAndDeletesConfiguration` |
| 72 | UserDefinedCloudProviderStore | 删除不存在的 ID 是空操作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeIgnoresUnknownIdentifier` |
| 73 | UserDefinedCloudProviderStore | 重启后从磁盘恢复自定义供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoresConfigurationsFromDisk` |
| 74 | UserDefinedCloudProviderStore | 装配时把磁盘上的供应商注册进管理器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attachRegistersRestoredProviders` |
| 75 | UserDefinedCloudProviderStore | 磁盘上损坏的配置在加载时被丢弃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dropsInvalidConfigurationsWhenLoading` |
| 76 | UserDefinedCloudProviderStore | 磁盘文件不存在时加载为空配置 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `loadsEmptyWhenFileMissing` |
| 77 | UserDefinedCloudProviderStore | 能识别某个 ID 是否为自定义供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsCustomProviderMembership` |
| 78 | UserDefinedCloudProviderStore | 自定义供应商按所选 API 格式暴露对应配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userDefinedProviderExposesFormatSpecificConfiguration` |
| 79 | UserDefinedCloudProviderStore | 自定义供应商在管理器中暴露为云端供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userDefinedProviderIsRegisteredAsRemoteProvider` |

> 说明：全部 **79 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 9 / 9
- P1: 已覆盖 58 / 58
- P2: 已覆盖 12 / 12
- **合计: 79 / 79**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（9 条）
- **P1**: 其余功能性用例（58 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（12 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 79 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMProviderSettings
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
