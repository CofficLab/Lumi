# TestPlan — PluginComputerUse

## 包概述

PluginComputerUse 的实现包，包含 14 个主要类型；当前测试覆盖 85 条用例。

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 85

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
- `ComputerUseTargetGeometryProvider`
- `ComputerUseTargetOverlayController`
- `ComputerUseTargetOverlayPanel`

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
- **ComputerUseTargetOverlay**（10 条）：由 `quartzRectConvertsToAppKitUsingHostingScreen`、`intensitiesDifferBetweenExecutionPaths`、`overlayPanelIgnoresMouseAndFocus` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseAuthorizationCard**（27 条）：由 `pendingResultSuspendsTheTurn`、`allowOnceGrantsExactlyOneOperation`、`denyGrantsNothing` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseAuthorizationCardVisibility**（5 条）：由 `suspendedRequestRendersCardEvenWhenAutoApproved`、`completedCallDoesNotRenderCard` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseSystemPermission**（14 条）：由 `accessibilityBecomesPayloadFailure`、`rendererIgnoresAuthorizationSuspension` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 28 | ComputerUseTargetOverlay | quartzRectConvertsToAppKitUsingHostingScreen | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `quartzRectConvertsToAppKitUsingHostingScreen` |
| 29 | ComputerUseTargetOverlay | degenerateRectanglesAreRejected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `degenerateRectanglesAreRejected` |
| 30 | ComputerUseTargetOverlay | rectOutsideEveryScreenIsRejected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rectOutsideEveryScreenIsRejected` |
| 31 | ComputerUseTargetOverlay | convertedRectPreservesSize | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `convertedRectPreservesSize` |
| 32 | ComputerUseTargetOverlay | intensitiesDifferBetweenExecutionPaths | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `intensitiesDifferBetweenExecutionPaths` |
| 33 | ComputerUseTargetOverlay | badgeTextsDistinguishControlPaths | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `badgeTextsDistinguishControlPaths` |
| 34 | ComputerUseTargetOverlay | overlayLingersBeforeFadingOut | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overlayLingersBeforeFadingOut` |
| 35 | ComputerUseTargetOverlay | followIntervalIsResponsiveButNotBusy | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `followIntervalIsResponsiveButNotBusy` |
| 36 | ComputerUseTargetOverlay | overlayTargetIsEquatable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `overlayTargetIsEquatable` |
| 37 | ComputerUseTargetOverlay | overlayPanelIgnoresMouseAndFocus | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `overlayPanelIgnoresMouseAndFocus` |

