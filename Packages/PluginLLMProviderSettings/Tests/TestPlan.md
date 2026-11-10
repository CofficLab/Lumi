# TestPlan — PluginLLMProviderSettings

## 包概述

PluginLLMProviderSettings 的实现包，包含 14 个主要类型；当前测试覆盖 54 条用例。

平台: macOS 14+, iOS 17+
测试文件: 7 个，用例总数: 57

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

- **CustomCloudProviderForm**（19 条）：由 `parsesModelIDsSeparatedByNewlines`、`parsesModelIDsSeparatedByCommas`、`parsesModelIDsSeparatedByMixedDelimiters` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LLMProviderSettingsPlugin**（6 条）：由 `pluginRegistersSettingEntries`、`pluginShutdownRemovesEntries`、`pluginBootWithoutManagerIsNoop` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderDetailModelRefresh**（8 条）：由 `exposesRefreshEntryOnlyForRemoteProviders`、`noRefreshEntryForUnregisteredProvider`、`refreshUpdatesModels` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderDetailCustomProviderRemoval**（2 条）：由 `removalFailureSurfacesErrorAndKeepsProvider`、`removalSuccessClearsPreviousError` 锁定；改动删除自定义供应商链路时优先跑对应测试文件。
- **ProviderSettingsPageViewModel**（15 条）：由 `listsNewlyAddedCloudProvider`、`customProviderRevisionIncrementsOnStoreChange`、`newlyAddedProviderIsSearchable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderSettingsScopeViewModel**（4 条）：由 `defaultsToCloudScope`、`switchingScopeSwapsListAndSelection`、`scopesKeepIndependentSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **本地化资源完整性**（1 条）：由 `userFacingKeysIncludeEnglish` 锁定供应商设置页可见文案的 en 翻译；改动文案或 xcstrings 时优先跑该测试文件。

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
| 50 | 本地化资源完整性 | 供应商设置页全部可见文案都有非空 en 翻译，且不等于中文 key | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userFacingKeysIncludeEnglish` |
| 51 | ProviderDetailCustomProviderRemoval | 删除自定义供应商时落盘失败会展示错误并保留供应商 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `removalFailureSurfacesErrorAndKeepsProvider` |
| 52 | ProviderDetailCustomProviderRemoval | 删除成功后不残留上一次的错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removalSuccessClearsPreviousError` |
| 53 | CustomCloudProviderForm | 只改名称等无关字段时保留既有默认模型（**回归 #947**） | 既有配置默认模型为 `m2`，模型为 `m1`、`m2` | 回填表单只修改名称后构造配置 | `defaultModel` 仍为 `m2`，不重置为首模型 | P1 | ✅ 已覆盖 | `preservesExistingDefaultModelWhenEditingOtherFields` |
| 54 | CustomCloudProviderForm | 既有默认模型已从列表删除时才回退到首模型（**回归 #947**） | 既有配置默认模型为 `m2`，模型改为 `m1`、`m3` | 构造配置 | `defaultModel` 回退为 `m1` | P1 | ✅ 已覆盖 | `fallsBackToFirstModelWhenExistingDefaultWasRemoved` |
| 55 | ProviderSettingsPageViewModel | 切换供应商后不得继承上一个供应商的 API Key 明文状态（**回归 #942**） | 供应商 P 的详情已展开明文 Key，页面按供应商缓存 ViewModel | 取得供应商 Q 的详情 ViewModel | Q 默认隐藏 Key；P 的状态保留在自己的 ViewModel | P0 | ✅ 已覆盖 | `apiKeyRevealStateIsScopedToProvider` |
| 56 | ProviderSettingsPageViewModel | 搜索排除当前供应商时头部模型数量保持原值（**回归 #941**） | 选中含两个模型的供应商 P，输入只匹配 Q 的搜索词 | 读取选中供应商与模型数量，并刷新选中态 | 详情仍是 P、数量为 2，刷新选中态也不改写选中项 | P1 | ✅ 已覆盖 | `searchDoesNotZeroSelectedProviderModelCount` |
| 57 | ProviderSettingsPageViewModel | 全局选中变化后详情刷新「当前」模型（**回归 #940**） | 详情已把 P 的 `m1` 标为当前，全局选中切到 Q 的 `m3` | 读取详情的选中模型与「当前」标记 | 详情不再标记 P 的 `m1`，选中快照等于全局选中 | P1 | ✅ 已覆盖 | `detailRefreshesSelectedModelAfterExternalSelection` |

> 说明：全部 **57 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 47 / 47
- P2: 已覆盖 7 / 7
- **合计: 57 / 57**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（47 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 57 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
