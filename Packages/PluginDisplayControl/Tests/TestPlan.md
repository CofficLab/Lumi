# TestPlan — PluginDisplayControl

## 包概述

DisplayControlPlugin External display DDC (Display Data Channel) control for Lumi. - Brightness, Volume, Contrast control for external monitors via DDC/CI (VCP commands over I2C) - Built-in display brightness via DisplayServices - Apple Silicon DDC service matching (Arm64DDCMatcher) - Debounced writes (150ms) to prevent DDC overload - Unsupported controls are automatically disabled Based on reference implementation from [hagimi-monitor](https://github.com/Acerola-1/hagimi-monitor).

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 54

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

- **DDCBridge**（14 条）：由 `bridgeReturnsNilWithoutService`、`bridgeReturnsNilAfterEmptyRefresh`、`bridgeRefreshWithInvalidIDs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DisplayControlLocalization**（4 条）：由 `pluginBundleIncludesLocalizedStringsCatalog`、`loadsSimplifiedChineseStrings`、`stringCatalogDefinesRequiredLanguages` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DisplayControlPlugin**（9 条）：由 `pluginInfoIdentifier`、`pluginInfoDisplayName`、`pluginCategory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DisplayControlRuntime**（3 条）：由 `usesInjectedDirectory`、`resetClearsInjectedDirectory`、`bootInjectsStorageDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（2 条）：由 `pluginInfoIsValid`、`controlKindDefaults` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PrivateDisplaySymbol**（3 条）：由 `privateSymbolsDegradeGracefully`、`displayServiceSurvivesMissingSymbols`、`displayServiceHandlesUnknownDisplayID` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DDCI2CReturnValue**（3 条）：由 `i2cSymbolsReturnIOReturn`、`successValueIsZero`、`transferResultUsesIOReturn` 锁定 I2C 符号返回 `IOReturn`（成功值 0）而非 `Bool`（#864）；改动 `PrivateDisplaySymbol` 的 I2C 签名或传输判定时优先跑该文件。
- **CoreDisplayOwnership**（3 条）：由 `symbolSignatureCarriesOwnership`、`takingTheValueReleasesTheDictionary`、`repeatedDisplayNameDoesNotAccumulateDictionaries` 锁定 CoreDisplay Create 规则字典的所有权平衡，防止每 5 秒刷新泄漏（#865）。
- **DisplayControlSupport**（4 条）：由 `ddcServiceAloneDoesNotEnableControl`、`liveVCPReadEnablesControl`、`storedValueEnablesControlWithoutLiveRead`、`builtInOnlySupportsBrightnessWithAppleEvidence` 锁定逐控制能力判定——只有读到 VCP 值或有历史存储值才算支持，DDC 通道存在本身不是证据（#240）；改动 `DisplayService.isControlSupported` 或 refresh 支持旗标时优先跑该文件。
- **DDCValueScaling**（7 条，**回归 #837**）：由 `readUsesFullReportedMax`、`writeScalesByFullReportedMax`、`readClampsCurrentAboveMax`、`writeClampsPercentageRange` 等锁定 DDC 读数/写回换算——百分比与写回硬件值都必须以显示器报告的原始 VCP 满量程为准，不得截断到 100；改动 `DDCBridge` 的 `DDCValueScaling` 或 read/write 缩放时优先跑该文件。
- **DisplayControl 禁用生命周期**（1 条，**回归 #460**）：由 `disableStopsRefreshAndCancelsPendingWrites` 锁定——Kernel 运行时 `disablePlugin` 只调用 `onDisable` 并撤回经 `trackContribution` 注册的贡献，不调用 `onShutdown`，也不会清理插件直接写入 ActivityBar 的入口、`DisplayControlObserver` 的 5 秒刷新定时器与订阅、以及 `DisplayService` 150ms 防抖窗口内尚未执行的硬件写入。插件必须在 `onDisable` 取消观察器、调用 `DisplayService.cancelPendingWrites()` 取消未执行的防抖写入并撤回入口；`onEnable` 幂等恢复。viewModel 在禁用期间保持存活。改动 `DisplayControlPlugin` 的 `onBoot`/`onEnable`/`onDisable`/`onShutdown` 或 `installRuntimeContributions`/`removeRuntimeContributions`、`DisplayService.cancelPendingWrites` 时优先跑该文件（串行套件，共享进程级单例与运行时目录注入）。
- **DisplayControl Observer 同步**（1 条，**回归 #459**）：由 `observerPropagatesDisplaysImmediatelyAfterWrite` 锁定——`DisplayControlObserver` 必须订阅 `DisplayService.displaysDidChange`（`displays` 写入完成后由 `didSet` 发出）而不是 `objectWillChange`（`willSet` 阶段发出，订阅方此时读到的还是旧数组），否则 ViewModel 每轮刷新拿到上一轮的显示器列表。改动 `DisplayService` 的 `displays` 发布方式或 `DisplayControlObserver` 的订阅源时优先跑该文件（串行套件，须先注入运行时目录）。

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
| 34 | DDCBridge | 零音量不得写入 0x8D（该值会触发 screen blank） | — | 调用 `DDCVolumeWritePlan.plan(for: 0)` | 返回 `.volumeOnly`，不触碰静音通道 | P0 | ✅ 已覆盖 | `zeroVolumeSkipsScreenBlankChannel` |
| 35 | DDCBridge | 非零音量先解除静音再写扬声器音量 | — | 调用 `DDCVolumeWritePlan.plan(for: 1)` | 返回 `.unmute` | P1 | ✅ 已覆盖 | `nonZeroVolumeUnmutes` |
| 36 | DDCI2CReturnValue | I2C 符号返回 IOReturn 而不是 Bool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `i2cSymbolsReturnIOReturn` |
| 37 | DDCI2CReturnValue | kIOReturnSuccess 是 0 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `successValueIsZero` |
| 38 | DDCI2CReturnValue | 传输结果按 IOReturn 判定，成功即成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transferResultUsesIOReturn` |
| 39 | CoreDisplayOwnership | 符号签名用 Unmanaged 表达 Create 规则的所有权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `symbolSignatureCarriesOwnership` |
| 40 | CoreDisplayOwnership | 取字典内容后所有权被平衡，实例不会持续累积 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `takingTheValueReleasesTheDictionary` |
| 41 | CoreDisplayOwnership | 反复读取显示器名称不累积未释放的字典 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedDisplayNameDoesNotAccumulateDictionaries` |
| 42 | DisplayControlSupport | DDC service alone must not enable a control without per-control evidence (#240) | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ddcServiceAloneDoesNotEnableControl` |
| 43 | DisplayControlSupport | a successful VCP read enables the control (#240) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `liveVCPReadEnablesControl` |
| 44 | DisplayControlSupport | a stored historical value enables the control without a live read (#240) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storedValueEnablesControlWithoutLiveRead` |
| 45 | DisplayControlSupport | built-in display only supports brightness backed by Apple evidence (#240) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `builtInOnlySupportsBrightnessWithAppleEvidence` |
| 46 | DDCValueScaling | 读取百分比必须用显示器报告的完整满量程（max>100，**回归 #837**） | current=128, max=255 | 调用 `DDCValueScaling.read` | 百分比≈50.2%（<100），缓存满量程为 255 | P0 | ✅ 已覆盖 | `readUsesFullReportedMax` |
| 47 | DDCValueScaling | 写回硬件值必须按完整满量程缩放（max>100，**回归 #837**） | percentage=50, max=255 | 调用 `DDCValueScaling.write` | 硬件值为 128（127.5 四舍五入），而非 50 | P0 | ✅ 已覆盖 | `writeScalesByFullReportedMax` |
| 48 | DDCValueScaling | current 等于 max 时读数为 100% | current=255, max=255 | 调用 `DDCValueScaling.read` | 百分比为 100，缓存满量程 255 | P1 | ✅ 已覆盖 | `readAtMaxIs100Percent` |
| 49 | DDCValueScaling | current 超过 max 时读数夹到 100% | current=300, max=255 | 调用 `DDCValueScaling.read` | 百分比夹到 100，缓存满量程仍 255 | P1 | ✅ 已覆盖 | `readClampsCurrentAboveMax` |
| 50 | DDCValueScaling | max=100 的显示器读写行为保持不变 | current=50, max=100 | 调用 read 与 write | 读数 50%、缓存 100、写回 50 | P1 | ✅ 已覆盖 | `max100DisplayUnchanged` |
| 51 | DDCValueScaling | 写回百分比夹到 0...100 | percentage=200 / -50, max=255 | 调用 `DDCValueScaling.write` | 200%→255，-50%→0 | P1 | ✅ 已覆盖 | `writeClampsPercentageRange` |
| 52 | DDCValueScaling | 满量程 65535 时 100% 写回不溢出 UInt16 | percentage=100, max=65535 | 调用 `DDCValueScaling.write` | 硬件值为 65535，不溢出 | P1 | ✅ 已覆盖 | `writeFullScaleUInt16Boundary` |
| 53 | DisplayControl 禁用生命周期 | 运行时禁用停止周期刷新、取消未执行的硬件写入并撤回入口，重新启用恢复（**回归 #460**） | 真实 kernel 注册并启用插件（disabledByDefault），注入临时存储目录，构造 150ms 防抖窗口内的待写值 | 禁用/启用插件 | 禁用后入口撤回、观察器停止、防抖写入被取消；启用后入口与观察器恢复；stop 后同样清空 | P0 | ✅ 已覆盖 | `disableStopsRefreshAndCancelsPendingWrites` |
| 54 | DisplayControl Observer 同步 | displays 写入后 ViewModel 立即同步新列表，不再滞后一轮（**回归 #459**） | 注入临时运行时目录（LocalStore 单例初始化依赖它），向 `DisplayService.shared` 注入显示器快照并构造观察器 | 通过 `setDisplaysForTesting` 写入新的显示器列表 | ViewModel 同步拿到新列表（didSet → displaysDidChange → sink → apply 全链路同步），先注入的初始列表也正确回填 | P0 | ✅ 已覆盖 | `observerPropagatesDisplaysImmediatelyAfterWrite` |

> 说明：全部 **54 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> ID 53 为本轮新增的运行时禁用生命周期回归用例（`DisplayControlDisableLifecycleTests`，见 #460）。
> ID 54 为本轮新增的 Observer 同步回归用例（`DisplayControlObserverSyncTests`，见 #459）。
> #459 回归：`DisplayControlObserver` 订阅 `objectWillChange`，该信号在 `@Published displays` 的 `willSet` 阶段发出，同步执行的 `viewModel.apply(service)` 读到的是写入前的旧数组，ViewModel 每轮刷新滞后一轮。修复给 `DisplayService` 加 `displaysDidChange`（`PassthroughSubject`，在 `displays` 的 `didSet` 中发出），观察器改订阅它。变异验证（把观察器订阅改回 `objectWillChange`）令 `observerPropagatesDisplaysImmediatelyAfterWrite` 转红（ViewModel 仍持有旧列表）；还原后 54 条全绿。
> #460 回归：清理原本只在 `onShutdown`，运行时禁用只调用 `onDisable`，导致 5 秒刷新定时器、观察器订阅与 150ms 防抖窗口内的硬件写入在禁用后继续运行。修复抽出 `installRuntimeContributions`/`removeRuntimeContributions`，`onDisable` 取消观察器、`DisplayService.cancelPendingWrites()` 与入口撤回，`onEnable` 恢复。变异验证（掏空 `onDisable`）令 `disableStopsRefreshAndCancelsPendingWrites` 转红（3 issues：入口仍在、观察器仍运行、防抖写入未取消）；还原后 53 条全绿。
> #240 回归：`hasDDCService` 曾被并进三个支持旗标，导致仅支持 DDC 亮度的显示器把音量/对比度也判为可用。变异验证 M1（在 `isControlSupported` 外部显示分支重新加回 `|| hasDDCService`）令 `ddcServiceAloneDoesNotEnableControl` 转红；M2（移除 `|| storedValue != nil`，只认实时读取）令 `storedValueEnablesControlWithoutLiveRead` 转红；还原后 45 条全绿。
> #837 回归：`DDCBridge` 曾把显示器报告的 VCP 满量程截断到 100（`min(values.max, 100)`），max>100 的显示器读数被压成 100%、写回硬件值按比例偏小。修复抽出 `DDCValueScaling.read/write`，以显示器报告的原始 max 换算百分比与写回值。变异验证 M1（read 重新把 max 截断到 100）令 `readUsesFullReportedMax` 转红；M2（write 重新截断 max）令 `writeScalesByFullReportedMax` 转红；M3（移除 read 的 100% 上限夹取）令 `readClampsCurrentAboveMax` 转红；M4（移除 write 的百分比上限夹取）令 `writeClampsPercentageRange` 转红；还原后 52 条全绿。

## 覆盖率统计

- P0: 已覆盖 14 / 14
- P1: 已覆盖 35 / 35
- P2: 已覆盖 5 / 5
- **合计: 54 / 54**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（14 条）
- **P1**: 其余功能性用例（35 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 54 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
