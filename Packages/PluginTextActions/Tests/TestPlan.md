# TestPlan — PluginTextActions

## 包概述

PluginTextActions 的实现包，包含 8 个主要类型；当前测试覆盖 51 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 51

核心组件（源码目录）:
- `Observers/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `TextSelectionReadPolicy`
- `TextActionsManualView`
- `TextActionsPlugin`
- `TextActionsPluginLocalStore`
- `TextActionsRuntime`
- `TextActionsSettings`
- `TextSelectionObserver`
- `TextActionsAboutView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **TextActionsPlugin**（16 条）：由 `pluginMetadata`、`localStorePersistsEnabledFlagInBinaryPlist`、`localStoreWritesNoUserDefaults` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextActionsCore**（14 条）：由 `doesNotPresentMenuForBlankText`、`presentsMenuForRealText`、`retryConstants` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextActionsPluginLifecycle**（11 条）：由 `registerAddsDocsEntries`、`registerWithoutDocsProviderIsNoop`、`bootInjectsStorageDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextActionsStorage**（10 条）：由 `usesConfiguredDirectory`、`resetsToFallbackDirectory`、`roundTripsValue` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | TextActionsPlugin | pluginMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMetadata` |
| 2 | TextActionsPlugin | localStorePersistsEnabledFlagInBinaryPlist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStorePersistsEnabledFlagInBinaryPlist` |
| 3 | TextActionsPlugin | localStoreWritesNoUserDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `localStoreWritesNoUserDefaults` |
| 4 | TextActionsPlugin | textActionCatalogIsComplete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textActionCatalogIsComplete` |
| 5 | TextActionsPlugin | searchURLEncodesQueryItems | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchURLEncodesQueryItems` |
| 6 | TextActionsPlugin | translationRequestUsesSelectedTextAndTranslationInstruction | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `translationRequestUsesSelectedTextAndTranslationInstruction` |
| 7 | TextActionsPlugin | v2TranslationRequestPreservesPromptAndText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2TranslationRequestPreservesPromptAndText` |
| 8 | TextActionsPlugin | v2PluginPreservesIdentityAndOptInPolicy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginPreservesIdentityAndOptInPolicy` |
| 9 | TextActionsPlugin | copyActionWritesToPasteboard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyActionWritesToPasteboard` |
| 10 | TextActionsPlugin | emptySelectionDoesNotPresentMenu | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptySelectionDoesNotPresentMenu` |
| 11 | TextActionsPlugin | nonEmptySelectionPresentsMenu | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonEmptySelectionPresentsMenu` |
| 12 | TextActionsPlugin | menuLayoutClampsToScreenEdges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `menuLayoutClampsToScreenEdges` |
| 13 | TextActionsPlugin | selectionManagerStartsOnlyOnceAndStopsMonitoring | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerStartsOnlyOnceAndStopsMonitoring` |
| 14 | TextActionsPlugin | selectionManagerDoesNotMonitorWithoutAccessibilityPermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerDoesNotMonitorWithoutAccessibilityPermission` |
| 15 | TextActionsPlugin | selectionManagerCanStartAfterPermissionIsGranted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerCanStartAfterPermissionIsGranted` |
| 16 | TextActionsPlugin | selectedTextProviderCanSimulateAXRetrySequence | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `selectedTextProviderCanSimulateAXRetrySequence` |
| 17 | TextActionsCore | 空白与空选区不弹菜单 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotPresentMenuForBlankText` |
| 18 | TextActionsCore | 有内容的选区弹菜单 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `presentsMenuForRealText` |
| 19 | TextActionsCore | 重试节奏常量固定 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryConstants` |
| 20 | TextActionsCore | 锚点居中时水平居中、垂直下移 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `centersOnAnchor` |
| 21 | TextActionsCore | 靠左时夹到屏幕左边 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsToLeftEdge` |
| 22 | TextActionsCore | 靠右时夹到屏幕右边 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsToRightEdge` |
| 23 | TextActionsCore | 靠上时夹到屏幕上边 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsToTopEdge` |
| 24 | TextActionsCore | 自定义边距与偏移生效 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `respectsCustomMarginAndOffset` |
| 25 | TextActionsCore | 三个动作可枚举且标识稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `actionsAreCaseIterable` |
| 26 | TextActionsCore | 每个动作有标题与图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `actionsHaveTitlesAndIcons` |
| 27 | TextActionsCore | 搜索地址用百分号编码查询词 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsSearchURL` |
| 28 | TextActionsCore | 翻译请求带固定的 system 指令与原文 user 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsTranslationRequest` |
| 29 | TextActionsCore | 旧版翻译请求与新版语义一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyTranslationRequestMatchesV2` |
| 30 | TextActionsCore | 选区结果按值比较 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedTextIsEquatable` |
| 31 | TextActionsPluginLifecycle | 注册时写入关于与说明书文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerAddsDocsEntries` |
| 32 | TextActionsPluginLifecycle | 缺少文档 Provider 时注册不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerWithoutDocsProviderIsNoop` |
| 33 | TextActionsPluginLifecycle | 启动时把存储目录注入运行时 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootInjectsStorageDirectory` |
| 34 | TextActionsPluginLifecycle | 缺少存储 Provider 时启动不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutStorageProviderIsNoop` |
| 35 | TextActionsPluginLifecycle | 关闭时移除设置入口并清理观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownCleansUp` |
| 36 | TextActionsPluginLifecycle | 注销时移除文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregisterRemovesDocsEntries` |
| 37 | TextActionsPluginLifecycle | 插件元数据保持稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 38 | TextActionsPluginLifecycle | 没有旧开关时不做任何导入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsWhenNoLegacyValue` |
| 39 | TextActionsPluginLifecycle | 取不到旧域时不做任何导入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsWhenDomainUnavailable` |
| 40 | TextActionsPluginLifecycle | 旧开关被导入插件专属存储 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importsLegacyValue` |
| 41 | TextActionsPluginLifecycle | 存储已有值时不被旧开关覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotOverwriteExistingValue` |
| 42 | TextActionsStorage | 注入目录后 settingsDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesConfiguredDirectory` |
| 43 | TextActionsStorage | 重置后回到默认回退目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetsToFallbackDirectory` |
| 44 | TextActionsStorage | 写入后能读回同一个值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripsValue` |
| 45 | TextActionsStorage | 写入 nil 会移除该键 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removingValue` |
| 46 | TextActionsStorage | 未写入的键读回 nil 与 false | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingKeyReadsAsEmpty` |
| 47 | TextActionsStorage | 非布尔值按 false 处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonBooleanReadsAsFalse` |
| 48 | TextActionsStorage | 启用开关可读写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `enabledSwitchRoundTrips` |
| 49 | TextActionsStorage | 存储落在 settings.plist 且能被新实例读回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistsAcrossInstances` |
| 50 | TextActionsStorage | 损坏的 plist 被当作空字典 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `treatsCorruptFileAsEmpty` |
| 51 | TextActionsStorage | 不同实例使用各自隔离的目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isolatesInstancesByDirectory` |

> 说明：全部 **51 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 41 / 41
- P2: 已覆盖 7 / 7
- **合计: 51 / 51**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（41 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 51 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginTextActions
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
