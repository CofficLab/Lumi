# TestPlan — PluginLLMProviderSettings

## 包概述

PluginLLMProviderSettings 的实现包，包含 14 个主要类型；当前测试覆盖 67 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 67

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
- `CloudProviderSettingsPage`
- `CustomCloudProviderEditor`
- `LocalProviderSettingsPage`
- `ProviderDetailView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CustomCloudProviderForm**（17 条）：由 `parsesModelIDsSeparatedByNewlines`、`parsesModelIDsSeparatedByCommas`、`parsesModelIDsSeparatedByMixedDelimiters` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LLMProviderSettingsPlugin**（6 条）：由 `pluginRegistersSettingEntries`、`pluginShutdownRemovesEntries`、`pluginBootWithoutManagerIsNoop` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderSettingsPageViewModel**（14 条）：由 `listsNewlyAddedCloudProvider`、`customProviderRevisionIncrementsOnStoreChange`、`newlyAddedProviderIsSearchable` 等用例锁定；改动该模块时优先跑对应测试文件。
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
| 18 | LLMProviderSettingsPlugin | onBoot 注册云端/本地两个设置入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersSettingEntries` |
| 19 | LLMProviderSettingsPlugin | onShutdown 撤回设置入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginShutdownRemovesEntries` |
| 20 | LLMProviderSettingsPlugin | 无管理器时 onBoot 静默跳过 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginBootWithoutManagerIsNoop` |
| 21 | LLMProviderSettingsPlugin | 设置页数据源来自管理器注册表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsPageReadsManagerRegistry` |
| 22 | LLMProviderSettingsPlugin | 自定义供应商保存后可恢复并自动注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customProviderPersistsAndRestores` |
| 23 | LLMProviderSettingsPlugin | 删除自定义供应商会注销运行时实例并更新磁盘配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removingCustomProviderUnregistersAndPersists` |
| 24 | ProviderSettingsPageViewModel | 新增自定义供应商后立即出现在云端供应商列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listsNewlyAddedCloudProvider` |
| 25 | ProviderSettingsPageViewModel | 新增自定义供应商会刷新自定义供应商修订号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customProviderRevisionIncrementsOnStoreChange` |
| 26 | ProviderSettingsPageViewModel | 新增后可以按名称搜索到该供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `newlyAddedProviderIsSearchable` |
| 27 | ProviderSettingsPageViewModel | 新增后供应商计数标签同步更新 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerCountLabelReflectsAddedProvider` |
| 28 | ProviderSettingsPageViewModel | 新增后选中态自动落到新供应商并显示其模型数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectsNewlyAddedProviderAndReportsModelCount` |
| 29 | ProviderSettingsPageViewModel | 删除自定义供应商后列表同步移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesProviderFromListAfterDeletion` |
| 30 | ProviderSettingsPageViewModel | 新增供应商可生成空白编辑器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makesNewCustomProviderEditor` |
| 31 | ProviderSettingsPageViewModel | 没有自定义供应商 Store 时不生成编辑器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `makesNoEditorWithoutStore` |
| 32 | ProviderSettingsPageViewModel | 云端页与本地页各自只显示对应作用域的供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scopesProvidersByLocalFlag` |
| 33 | ProviderSettingsPageViewModel | 搜索匹配名称、描述与 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersProvidersBySearchText` |
| 34 | ProviderSettingsPageViewModel | 没有选中项时自动选中第一个供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `synchronizeSelectionSelectsFirstProvider` |
| 35 | ProviderSettingsPageViewModel | 选中项仍然有效时保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `synchronizeSelectionKeepsValidSelection` |
| 36 | ProviderSettingsPageViewModel | 选中项被删除后回退到仍然存在的供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `synchronizeSelectionFallsBackWhenSelectedProviderDisappears` |
| 37 | ProviderSettingsPageViewModel | 列表为空时没有选中项 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `synchronizeSelectionClearsWhenListEmpty` |
| 38 | UserDefinedCloudProviderConfiguration | 名称为空或全是空白时校验失败（空串与空白串） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyOrWhitespaceDisplayName` |
| 39 | UserDefinedCloudProviderConfiguration | 校验通过后名称去掉首尾空白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsDisplayName` |
| 40 | UserDefinedCloudProviderConfiguration | ID 为空时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyIdentifier` |
| 41 | UserDefinedCloudProviderConfiguration | Base URL 非法时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidBaseURL` |
| 42 | UserDefinedCloudProviderConfiguration | HTTP 与 HTTPS 的 Base URL 都合法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsHTTPAndHTTPSBaseURL` |
| 43 | UserDefinedCloudProviderConfiguration | 校验通过后 Base URL 去掉首尾空白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsBaseURL` |
| 44 | UserDefinedCloudProviderConfiguration | 模型列表为空时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyModelList` |
| 45 | UserDefinedCloudProviderConfiguration | 模型 ID 重复时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsDuplicateModelIDs` |
| 46 | UserDefinedCloudProviderConfiguration | 模型 ID 为空白时校验失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsBlankModelID` |
| 47 | UserDefinedCloudProviderConfiguration | 默认模型不在列表中时回退到第一个模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackToFirstModelWhenDefaultMissing` |
| 48 | UserDefinedCloudProviderConfiguration | 默认模型在列表中时保持不变 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsDefaultModelWhenPresent` |
| 49 | UserDefinedCloudProviderConfiguration | Responses 格式关闭工具调用能力 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesFormatDisablesToolSupport` |
| 50 | UserDefinedCloudProviderConfiguration | OpenAI 与 Anthropic 格式保留工具调用能力 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherFormatsKeepToolSupport` |
| 51 | UserDefinedCloudProviderConfiguration | 未知的 API 格式原始值回退到 OpenAI | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownAPIFormatFallsBackToOpenAI` |
| 52 | UserDefinedCloudProviderConfiguration | API Key 存储键按供应商 ID 隔离 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyStorageKeyIsScopedByProviderID` |
| 53 | UserDefinedCloudProviderConfiguration | 官网为空串时解析为 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `websiteURLIsNilWhenEmpty` |
| 54 | UserDefinedCloudProviderConfiguration | 错误描述非空且为中文提示 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `errorDescriptionsAreNotEmpty` |
| 55 | UserDefinedCloudProviderStore | 新增供应商后配置落盘并注册到管理器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertPersistsAndRegistersProvider` |
| 56 | UserDefinedCloudProviderStore | 同一 ID 再次新增是覆盖而不是追加 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertReplacesConfigurationWithSameIdentifier` |
| 57 | UserDefinedCloudProviderStore | 配置非法时新增失败且不落盘不注册 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `upsertRejectsInvalidConfigurationWithoutSideEffects` |
| 58 | UserDefinedCloudProviderStore | 未装配管理器时新增失败并报持久化错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertFailsWhenManagerNotAttached` |
| 59 | UserDefinedCloudProviderStore | 删除供应商会注销运行时实例并更新磁盘配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeUnregistersProviderAndDeletesConfiguration` |
| 60 | UserDefinedCloudProviderStore | 删除不存在的 ID 是空操作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeIgnoresUnknownIdentifier` |
| 61 | UserDefinedCloudProviderStore | 重启后从磁盘恢复自定义供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoresConfigurationsFromDisk` |
| 62 | UserDefinedCloudProviderStore | 装配时把磁盘上的供应商注册进管理器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attachRegistersRestoredProviders` |
| 63 | UserDefinedCloudProviderStore | 磁盘上损坏的配置在加载时被丢弃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dropsInvalidConfigurationsWhenLoading` |
| 64 | UserDefinedCloudProviderStore | 磁盘文件不存在时加载为空配置 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `loadsEmptyWhenFileMissing` |
| 65 | UserDefinedCloudProviderStore | 能识别某个 ID 是否为自定义供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsCustomProviderMembership` |
| 66 | UserDefinedCloudProviderStore | 自定义供应商按所选 API 格式暴露对应配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userDefinedProviderExposesFormatSpecificConfiguration` |
| 67 | UserDefinedCloudProviderStore | 自定义供应商在管理器中暴露为云端供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userDefinedProviderIsRegisteredAsRemoteProvider` |

> 说明：全部 **67 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 9 / 9
- P1: 已覆盖 48 / 48
- P2: 已覆盖 10 / 10
- **合计: 67 / 67**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（9 条）
- **P1**: 其余功能性用例（48 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（10 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 67 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMProviderSettings
swift test
```

