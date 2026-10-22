# TestPlan — PluginDisplayControl

## 包概述

DisplayControlPlugin External display DDC (Display Data Channel) control for Lumi. - Brightness, Volume, Contrast control for external monitors via DDC/CI (VCP commands over I2C) - Built-in display brightness via DisplayServices - Apple Silicon DDC service matching (Arm64DDCMatcher) - Debounced writes (150ms) to prevent DDC overload - Unsupported controls are automatically disabled Based on reference implementation from [hagimi-monitor](https://github.com/Acerola-1/hagimi-monitor).

平台: macOS 14+, iOS 17+
测试文件: 7 个，用例总数: 33

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DisplayControlPlugin`
- `DisplayControlKind`
- `DisplayControlObserver`
- `DDCVCPCode`
- `DisplayControlPluginLocalStore`
- `DisplayControlRuntime`
- `DisplayServicesBridge`
- `PrivateDisplaySymbol`
- `DisplayControlViewModel`
- `DisplayControlAboutView`
- `DisplayControlManualView`
- `DisplayControlView`
- `DisplayMenuBarPopupView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DDCBridge**（12 条）：由 `bridgeReturnsNilWithoutService`、`bridgeReturnsNilAfterEmptyRefresh`、`bridgeRefreshWithInvalidIDs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DisplayControlLocalization**（4 条）：由 `pluginBundleIncludesLocalizedStringsCatalog`、`loadsSimplifiedChineseStrings`、`stringCatalogDefinesRequiredLanguages` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DisplayControlPlugin**（9 条）：由 `pluginInfoIdentifier`、`pluginInfoDisplayName`、`pluginCategory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DisplayControlRuntime**（3 条）：由 `usesInjectedDirectory`、`resetClearsInjectedDirectory`、`bootInjectsStorageDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（2 条）：由 `pluginInfoIsValid`、`controlKindDefaults` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PrivateDisplaySymbol**（3 条）：由 `privateSymbolsDegradeGracefully`、`displayServiceSurvivesMissingSymbols`、`displayServiceHandlesUnknownDisplayID` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DDCBridge | DisplayDDCBridge returns nil/false when no service exists for display | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bridgeReturnsNilWithoutService` |
| 2 | DDCBridge | DisplayDDCBridge returns nil after refresh with empty display IDs | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bridgeReturnsNilAfterEmptyRefresh` |
| 3 | DDCBridge | DisplayDDCBridge handles refresh with non-existent display IDs gracefully | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bridgeRefreshWithInvalidIDs` |
| 4 | DDCBridge | DisplayDDCBridge multiple refreshes do not crash | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bridgeMultipleRefreshes` |
| 5 | DDCBridge | DisplayDDCBridge read/write all control kinds without service returns nil/false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bridgeAllControlsWithoutService` |
| 6 | DDCBridge | DisplayDDCBridge write clamps out-of-range values without crashing | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bridgeWriteClampsValues` |
| 7 | DDCBridge | DisplayDDCBridge can be deallocated safely after refresh | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bridgeDeallocation` |
| 8 | DDCBridge | ControlledDisplay setValue and setSupported mutate correctly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `controlledDisplayMutation` |
| 9 | DDCBridge | ControlledDisplay value(for:) returns correct values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `controlledDisplayValueFor` |
| 10 | DDCBridge | ControlKey equality works correctly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `controlKeyEquality` |
| 11 | DDCBridge | ControlKey can be used as dictionary key | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `controlKeyAsDictionaryKey` |
| 12 | DDCBridge | DisplayWriteResult stores values correctly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayWriteResult` |
| 13 | DisplayControlLocalization | plugin bundle includes localized strings catalog | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginBundleIncludesLocalizedStringsCatalog` |
| 14 | DisplayControlLocalization | loads simplified Chinese strings from plugin bundle | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsSimplifiedChineseStrings` |
| 15 | DisplayControlLocalization | string catalog defines required languages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stringCatalogDefinesRequiredLanguages` |
| 16 | DisplayControlLocalization | string catalog includes key display strings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stringCatalogIncludesKeyDisplayStrings` |
| 17 | DisplayControlPlugin | Plugin info has correct identifier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginInfoIdentifier` |
| 18 | DisplayControlPlugin | Plugin info has correct display name | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginInfoDisplayName` |
| 19 | DisplayControlPlugin | Plugin category is system | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginCategory` |
| 20 | DisplayControlPlugin | Plugin policy is optIn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginPolicy` |
| 21 | DisplayControlPlugin | Plugin iconName is display | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginIconName` |
| 22 | DisplayControlPlugin | 激活显示器控制时隐藏 ChatSection，离开后恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationHidesChatSection` |
| 23 | DisplayControlPlugin | DisplayControlKind has correct cases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayControlKinds` |
| 24 | DisplayControlPlugin | DisplayControlKind default values are correct | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayControlKindDefaultValues` |
| 25 | DisplayControlPlugin | ControlledDisplay initializes correctly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `controlledDisplayInit` |
| 26 | DisplayControlRuntime | 注入目录后 settingsDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDirectory` |
| 27 | DisplayControlRuntime | 重置后清空注入目录，不再回退到真实数据目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetClearsInjectedDirectory` |
| 28 | DisplayControlRuntime | 启动时把存储目录注入运行时配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootInjectsStorageDirectory` |
| 29 | 综合 | Plugin info is valid | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginInfoIsValid` |
| 30 | 综合 | DisplayControlKind defaults are in valid range | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `controlKindDefaults` |
| 31 | PrivateDisplaySymbol | 私有符号解析不会崩溃，缺失时降级为不可用 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `privateSymbolsDegradeGracefully` |
| 32 | PrivateDisplaySymbol | DisplayService 在私有符号缺失时不会崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `displayServiceSurvivesMissingSymbols` |
| 33 | PrivateDisplaySymbol | DisplayService 对未知 display id 安全降级 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `displayServiceHandlesUnknownDisplayID` |

> 说明：全部 **33 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 23 / 23
- P2: 已覆盖 4 / 4
- **合计: 33 / 33**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 33 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDisplayControl
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
