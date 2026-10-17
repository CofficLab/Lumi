# TestPlan — PluginComputerUse

## 包概述

PluginComputerUse 的实现包，包含 14 个主要类型；当前测试覆盖 27 条用例。

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 27

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `FixtureDelegate`
- `AccessibilityObserveTool`
- `ComputerUsePlugin`
- `ComputerUseActionParser`
- `ComputerUseWindow`
- `ApplicationActivationObserver`
- `AccessibilityService`
- `ComputerUseAuthorizationStore`
- `ComputerUseImageEncoder`
- `ComputerUseInputExecutor`
- `ComputerUsePermissionService`
- `ComputerUseService`
- `ComputerUseWindowProvider`
- `NativeControlBannerController`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AccessibilityIntegration**（1 条）：由 `accessibilityOperatesBackgroundFixtureWithoutMovingCursorOrActivatingIt` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ApplicationActivationObserver**（1 条）：由 `activationObserverCallsBackUntilCancelled` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseActionParser**（6 条）：由 `parserSupportsAllActionsAndAppliesDefaults`、`parserAcceptsExactlyTenActions`、`parserEnforcesActionAndCoordinateRequirements` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseAuthorizationStore**（1 条）：由 `authorizationStoreAddsRemovesAndIgnoresEmptyIdentifiers` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseImageEncoder**（2 条）：由 `imageEncoderDownscalesAndReturnsReadableJPEGAttachment`、`downscalePreservesSmallImagesAndHandlesNonPositiveLimit` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseInputExecutor**（4 条）：由 `inputExecutorMapsInBoundsImageCoordinates`、`inputExecutorRejectsInvalidCoordinatesWithoutIntegerOverflow`、`keyCodeRecognizesLettersDigitsAndCommonKeys` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseModels**（6 条）：由 `observationMapsImageCoordinatesIntoWindowCoordinates`、`observationFallsBackToWindowOriginForInvalidImageDimensions`、`actionsReportWhetherTheyChangeApplicationState` 等用例锁定；改动该模块时优先跑对应测试文件。
- **NativeControl**（6 条）：由 `revokedInputLeaseCannotBeRestarted`、`expiredLeaseRejectsFurtherInput`、`eventMarkerAloneCannotMasqueradeAsLumi` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AccessibilityIntegration | accessibilityOperatesBackgroundFixtureWithoutMovingCursorOrActivatingIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `accessibilityOperatesBackgroundFixtureWithoutMovingCursorOrActivatingIt` |
| 2 | ApplicationActivationObserver | activationObserverCallsBackUntilCancelled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationObserverCallsBackUntilCancelled` |
| 3 | ComputerUseActionParser | parserSupportsAllActionsAndAppliesDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `parserSupportsAllActionsAndAppliesDefaults` |
| 4 | ComputerUseActionParser | parserAcceptsExactlyTenActions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parserAcceptsExactlyTenActions` |
| 5 | ComputerUseActionParser | parserEnforcesActionAndCoordinateRequirements | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parserEnforcesActionAndCoordinateRequirements` |
| 6 | ComputerUseActionParser | parserValidatesDragPathAndBounds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parserValidatesDragPathAndBounds` |
| 7 | ComputerUseActionParser | parserValidatesTextAndKeypressLimits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parserValidatesTextAndKeypressLimits` |
| 8 | ComputerUseActionParser | parserClampsWaitDurationWithoutOverflowingIntegerConversion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parserClampsWaitDurationWithoutOverflowingIntegerConversion` |
| 9 | ComputerUseAuthorizationStore | authorizationStoreAddsRemovesAndIgnoresEmptyIdentifiers | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `authorizationStoreAddsRemovesAndIgnoresEmptyIdentifiers` |
| 10 | ComputerUseImageEncoder | imageEncoderDownscalesAndReturnsReadableJPEGAttachment | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageEncoderDownscalesAndReturnsReadableJPEGAttachment` |
| 11 | ComputerUseImageEncoder | downscalePreservesSmallImagesAndHandlesNonPositiveLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `downscalePreservesSmallImagesAndHandlesNonPositiveLimit` |
| 12 | ComputerUseInputExecutor | inputExecutorMapsInBoundsImageCoordinates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inputExecutorMapsInBoundsImageCoordinates` |
| 13 | ComputerUseInputExecutor | inputExecutorRejectsInvalidCoordinatesWithoutIntegerOverflow | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `inputExecutorRejectsInvalidCoordinatesWithoutIntegerOverflow` |
| 14 | ComputerUseInputExecutor | keyCodeRecognizesLettersDigitsAndCommonKeys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keyCodeRecognizesLettersDigitsAndCommonKeys` |
| 15 | ComputerUseInputExecutor | screenshotAndZeroWaitActionsDoNotPostInputEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `screenshotAndZeroWaitActionsDoNotPostInputEvents` |
| 16 | ComputerUseModels | observationMapsImageCoordinatesIntoWindowCoordinates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observationMapsImageCoordinatesIntoWindowCoordinates` |
| 17 | ComputerUseModels | observationFallsBackToWindowOriginForInvalidImageDimensions | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `observationFallsBackToWindowOriginForInvalidImageDimensions` |
| 18 | ComputerUseModels | actionsReportWhetherTheyChangeApplicationState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actionsReportWhetherTheyChangeApplicationState` |
| 19 | ComputerUseModels | windowSelectionMatchesApplicationAndTitleCaseInsensitively | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `windowSelectionMatchesApplicationAndTitleCaseInsensitively` |
| 20 | ComputerUseModels | blankWindowFiltersUseTheFrontmostApplication | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `blankWindowFiltersUseTheFrontmostApplication` |
| 21 | ComputerUseModels | computerUseErrorsProvideReadableLocalizedDescriptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `computerUseErrorsProvideReadableLocalizedDescriptions` |
| 22 | NativeControl | revokedInputLeaseCannotBeRestarted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokedInputLeaseCannotBeRestarted` |
| 23 | NativeControl | expiredLeaseRejectsFurtherInput | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `expiredLeaseRejectsFurtherInput` |
| 24 | NativeControl | eventMarkerAloneCannotMasqueradeAsLumi | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `eventMarkerAloneCannotMasqueradeAsLumi` |
| 25 | NativeControl | nativeControlHoldsExclusiveLeaseAndStopRequiresFreshConsent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nativeControlHoldsExclusiveLeaseAndStopRequiresFreshConsent` |
| 26 | NativeControl | resumeRequiresFreshObservationAndNeverReplaysBatch | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeRequiresFreshObservationAndNeverReplaysBatch` |
| 27 | NativeControl | cancellationWhileAwaitingConsentReleasesUI | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellationWhileAwaitingConsentReleasesUI` |

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 20 / 20
- P2: 已覆盖 3 / 3
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（20 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginComputerUse
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