| 38 | ComputerUseAuthorizationCard | allowOnceGrantsExactlyOneOperation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allowOnceGrantsExactlyOneOperation` |
| 39 | ComputerUseAuthorizationCard | allowOnceMessageStatesScope | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allowOnceMessageStatesScope` |
| 40 | ComputerUseAuthorizationCard | allowOnceStaysOutOfAllowlist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allowOnceStaysOutOfAllowlist` |
| 41 | ComputerUseAuthorizationCard | alwaysAllowWritesExplicitAllowlist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `alwaysAllowWritesExplicitAllowlist` |
| 42 | ComputerUseAuthorizationCard | authorizationRequiredBecomesSuspension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationRequiredBecomesSuspension` |
| 43 | ComputerUseAuthorizationCard | denialMessageStopsThePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `denialMessageStopsThePath` |
| 44 | ComputerUseAuthorizationCard | denyGrantsNothing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `denyGrantsNothing` |
| 45 | ComputerUseAuthorizationCard | denyIsTheOnlyRejection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `denyIsTheOnlyRejection` |
| 46 | ComputerUseAuthorizationCard | emptyIdentifierIsForbidden | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyIdentifierIsForbidden` |
| 47 | ComputerUseAuthorizationCard | emptyIdentifierIsIgnored | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyIdentifierIsIgnored` |
| 48 | ComputerUseAuthorizationCard | expiredOneShotIsRejected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expiredOneShotIsRejected` |
| 49 | ComputerUseAuthorizationCard | explicitAllowlistPasses | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitAllowlistPasses` |
| 50 | ComputerUseAuthorizationCard | forbiddenDoesNotSuspend | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forbiddenDoesNotSuspend` |
| 51 | ComputerUseAuthorizationCard | foreignPayloadIsNotAnAuthorizationRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foreignPayloadIsNotAnAuthorizationRequest` |
| 52 | ComputerUseAuthorizationCard | oneShotIsConsumedByTheCheck | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `oneShotIsConsumedByTheCheck` |
| 53 | ComputerUseAuthorizationCard | otherErrorsDoNotSuspend | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherErrorsDoNotSuspend` |
| 54 | ComputerUseAuthorizationCard | parsingIsForgiving | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsingIsForgiving` |
| 55 | ComputerUseAuthorizationCard | pendingResultSuspendsTheTurn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingResultSuspendsTheTurn` |
| 56 | ComputerUseAuthorizationCard | purgingKeepsValidEntries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `purgingKeepsValidEntries` |
| 57 | ComputerUseAuthorizationCard | readOnlyCheckDoesNotConsume | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readOnlyCheckDoesNotConsume` |
| 58 | ComputerUseAuthorizationCard | rendererOnlyClaimsItsOwnPayload | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererOnlyClaimsItsOwnPayload` |
| 59 | ComputerUseAuthorizationCard | revokingExplicitAuthorizationAlsoRevokesOneShot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokingExplicitAuthorizationAlsoRevokesOneShot` |
| 60 | ComputerUseAuthorizationCard | revokingOneApplicationKeepsOthersOneShot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokingOneApplicationKeepsOthersOneShot` |
| 61 | ComputerUseAuthorizationCard | successfulResultPassesThrough | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `successfulResultPassesThrough` |
| 62 | ComputerUseAuthorizationCard | tokensRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokensRoundTrip` |
| 63 | ComputerUseAuthorizationCard | unknownAnswerIsNil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownAnswerIsNil` |
| 64 | ComputerUseAuthorizationCard | unknownApplicationNeedsAuthorization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownApplicationNeedsAuthorization` |
| 65 | ComputerUseAuthorizationCardVisibility | completedCallDoesNotRenderCard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedCallDoesNotRenderCard` |
| 66 | ComputerUseAuthorizationCardVisibility | computerUseCardOutranksGenericApproval | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `computerUseCardOutranksGenericApproval` |
| 67 | ComputerUseAuthorizationCardVisibility | decidedRequestDoesNotRenderCard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decidedRequestDoesNotRenderCard` |
| 68 | ComputerUseAuthorizationCardVisibility | suspendedRequestRendersCardEvenWhenAutoApproved | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedRequestRendersCardEvenWhenAutoApproved` |
| 69 | ComputerUseAuthorizationCardVisibility | suspendedRequestRendersCardWhenPending | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedRequestRendersCardWhenPending` |
| 70 | ComputerUseAuthorizationStore | authorizationStorePersistsAcrossInstances | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationStorePersistsAcrossInstances` |
| 71 | ComputerUseAuthorizationStore | revokingExplicitAuthorizationAlsoRevokesNativeAuthorization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokingExplicitAuthorizationAlsoRevokesNativeAuthorization` |
| 72 | ComputerUseSystemPermission | accessibilityBecomesPayloadFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `accessibilityBecomesPayloadFailure` |
| 73 | ComputerUseSystemPermission | applicationAuthorizationStillSuspends | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `applicationAuthorizationStillSuspends` |
| 74 | ComputerUseSystemPermission | everyPermissionHasDisplayText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyPermissionHasDisplayText` |
| 75 | ComputerUseSystemPermission | failureContentCarriesReadableReason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failureContentCarriesReadableReason` |
| 76 | ComputerUseSystemPermission | foreignContentIsNotASystemPermissionRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foreignContentIsNotASystemPermissionRequest` |
| 77 | ComputerUseSystemPermission | messageNamesThePermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageNamesThePermission` |
| 78 | ComputerUseSystemPermission | otherErrorsRemainPlainFailures | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherErrorsRemainPlainFailures` |
| 79 | ComputerUseSystemPermission | payloadRoundTrips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `payloadRoundTrips` |
| 80 | ComputerUseSystemPermission | rendererClaimsSystemPermissionFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererClaimsSystemPermissionFailure` |
| 81 | ComputerUseSystemPermission | rendererIgnoresAuthorizationSuspension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererIgnoresAuthorizationSuspension` |
| 82 | ComputerUseSystemPermission | rendererIgnoresOrdinaryFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererIgnoresOrdinaryFailure` |
| 83 | ComputerUseSystemPermission | rendererOutranksGenericApproval | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererOutranksGenericApproval` |
| 84 | ComputerUseSystemPermission | screenRecordingBecomesPayloadFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `screenRecordingBecomesPayloadFailure` |
| 85 | ComputerUseSystemPermission | screenRecordingRoundTrips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `screenRecordingRoundTrips` |

> 说明：全部 **85 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 72 / 72
- P2: 已覆盖 7 / 7
- **合计: 85 / 85**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（72 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 85 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