## UI 测试（宿主 App 级）

「添加供应商」是一条跨插件长链路：设置页按钮 → 弹出编辑器 → 填表 →
`UserDefinedCloudProviderStore.upsert` → 落盘 + 注册进运行时管理器 →
发布者通知设置页刷新列表。任一环静默失效，界面表现都是同一个：
**列表里没有新供应商**。包内单元测试覆盖不到「按钮能不能点到」
「表单能不能填进去」「列表会不会刷新」这三段，因此补一条驱动真实 App 的 UI 测试。

文件：`LumiUITests/LumiCloudProviderAddUITests.swift`（XCTest，独立 target）

- `testAddProviderCreatesCloudProviderInList`：填表保存后编辑器关闭、计数 +1、侧边栏出现新供应商、详情里能看到保存的模型。
- `testAddProviderRejectsInvalidBaseURL`：Base URL 非法时保存失败，错误提示可见，编辑器不关闭，供应商不被创建。
- `testSaveButtonIsDisabledUntilNameIsEntered`：名称为空时保存按钮不可用，填入名称后恢复可用。
- `testCancelAddProviderDoesNotCreateProvider`：取消编辑不创建任何供应商。

确定性来源：`--lumi-ui-testing-isolated-storage` 把数据根目录重定向到临时目录下的
全新 UUID 子目录（见 `KernelFactory.uiTestingDataRootDirectory()`），等价于全新安装，
用例之间互不污染。

