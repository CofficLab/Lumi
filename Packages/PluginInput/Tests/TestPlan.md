# TestPlan — PluginInput

## 包概述

InputPlugin Manage input-related behaviors

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 16

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `InputPluginRuntimeBridge`
- `InputRule`
- `InputSource`
- `InputEventObserver`
- `InputSettingsObserver`
- `InputPluginLocalStore`
- `InputService`
- `InputSettingsViewModel`
- `AddRuleFormView`
- `InputAboutView`
- `InputManualView`
- `InputRuleRowView`
- `InputRulesEmptyStateView`
- `InputSettingsView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（15 条）：由 `packageLoads`、`activatingPluginHidesRailAndContentHeaderAndDeactivatingRestoresThem`、`compactHostActivatesAndRestoresRailLifecycleWithoutActivityBar` 等用例锁定；改动该模块时优先跑对应测试文件。
- **InputDisableLifecycle**（1 条，**回归 #365**）：由 `disableStopsAppActivationListenerAndEnableRestoresIt` 锁定运行时禁用必须立即取消应用激活监听（不再切换 macOS 输入源）并撤回 ActivityBar 入口，启用时恢复；改动 `InputPlugin.onDisable`/`onEnable` 或 `InputEventObserver` 时优先跑该文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | packageLoads | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `packageLoads` |
| 2 | 综合 | activatingPluginHidesRailAndContentHeaderAndDeactivatingRestoresThem | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesRailAndContentHeaderAndDeactivatingRestoresThem` |
| 3 | 综合 | compactHostActivatesAndRestoresRailLifecycleWithoutActivityBar | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactHostActivatesAndRestoresRailLifecycleWithoutActivityBar` |
| 4 | 综合 | localStoreReportsSaveResultAndReloadsData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStoreReportsSaveResultAndReloadsData` |
| 5 | 综合 | localStoreUsesPluginRootWithoutNestedSettingsDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStoreUsesPluginRootWithoutNestedSettingsDirectory` |
| 6 | 综合 | localStoreQuarantinesInvalidSettingsFileAndRecovers | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `localStoreQuarantinesInvalidSettingsFileAndRecovers` |
| 7 | 综合 | localStoreReportsFailureWhenSettingsDirectoryIsBlocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStoreReportsFailureWhenSettingsDirectoryIsBlocked` |
| 8 | 综合 | removeRuleIgnoresStaleOffsets | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeRuleIgnoresStaleOffsets` |
| 9 | 综合 | 注入目录后 resolvedPluginDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDirectory` |
| 10 | 综合 | 未注入目录时守卫拒绝回退到真实数据目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refusesWithoutInjectedDirectory` |
| 11 | 综合 | 启动时把存储目录注入运行时配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootInjectsStorageDirectory` |
| 12 | 综合 | 设置页出现时重新枚举输入源，不复用启动时缓存 | 列表里残留一个旧输入源 | 调用 `refreshSources()` | 旧项消失，列表与 `InputService.availableInputSources` 一致 | P0 | ✅ 已覆盖 | `refreshingSettingsReloadsInputSources` |
| 13 | 综合 | 旧嵌套 settings/settings.plist 首次启动前移到根文件（**回归 #784**） | 根目录仅有嵌套 settings/settings.plist | 初始化 `InputPluginLocalStore` 后读取配置 | 读到旧配置，根 settings.plist 生成，旧嵌套文件被清理 | P0 | ✅ 已覆盖 | `localStoreMigratesLegacyNestedSettingsOnFirstRead` |
| 14 | 综合 | 根文件已存在时不得被旧嵌套文件覆盖（**回归 #784** 护栏） | 根 settings.plist 为新配置，嵌套为旧配置 | 初始化 `InputPluginLocalStore` 后读取 | 读到新配置，旧嵌套文件原样保留 | P0 | ✅ 已覆盖 | `localStoreKeepsExistingFlatSettingsOverLegacyNested` |
| 15 | 综合 | 迁移后的配置可继续保存并跨重启读取（**回归 #784**） | 仅含旧嵌套配置 | 迁移后 `set` 新值并新建 Store 读取 | 读到新值，旧嵌套文件不再残留 | P1 | ✅ 已覆盖 | `localStoreMigratedSettingsSurviveReloadAndSave` |
| 16 | InputDisableLifecycle | 运行时禁用必须立即停止应用激活监听并撤回入口，启用时恢复（**回归 #365**） | onBoot 后监听器在订阅、入口存在 | 调用 `onDisable` 再 `onEnable` | 禁用后 `isEventObserverRunningForTesting` 为 false 且入口移除；启用后两者恢复 | P0 | ✅ 已覆盖 | `disableStopsAppActivationListenerAndEnableRestoresIt` |

> 说明：全部 **16 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> #365 回归：InputPlugin 此前没有 `onDisable`/`onEnable`，内核运行时禁用不调用 `onShutdown`，`InputEventObserver` 仍订阅应用激活通知并转发给 `InputService.handleAppActivation`，禁用后仍按旧规则切换 macOS 输入源。修复抽出 install/remove 运行时贡献助手，`onDisable` 取消监听并撤回入口，`onEnable` 恢复。变异验证（把 `onDisable` 还原为空实现）令 `disableStopsAppActivationListenerAndEnableRestoresIt` 转红（2 处断言失败）；还原后 16 条全绿。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 10 / 10
- P2: 已覆盖 0 / 0
- **合计: 16 / 16**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 16 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginInput
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
