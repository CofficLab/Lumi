# TestPlan — PluginComputerUse

## 包概述

PluginComputerUse 的实现包，包含 14 个主要类型；当前测试覆盖 113 条用例。

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 113

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

- **AccessibilityIntegration**（1 条）：由 `accessibilityOperatesBackgroundFixtureWithoutMovingCursorOrActivatingIt` 用例锁定；改动该模块时优先跑对应测试文件。
- **ApplicationActivationObserver**（1 条）：由 `activationObserverCallsBackUntilCancelled` 用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseActionParser**（6 条）：由 `parserSupportsAllActionsAndAppliesDefaults`、`parserAcceptsExactlyTenActions` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseImageEncoder**（2 条）：由 `imageEncoderDownscalesAndReturnsReadableJPEGAttachment`、`downscalePreservesSmallImagesAndHandlesNonPositiveLimit` 用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseInputExecutor**（4 条）：由 `inputExecutorMapsInBoundsImageCoordinates`、`inputExecutorRejectsInvalidCoordinatesWithoutIntegerOverflow` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseModels**（6 条）：由 `observationMapsImageCoordinatesIntoWindowCoordinates`、`observationFallsBackToWindowOriginForInvalidImageDimensions` 等用例锁定；改动该模块时优先跑对应测试文件。
- **NativeControl**（6 条）：由 `revokedInputLeaseCannotBeRestarted`、`expiredLeaseRejectsFurtherInput` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 目标窗口提示遮罩**（12 条）：由 `quartzRectConvertsToAppKitUsingHostingScreen`、`degenerateRectanglesAreRejected` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 会话作用域授权**（5 条）：由 `grantIsNotConsumedWithinTheSession`、`emptyIdentifierIsIgnored` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 授权决策解析**（7 条）：由 `allowMessageStatesScope`、`denialMessageNamesTheApplication` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 工具授权挂起**（4 条）：由 `authorizationRequiredBecomesSuspension`、`forbiddenDoesNotSuspend` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 授权决策落地**（2 条）：由 `denyGrantsNothing`、`allowForTaskGrantsSessionScopedAccess` 用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 访问判定**（7 条）：由 `emptyIdentifierIsForbidden`、`sessionGrantPassesWithoutBeingConsumed` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 授权挂起载荷**（3 条）：由 `foreignPayloadIsNotAnAuthorizationRequest`、`pendingResultSuspendsTheTurn` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 授权卡片的渲染条件**（5 条）：由 `completedCallDoesNotRenderCard`、`computerUseCardOutranksGenericApproval` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseAuthorizationStore**（1 条）：由 `nativeAuthorizationStoresAndPersistsAcrossInstances` 用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 系统权限错误映射**（4 条）：由 `accessibilityBecomesPayloadFailure`、`applicationAuthorizationStillSuspends` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 系统权限展示**（2 条）：由 `everyPermissionHasDisplayText`、`messageNamesThePermission` 用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 系统权限载荷**（3 条）：由 `failureContentCarriesReadableReason`、`foreignContentIsNotASystemPermissionRequest` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ComputerUseSystemPermission**（2 条）：由 `payloadRoundTrips`、`rendererOutranksGenericApproval` 用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 系统权限渲染器**（3 条）：由 `rendererClaimsSystemPermissionFailure`、`rendererIgnoresAuthorizationSuspension` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 访问上下文**（4 条）：由 `autonomousAllowsUnattendedAccess`、`autonomousSessionNeverRequestsAuthorization` 等用例锁定；改动该模块时优先跑对应测试文件。
- **None**（2 条）：由 `autonomousSessionSkipsNativeConsentButKeepsStopAvailable`、`legacyExplicitAllowlistIsPurged` 用例锁定；改动该模块时优先跑对应测试文件。
- **Computer Use 目标窗口可见区域**（17 条）：由 `cornerOccluderKeepsMostOfTarget`、`degenerateTargetHasNoVisibleRegion` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 9 | ComputerUseImageEncoder | imageEncoderDownscalesAndReturnsReadableJPEGAttachment | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageEncoderDownscalesAndReturnsReadableJPEGAttachment` |
| 10 | ComputerUseImageEncoder | downscalePreservesSmallImagesAndHandlesNonPositiveLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `downscalePreservesSmallImagesAndHandlesNonPositiveLimit` |
| 11 | ComputerUseInputExecutor | inputExecutorMapsInBoundsImageCoordinates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inputExecutorMapsInBoundsImageCoordinates` |
| 12 | ComputerUseInputExecutor | inputExecutorRejectsInvalidCoordinatesWithoutIntegerOverflow | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `inputExecutorRejectsInvalidCoordinatesWithoutIntegerOverflow` |
| 13 | ComputerUseInputExecutor | keyCodeRecognizesLettersDigitsAndCommonKeys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keyCodeRecognizesLettersDigitsAndCommonKeys` |
| 14 | ComputerUseInputExecutor | screenshotAndZeroWaitActionsDoNotPostInputEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `screenshotAndZeroWaitActionsDoNotPostInputEvents` |
| 15 | ComputerUseModels | observationMapsImageCoordinatesIntoWindowCoordinates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observationMapsImageCoordinatesIntoWindowCoordinates` |
| 16 | ComputerUseModels | observationFallsBackToWindowOriginForInvalidImageDimensions | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `observationFallsBackToWindowOriginForInvalidImageDimensions` |
| 17 | ComputerUseModels | actionsReportWhetherTheyChangeApplicationState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actionsReportWhetherTheyChangeApplicationState` |
| 18 | ComputerUseModels | windowSelectionMatchesApplicationAndTitleCaseInsensitively | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `windowSelectionMatchesApplicationAndTitleCaseInsensitively` |
| 19 | ComputerUseModels | blankWindowFiltersUseTheFrontmostApplication | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `blankWindowFiltersUseTheFrontmostApplication` |
| 20 | ComputerUseModels | computerUseErrorsProvideReadableLocalizedDescriptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `computerUseErrorsProvideReadableLocalizedDescriptions` |
| 21 | NativeControl | revokedInputLeaseCannotBeRestarted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokedInputLeaseCannotBeRestarted` |
| 22 | NativeControl | expiredLeaseRejectsFurtherInput | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `expiredLeaseRejectsFurtherInput` |
| 23 | NativeControl | eventMarkerAloneCannotMasqueradeAsLumi | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `eventMarkerAloneCannotMasqueradeAsLumi` |
| 24 | NativeControl | nativeControlHoldsExclusiveLeaseAndStopRequiresFreshConsent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nativeControlHoldsExclusiveLeaseAndStopRequiresFreshConsent` |
| 25 | NativeControl | resumeRequiresFreshObservationAndNeverReplaysBatch | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeRequiresFreshObservationAndNeverReplaysBatch` |
| 26 | NativeControl | cancellationWhileAwaitingConsentReleasesUI | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellationWhileAwaitingConsentReleasesUI` |
| 27 | Computer Use 目标窗口提示遮罩 | quartzRectConvertsToAppKitUsingHostingScreen | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `quartzRectConvertsToAppKitUsingHostingScreen` |
| 28 | Computer Use 目标窗口提示遮罩 | degenerateRectanglesAreRejected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `degenerateRectanglesAreRejected` |
| 29 | Computer Use 目标窗口提示遮罩 | rectOutsideEveryScreenIsRejected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rectOutsideEveryScreenIsRejected` |
| 30 | Computer Use 目标窗口提示遮罩 | convertedRectPreservesSize | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `convertedRectPreservesSize` |
| 31 | Computer Use 目标窗口提示遮罩 | intensitiesDifferBetweenExecutionPaths | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `intensitiesDifferBetweenExecutionPaths` |
| 32 | Computer Use 目标窗口提示遮罩 | badgeTextsDistinguishControlPaths | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `badgeTextsDistinguishControlPaths` |
| 33 | Computer Use 目标窗口提示遮罩 | overlayLingersBeforeFadingOut | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overlayLingersBeforeFadingOut` |
| 34 | Computer Use 目标窗口提示遮罩 | followIntervalIsResponsiveButNotBusy | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `followIntervalIsResponsiveButNotBusy` |
| 35 | Computer Use 目标窗口提示遮罩 | overlayTargetIsEquatable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `overlayTargetIsEquatable` |
| 36 | Computer Use 目标窗口提示遮罩 | overlayPanelIgnoresMouseAndFocus | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `overlayPanelIgnoresMouseAndFocus` |
| 37 | Computer Use 会话作用域授权 | 授权在本会话内持续有效，不被消费 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `grantIsNotConsumedWithinTheSession` |
| 38 | Computer Use 授权决策解析 | 放行文案说明仅本任务有效 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allowMessageStatesScope` |
| 39 | Computer Use 工具授权挂起 | authorizationRequiredBecomesSuspension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationRequiredBecomesSuspension` |
| 40 | Computer Use 授权决策解析 | 拒绝文案点名目标应用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `denialMessageNamesTheApplication` |
| 41 | Computer Use 授权决策落地 | denyGrantsNothing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `denyGrantsNothing` |
| 42 | Computer Use 授权决策解析 | denyIsTheOnlyRejection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `denyIsTheOnlyRejection` |
| 43 | Computer Use 访问判定 | emptyIdentifierIsForbidden | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyIdentifierIsForbidden` |
| 44 | Computer Use 会话作用域授权 | emptyIdentifierIsIgnored | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyIdentifierIsIgnored` |
| 45 | Computer Use 会话作用域授权 | 授权过期后不再有效 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expiredGrantIsRejected` |
| 46 | Computer Use 工具授权挂起 | forbiddenDoesNotSuspend | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forbiddenDoesNotSuspend` |
| 47 | Computer Use 授权挂起载荷 | foreignPayloadIsNotAnAuthorizationRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foreignPayloadIsNotAnAuthorizationRequest` |
| 48 | Computer Use 访问判定 | A2 会话授权过一次后放行，且授权在会话内不被消费 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sessionGrantPassesWithoutBeingConsumed` |
| 49 | Computer Use 工具授权挂起 | otherErrorsDoNotSuspend | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherErrorsDoNotSuspend` |
| 50 | Computer Use 授权决策解析 | parsingIsForgiving | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsingIsForgiving` |
| 51 | Computer Use 授权挂起载荷 | pendingResultSuspendsTheTurn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingResultSuspendsTheTurn` |
| 52 | Computer Use 访问判定 | readOnlyCheckDoesNotConsume | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readOnlyCheckDoesNotConsume` |
| 53 | Computer Use 授权挂起载荷 | rendererOnlyClaimsItsOwnPayload | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererOnlyClaimsItsOwnPayload` |
| 54 | Computer Use 会话作用域授权 | 撤销会话授权不影响其他会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokingOneSessionKeepsOthers` |
| 55 | Computer Use 工具授权挂起 | successfulResultPassesThrough | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `successfulResultPassesThrough` |
| 56 | Computer Use 授权决策解析 | tokensRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokensRoundTrip` |
| 57 | Computer Use 授权决策解析 | unknownAnswerIsNil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownAnswerIsNil` |
| 58 | Computer Use 访问判定 | A2 会话中未授权的应用返回需要授权并带上应用信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownApplicationNeedsAuthorizationInBuildMode` |
| 59 | Computer Use 授权卡片的渲染条件 | completedCallDoesNotRenderCard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedCallDoesNotRenderCard` |
| 60 | Computer Use 授权卡片的渲染条件 | computerUseCardOutranksGenericApproval | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `computerUseCardOutranksGenericApproval` |
| 61 | Computer Use 授权卡片的渲染条件 | decidedRequestDoesNotRenderCard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decidedRequestDoesNotRenderCard` |
| 62 | Computer Use 授权卡片的渲染条件 | suspendedRequestRendersCardEvenWhenAutoApproved | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedRequestRendersCardEvenWhenAutoApproved` |
| 63 | Computer Use 授权卡片的渲染条件 | suspendedRequestRendersCardWhenPending | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedRequestRendersCardWhenPending` |
| 64 | ComputerUseAuthorizationStore | 原生控制授权可存储、撤销且跨实例持久化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nativeAuthorizationStoresAndPersistsAcrossInstances` |
| 65 | Computer Use 系统权限错误映射 | accessibilityBecomesPayloadFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `accessibilityBecomesPayloadFailure` |
| 66 | Computer Use 系统权限错误映射 | applicationAuthorizationStillSuspends | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `applicationAuthorizationStillSuspends` |
| 67 | Computer Use 系统权限展示 | everyPermissionHasDisplayText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyPermissionHasDisplayText` |
| 68 | Computer Use 系统权限载荷 | failureContentCarriesReadableReason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failureContentCarriesReadableReason` |
| 69 | Computer Use 系统权限载荷 | foreignContentIsNotASystemPermissionRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foreignContentIsNotASystemPermissionRequest` |
| 70 | Computer Use 系统权限展示 | messageNamesThePermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageNamesThePermission` |
| 71 | Computer Use 系统权限错误映射 | otherErrorsRemainPlainFailures | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherErrorsRemainPlainFailures` |
| 72 | ComputerUseSystemPermission | payloadRoundTrips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `payloadRoundTrips` |
| 73 | Computer Use 系统权限渲染器 | rendererClaimsSystemPermissionFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererClaimsSystemPermissionFailure` |
| 74 | Computer Use 系统权限渲染器 | rendererIgnoresAuthorizationSuspension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererIgnoresAuthorizationSuspension` |
| 75 | Computer Use 系统权限渲染器 | rendererIgnoresOrdinaryFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererIgnoresOrdinaryFailure` |
| 76 | ComputerUseSystemPermission | rendererOutranksGenericApproval | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererOutranksGenericApproval` |
| 77 | Computer Use 系统权限错误映射 | screenRecordingBecomesPayloadFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `screenRecordingBecomesPayloadFailure` |
| 78 | Computer Use 系统权限载荷 | screenRecordingRoundTrips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `screenRecordingRoundTrips` |
| 79 | Computer Use 授权决策落地 | 本任务内允许只产生会话作用域的授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allowForTaskGrantsSessionScopedAccess` |
| 80 | Computer Use 访问上下文 | A3 会话允许无人值守访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `autonomousAllowsUnattendedAccess` |
| 81 | Computer Use 访问判定 | A3 会话中任何应用都直接放行，不打扰用户 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `autonomousModeAllowsEveryApplication` |
| 82 | Computer Use 访问判定 | A3 会话的只读查询恒为已授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `autonomousReadOnlyCheckIsAlwaysAuthorized` |
| 83 | Computer Use 访问上下文 | A3 会话在共享判定入口上不产生任何授权请求 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `autonomousSessionNeverRequestsAuthorization` |
| 84 | None | A3 会话跳过原生确认但仍保留停止通道 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `autonomousSessionSkipsNativeConsentButKeepsStopAvailable` |
| 85 | Computer Use 访问上下文 | A2 会话不允许无人值守访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildDoesNotAllowUnattendedAccess` |
| 86 | Computer Use 授权决策解析 | 授权卡片只有两个选项 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cardHasExactlyTwoOptions` |
| 87 | Computer Use 访问上下文 | A1 会话不允许无人值守访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatDoesNotAllowUnattendedAccess` |
| 88 | Computer Use 目标窗口可见区域 | 遮挡物只压住一角时可见区域仍覆盖绝大部分目标 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cornerOccluderKeepsMostOfTarget` |
| 89 | Computer Use 目标窗口可见区域 | 退化尺寸的目标矩形没有可见区域 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `degenerateTargetHasNoVisibleRegion` |
| 90 | Computer Use 目标窗口可见区域 | 窗口列表为空时无法定位目标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyWindowListCannotLocateTarget` |
| 91 | Computer Use 目标窗口可见区域 | 完全被遮挡时可见区域为空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullyOccludedTargetHasNoVisibleRegion` |
| 92 | Computer Use 会话作用域授权 | 授权不跨会话生效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `grantDoesNotLeakAcrossConversations` |
| 93 | None | 旧版显式白名单被清除且原生授权保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyExplicitAllowlistIsPurged` |
| 94 | Computer Use 目标窗口可见区域 | 遮挡物压在中间时可见区域被切成上下两条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `middleOccluderSplitsTarget` |
| 95 | Computer Use 目标窗口可见区域 | 多个遮挡物叠加后可见区域总面积等于原面积减去被遮面积 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleOccludersPreserveArea` |
| 96 | Computer Use 目标窗口可见区域 | 没有遮挡时可见区域就是目标矩形本身 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noOccluderKeepsWholeTarget` |
| 97 | Computer Use 目标窗口可见区域 | 与目标不相交的遮挡物不产生影响 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonIntersectingOccluderIsIgnored` |
| 98 | Computer Use 目标窗口可见区域 | 遮挡物从右侧压入时可见区域只剩左侧一条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rightOccluderLeavesLeftBand` |
| 99 | Computer Use 访问判定 | A2 会话的授权不跨会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `sessionGrantDoesNotLeakAcrossConversations` |
| 100 | Computer Use 目标窗口可见区域 | 残留的细条区域被丢弃 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sliverRegionsAreDiscarded` |
| 101 | Computer Use 目标窗口可见区域 | 没有窗口 ID 时按进程与矩形重叠近似匹配目标 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `targetIsMatchedByProcessAndOverlap` |
| 102 | Computer Use 目标窗口可见区域 | 遮挡物从上方压入时可见区域只剩下方一条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topOccluderLeavesBottomBand` |
| 103 | Computer Use 目标窗口可见区域 | 可见区域互不重叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visibleRegionsDoNotOverlap` |
| 104 | Computer Use 目标窗口可见区域 | 排在目标后面的窗口不算遮挡者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `windowsBehindTargetAreNotOccluders` |
| 105 | Computer Use 目标窗口可见区域 | 按窗口 ID 定位目标时排在目标前面的窗口都算遮挡者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `windowsInFrontOfTargetAreOccluders` |
| 106 | Computer Use 目标窗口提示遮罩 | 目标矩形不变时仍重算可见区域 | — | 轮询时当前面板矩形与目标矩形相同 | 不移动面板，但仍重算可见区域 | P1 | ✅ 已覆盖 | `unchangedTargetStillRefreshesVisibleRegions` |
| 107 | Computer Use 目标窗口提示遮罩 | 目标矩形变化时移动面板并重算可见区域 | — | 轮询时当前面板矩形与目标矩形不同 | 移动面板并重算可见区域 | P1 | ✅ 已覆盖 | `changedTargetMovesPanelAndRefreshes` |
| 108 | Computer Use 目标窗口可见区域 | 浮动层窗口同样是遮挡者 | — | 前方浮动面板 layer = 3 完全盖住目标 | 可见区域为空 | P1 | ✅ 已覆盖 | `floatingWindowIsOccluder` |
| 109 | Computer Use 目标窗口可见区域 | 自身遮罩面板不计入遮挡者 | — | 自身遮罩面板与目标完全重合 | 排除自身后可见区域等于目标矩形 | P1 | ✅ 已覆盖 | `overlayPanelIsExcluded` |

| 110 | Computer Use 授权恢复 | allowTokenReexecutes | 卡片回传 computer_use.allow_for_task | 解析恢复回答 | 必须重新执行工具，动作是 reexecute | P0 | ✅ 已覆盖 | `allowTokenReexecutes` |
| 111 | Computer Use 授权恢复 | denyTokenRejectsWithMessage | 卡片回传 computer_use.deny 与说明 | 解析恢复回答 | 以说明文案失败结束，动作是 reject | P1 | ✅ 已覆盖 | `denyTokenRejectsWithMessage` |
| 112 | Computer Use 授权恢复 | unknownAnswerReturnsText | 无法识别的恢复回答 | 解析恢复回答 | 保持 returnAnswer，把回答当结果 | P2 | ✅ 已覆盖 | `unknownAnswerReturnsText` |
| 113 | Computer Use 授权恢复 | toolsDeclareResumeActionThroughExistential | 四个挂起工具通过 any SuperAgentTool 调用 | 分别传入允许、拒绝与普通回答 | 允许为 reexecute、拒绝为 reject、普通为 returnAnswer，动态分派不被默认实现吞掉 | P1 | ✅ 已覆盖 | `toolsDeclareResumeActionThroughExistential` |

> 说明：全部 **113 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 90 / 90
- P2: 已覆盖 12 / 12
- **合计: 113 / 113**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（11 条）
- **P1**: 其余功能性用例（90 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（12 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 113 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