定位方式：**优先按无障碍标识符**（`ProviderSettingsAccessibility`），标识符没落到目标
控件上时退回占位符匹配。设置页的「添加供应商」「保存」是插件内硬编码的中文字面量，
不走 `String(localized:)`，不随 `-AppleLanguages` 变化；「Cloud Providers」走插件
资源包的字符串目录，会随语言变。混用两套判据会让用例在换语言时集体失效。

### 无障碍定位的三个坑（实跑踩出来的）

这三条是 SwiftUI → AX 树的真实行为，不写下来下次还会再踩：

1. **容器上的标识符会被继承给子元素，并覆盖子元素自己的标识符。**
   给编辑器根 `VStack` 挂 `…custom-provider-editor` 后，它的「取消 / 保存」按钮
   拿到的都是这个根标识符，而不是各自的 `…custom-provider.cancel` /
   `…custom-provider.save`——按后者定位永远找不到。
   因此 `ProviderSettingsAccessibility` 的标识符**只挂叶子控件，不挂容器**。
2. **同一个标识符可能同时落在多个元素上。**
   `AppSearchBar` 的放大镜图标和它的 `TextField` 拿到的是同一个标识符。
   不按元素类型限定查询，`firstMatch` 可能抓到那个 `Image`——点它不会有任何反应。
   所以查询一律用 `app.buttons.matching(identifier:)` / `app.textFields.matching(identifier:)`
   这种**按类型限定**的写法。
3. **SwiftUI 的 `Text` 把文字放在 AX 的 `value` 上，`label` 是空的。**
   只按 `label` 匹配会一条都查不到（表头的「26 个云端供应商」就是这么丢的）。
   谓词必须写成 `label CONTAINS %@ OR value CONTAINS %@`。

### 环境依赖（实跑踩出来的三条）

1. **钥匙串授权弹窗**：打开供应商详情会读钥匙串里的 API Key。Debug 构建的签名与
   钥匙串条目 ACL 不匹配时，macOS 会弹出「警告」对话框（宿主进程
   `com.apple.coreservices.uiagent`）。它是**模态系统弹窗**，一出现 Lumi 进程就
   进入 Disabled 状态，后续所有点击都被拦走，症状却是「设置窗口没有出现」。
   XCUITest 内置中断监控处理不了钥匙串弹窗，用例里注册
   `addUIInterruptionMonitor` 主动关掉它。
2. **残留进程**：Lumi 启动要装配 240+ 个本地包，退出很慢。旧实例没退干净时，
   `app.launch()` 不会新建进程而是去激活旧实例，报
   `Failed to activate application (Running Background)`——错误信息指向「激活失败」，
   真实原因却是「上一次的进程还在」。
3. **输入时限**：App 冷启动远慢于普通 App，元素等待统一放宽到 40s。

前两条的修复落在共享基类 `LumiUITests/LumiUITestCase.swift`（等待退出 + 清理同
bundle id 的残留实例），对仓库里其它 UI 测试同样有效。

```bash
xcodebuild test -project Lumi.xcodeproj -scheme Lumi -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiCloudProviderAddUITests
```

实跑结果：`Executed 4 tests, with 0 failures`。

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
