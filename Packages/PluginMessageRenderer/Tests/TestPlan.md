# TestPlan — PluginMessageRenderer

## 包概述

PluginMessageRenderer 的实现包，包含 14 个主要类型；当前测试覆盖 311 条用例。

平台: macOS 14+, iOS 17+
测试文件: 31 个，用例总数: 311

核心组件（源码目录）:
- `Capabilities/`
- `Components/`
- `Helpers/`
- `Models/`
- `Observers/`
- `Renderers/`
- `Services/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MessageRendererPlugin`
- `RiskApprovalPendingInteraction`
- `MessageRendererCapability`
- `BorderedUtilityContent`
- `CollapsedContentChips`
- `CollapsiblePlainText`
- `CompactMessageHeaderView`
- `ErrorTransportDetailsButton`
- `MessageDiagnosticStrip`
- `MessageFileAttachmentChips`
- `MessageInfoButton`
- `ResendMessageButton`
- `RetryTurnButton`
- `ThinkingPopoverContent`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentLoopRetrySummary**（3 条）：由 `statusUsesInjectedLocalization`、`retryAfterUsesInjectedLocalization`、`retryLabelsHaveTranslationsInCompiledBundle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTAssistantMessageView**（13 条）：由 `routesOnlyChatGPTVerbosity`、`assistantBodyHasNoChrome`、`typographyAndSpacing` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTChatMarkdownTheme**（7 条）：由 `legacyMakeKeepsEveryField`、`legacyMakeDoesNotApplyChatGPTGeometry`、`zcodeMakeDoesNotApplyChatGPTGeometry` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTErrorMessageView**（5 条）：由 `realFailedTurnCanRetry`、`staleTurnCannotRetry`、`missingTurnIDCannotRetry` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTMessageRouting**（8 条）：由 `rendererSelectionIsUnchangedByVerbosity`、`preferredRendererIDWins`、`assistantUsesChatGPTViewForV5` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTReasoningView**（7 条）：由 `emptyTextDoesNotRender`、`summaryIsLastNonEmptyLine`、`durationRequiresRealField` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTRendererAccessibility**（7 条）：由 `reducedMotionDisablesFade`、`reducedMotionDisablesShiftAndShimmer`、`globallyDisabledAnimationsAlsoOff` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTTimelineMarker**（8 条）：由 `rendersWithContentOrMetadata`、`doesNotRenderEmptyShell`、`modelSwitchUsesRealModelName` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTToolWorkHistoryView**（11 条）：由 `singleToolDoesNotGroup`、`multipleGroupableToolsGroup`、`mixedFamilyDoesNotGroup` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatGPTUserMessageView**（8 条）：由 `routesOnlyChatGPTVerbosity`、`bubbleWidthHugsShortTextAndConstrainsLongText`、`longURLWrapsWithoutLegacyCollapse` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageContextMenuStop**（15 条）：由 `canStopWhileRunning`、`canStopWhileSuspended`、`cannotStopWhenNoActiveTurn` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageHeaderVisibility**（3 条）：由 `richModesShowHeader`、`briefAndStandardNoHeaderHideHeader`、`explicitFalseWins` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageRendererPlugin**（15 条）：由 `assistantContentVerbosity`、`v1DoesNotUseCustomToolRenderers`、`formatsToolCallArguments` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ModelSwitchSummary**（9 条）：由 `sameModelAcrossProvidersKeepsProviders`、`labelsPrefixProvidersOnlyWhenDisambiguating`、`differentModelsStayCompact` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RetryTurnButton**（6 条）：由 `retryableWhenTurnMatches`、`notRetryableAfterTurnSuperseded`、`notRetryableWithoutTurnID` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalAfterConversationSwitch**（5 条）：由 `approvalCardDoesNotReappearAfterSwitchingBack`、`approvalCardDoesNotReappearAfterRejecting`、`cacheDoesNotResurrectAwaitingUserResponseResult` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalCancellation**（9 条）：由 `cancelledTurnClearsPendingApproval`、`terminalEventsClearPendingApproval`、`staleTerminalEventKeepsNewerTurnApproval` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalMisclaim**（4 条）：由 `askUserSuspensionIsNotClaimedByApprovalRenderer`、`misclaimedToolCallCannotBuildRequest`、`realPermissionRequestIsStillClaimed` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalVisibilityAfterResolution**（4 条）：由 `showsApprovalWhilePending`、`hidesApprovalAfterUserApproved`、`hidesApprovalAfterUserRejected` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallGroupCollapsePolicy**（15 条）：由 `singleCallIsNotCollapsed`、`emptyGroupIsNotCollapsed`、`multipleCompletedCallsAreCollapsed` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallRendererDispatchDecoding**（10 条）：由 `matchingBridgeDoesNotDecodeImages`、`matchingBridgeKeepsMatchingInformation`、`matchingBridgeMatchesFullBridgeOnMatchingDimensions` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJobSummary**（5 条）：由 `mapsAllStatuses`、`projectsLiveJob`、`terminalJobIsNotStale` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeAssistantMessageView**（23 条）：由 `bodyFontSizeIs14`、`trackingIs035`、`targetLineHeightIs245` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeChatMarkdownTheme**（5 条）：由 `legacyMakeKeepsEveryField`、`legacyMakeDoesNotApplyZCodeGeometry`、`zcodeMakeInheritsZCodeGeometry` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeMessageTimeLabel**（9 条）：由 `nonPositiveTimestampIsHidden`、`nonFiniteTimestampIsHidden`、`invalidNowIsHidden` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeReasoningSummary**（5 条）：由 `matchesReferenceImplementation`、`emptyContentReturnsNil`、`picksLastNonEmptyLine` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeReasoningView**（21 条）：由 `emptyStreamingReasoningIsHidden`、`blankStreamingReasoningIsHidden`、`nonEmptyReasoningIsRendered` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeTimelineMarker**（15 条）：由 `emptyEventIsHidden`、`eventWithContentIsRendered`、`turnCompletedIsMarkerNotBubble` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeToolWorkHistoryView**（24 条）：由 `singleToolIsNotGrouped`、`emptyToolsAreNotGrouped`、`consecutiveExploreExecuteAreGrouped` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeUserBubbleCollapseState**（8 条）：由 `defaultCollapsed`、`explicitExpand`、`explicitCollapse` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ZCodeUserMessageView**（24 条）：由 `cornerRadiiMatchZCode`、`paddingMatchesZCode`、`innerSpacingIs8` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentLoopRetrySummary | 状态文案经过注入的本地化解析（回归 #895） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `statusUsesInjectedLocalization` |
| 2 | AgentLoopRetrySummary | 退避文案经过注入的本地化解析（回归 #895） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryAfterUsesInjectedLocalization` |
| 3 | AgentLoopRetrySummary | 自动重试词条在所有规范语言下都有译文（回归 #895） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryLabelsHaveTranslationsInCompiledBundle` |
| 4 | ChatGPTAssistantMessageView | 只有 V5 使用 ChatGPT 助手呈现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `routesOnlyChatGPTVerbosity` |
| 5 | ChatGPTAssistantMessageView | 助手正文没有气泡、头像、名称与默认时间戳 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantBodyHasNoChrome` |
| 6 | ChatGPTAssistantMessageView | 正文 15、目标行高 24，工作项间距 12 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `typographyAndSpacing` |
| 7 | ChatGPTAssistantMessageView | 正文 lineSpacing 由 NSFont 实际行高换算，不等于目标行高 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineSpacingDerivedFromFont` |
| 8 | ChatGPTAssistantMessageView | 流式正文没有 cursor、淡入与脉冲 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingHasNoDecorativeEffects` |
| 9 | ChatGPTAssistantMessageView | 操作栏占位与 hover 无关，只看轮尾 + 已完成 + 有内容 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `actionBarSlotIgnoresHover` |
| 10 | ChatGPTAssistantMessageView | 操作栏显示需要轮尾 + 已完成 + hover 三者同时成立 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actionBarVisibilityRequiresHover` |
| 11 | ChatGPTAssistantMessageView | 没有 context 时操作栏永远不显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actionBarHiddenWithoutContext` |
| 12 | ChatGPTAssistantMessageView | 复制文本为空时不显示复制按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyButtonNeedsText` |
| 13 | ChatGPTAssistantMessageView | 操作栏几何符合 V5 token | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actionBarMetrics` |
| 14 | ChatGPTAssistantMessageView | 成功回复不显示重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `successfulReplyHasNoRetry` |
| 15 | ChatGPTAssistantMessageView | 只有真实可重试的失败回合才有重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `onlyRealFailedTurnCanRetry` |
| 16 | ChatGPTAssistantMessageView | 回合已失效时没有重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleTurnHasNoRetry` |
| 17 | ChatGPTChatMarkdownTheme | 旧 make(from:) 的每个字段逐值不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyMakeKeepsEveryField` |
| 18 | ChatGPTChatMarkdownTheme | 旧 make(from:) 不带 V5 的几何覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyMakeDoesNotApplyChatGPTGeometry` |
| 19 | ChatGPTChatMarkdownTheme | makeZCode 不带 V5 的几何覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zcodeMakeDoesNotApplyChatGPTGeometry` |
| 20 | ChatGPTChatMarkdownTheme | makeChatGPT 继承 MarkdownTheme.chatGPT 的全部几何 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatGPTMakeInheritsChatGPTGeometry` |
| 21 | ChatGPTChatMarkdownTheme | makeChatGPT 叠加宿主文字颜色 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatGPTMakeAppliesHostColors` |
| 22 | ChatGPTChatMarkdownTheme | V5 正文 15、目标行高 24 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatGPTTypography` |
| 23 | ChatGPTChatMarkdownTheme | V5 表格横向滚动，不撑破阅读列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatGPTTableScrollsHorizontally` |
| 24 | ChatGPTErrorMessageView | 真实可重试的失败回合提供重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `realFailedTurnCanRetry` |
| 25 | ChatGPTErrorMessageView | 回合已失效时不提供重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleTurnCannotRetry` |
| 26 | ChatGPTErrorMessageView | 没有 turnID 时不提供重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `missingTurnIDCannotRetry` |
| 27 | ChatGPTErrorMessageView | 没有 capability 时不提供重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `missingCapabilityCannotRetry` |
| 28 | ChatGPTErrorMessageView | 几何符合 V5 token | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metrics` |
| 29 | ChatGPTMessageRouting | V5 下各角色仍由核心 renderer 接管 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererSelectionIsUnchangedByVerbosity` |
| 30 | ChatGPTMessageRouting | preferredRendererID 仍然优先，V5 不截获 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preferredRendererIDWins` |
| 31 | ChatGPTMessageRouting | V5 的助手正文使用 ChatGPT 视图而非 legacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantUsesChatGPTViewForV5` |
| 32 | ChatGPTMessageRouting | V5 的用户消息使用 ChatGPT 气泡 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userUsesChatGPTBubbleForV5` |
| 33 | ChatGPTMessageRouting | timeline marker 是 V5 的系统事件呈现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `timelineMarkerHandlesSystemEvents` |
| 34 | ChatGPTMessageRouting | 独立工具消息保持工具呈现，不落到 timeline marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `standaloneToolKeepsToolRendering` |
| 35 | ChatGPTMessageRouting | tool-step-group 走助手分支，由 ChatGPT 助手视图承载工具组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolStepGroupUsesAssistantRenderer` |
| 36 | ChatGPTMessageRouting | 错误消息在 V5 下走内联错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorUsesInlineErrorForV5` |
| 37 | ChatGPTReasoningView | 空文本不渲染 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyTextDoesNotRender` |
| 38 | ChatGPTReasoningView | 摘要是最后一个非空行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `summaryIsLastNonEmptyLine` |
| 39 | ChatGPTReasoningView | 没有真实时长字段时不显示时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationRequiresRealField` |
| 40 | ChatGPTReasoningView | 真实时长按秒或毫秒格式化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationFormatting` |
| 41 | ChatGPTReasoningView | 完成后自动收起，但用户的显式选择优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `autoCollapseRespectsExplicitChoice` |
| 42 | ChatGPTReasoningView | 用户显式收起后不会被自动展开 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitCollapseIsSticky` |
| 43 | ChatGPTReasoningView | 几何符合 V5 token | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metrics` |
| 44 | ChatGPTRendererAccessibility | Reduced Motion 下关闭淡入动画 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reducedMotionDisablesFade` |
| 45 | ChatGPTRendererAccessibility | Reduced Motion 下关闭位移与 shimmer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reducedMotionDisablesShiftAndShimmer` |
| 46 | ChatGPTRendererAccessibility | 全局禁用动画时同样关闭 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `globallyDisabledAnimationsAlsoOff` |
| 47 | ChatGPTRendererAccessibility | 渲染层标识符稳定且带 chatgpt 前缀 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `rendererIdentifiersAreStable` |
| 48 | ChatGPTRendererAccessibility | 渲染层与列表层标识符前缀不同 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererAndListPrefixesDiffer` |
| 49 | ChatGPTRendererAccessibility | 流式不逐 token 发 announcement | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingDoesNotAnnouncePerToken` |
| 50 | ChatGPTRendererAccessibility | reasoning 完成时只做一次语义更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningCompletionUpdatesSemanticsOnce` |
| 51 | ChatGPTTimelineMarker | 有正文或真实元数据时渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersWithContentOrMetadata` |
| 52 | ChatGPTTimelineMarker | 空正文且无元数据时不渲染 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `doesNotRenderEmptyShell` |
| 53 | ChatGPTTimelineMarker | model-switch 显示真实模型名，缺失时不显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelSwitchUsesRealModelName` |
| 54 | ChatGPTTimelineMarker | agent-loop-retry 显示真实重试原因 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryUsesRealReason` |
| 55 | ChatGPTTimelineMarker | goal 标题来自真实字段，缺失时为空数组 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `goalTitlesRequireRealField` |
| 56 | ChatGPTTimelineMarker | 图标按事件类型选择，都是系统 SF Symbol | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconsAreSystemSymbols` |
| 57 | ChatGPTTimelineMarker | turn-completed 标记不显示多余文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnCompletedHasNoExtraText` |
| 58 | ChatGPTTimelineMarker | timeline marker 没有气泡、头像与旧 chrome | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noChrome` |
| 59 | ChatGPTToolWorkHistoryView | 单个工具不形成父分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleToolDoesNotGroup` |
| 60 | ChatGPTToolWorkHistoryView | 两个及以上同类工具形成父分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleGroupableToolsGroup` |
| 61 | ChatGPTToolWorkHistoryView | 混入非分组家族时不形成父分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mixedFamilyDoesNotGroup` |
| 62 | ChatGPTToolWorkHistoryView | 工具名大小写不敏感 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNameMatchingIsCaseInsensitive` |
| 63 | ChatGPTToolWorkHistoryView | 等待用户响应的工具必须被识别 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `detectsAwaitingUserResponse` |
| 64 | ChatGPTToolWorkHistoryView | 待授权状态的工具必须被识别 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `detectsPendingAuthorizationState` |
| 65 | ChatGPTToolWorkHistoryView | 没有待授权工具时不默认展开 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotExpandWithoutPendingAuthorization` |
| 66 | ChatGPTToolWorkHistoryView | 有待授权工具时默认展开，不隐藏授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expandsWhenAuthorizationPending` |
| 67 | ChatGPTToolWorkHistoryView | 摘要包含真实工具名与真实数量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryShowsRealNamesAndCount` |
| 68 | ChatGPTToolWorkHistoryView | 没有工具名时摘要为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `summaryEmptyWithoutNames` |
| 69 | ChatGPTToolWorkHistoryView | 几何符合 V5 token | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metrics` |
| 70 | ChatGPTUserMessageView | 只有 V5 使用 ChatGPT 用户消息呈现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `routesOnlyChatGPTVerbosity` |
| 71 | ChatGPTUserMessageView | 短文本按理想宽度收缩，长文本受气泡最大宽约束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bubbleWidthHugsShortTextAndConstrainsLongText` |
| 72 | ChatGPTUserMessageView | 长 URL 自然换行且不进入 120pt 折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `longURLWrapsWithoutLegacyCollapse` |
| 73 | ChatGPTUserMessageView | collapsed content metadata 仍使用 chip 呈现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapsedMetadataUsesChips` |
| 74 | ChatGPTUserMessageView | 只有附件时不产生空气泡 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `attachmentOnlyMessageHasNoEmptyBubble` |
| 75 | ChatGPTUserMessageView | 复制使用原始正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyUsesRawContent` |
| 76 | ChatGPTUserMessageView | 再次发送只调用一次现有 capability 并保留原文和会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resendSendsExactlyOneRequest` |
| 77 | ChatGPTUserMessageView | 气泡与操作按钮使用 V5 几何 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bubbleAndActionMetrics` |
| 78 | MessageContextMenuStop | 回合 running 时可停止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canStopWhileRunning` |
| 79 | MessageContextMenuStop | 回合 suspended 时也可停止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canStopWhileSuspended` |
| 80 | MessageContextMenuStop | 回合空闲 / 已完成 / 已失败 / 已取消时不可停止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cannotStopWhenNoActiveTurn` |
| 81 | MessageContextMenuStop | 缺少能力时不可停止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cannotStopWithoutCapability` |
| 82 | MessageContextMenuStop | 可停止性与消息角色无关 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopVisibilityIsIndependentOfMessageRole` |
| 83 | MessageContextMenuStop | running 与 suspended 都判定为可停止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canStopTurnReflectsRunningAndSuspended` |
| 84 | MessageContextMenuStop | 其余回合状态都判定为不可停止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canStopTurnIsFalseForTerminalStates` |
| 85 | MessageContextMenuStop | 停止动作取消的是消息所属会话的回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopTurnCancelsTheGivenConversation` |
| 86 | MessageContextMenuStop | 停止后回合状态变为 cancelled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopTurnLeavesCancelledState` |
| 87 | MessageContextMenuStop | 缺少 AgentLoop Provider 时安全降级 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `degradesGracefullyWithoutAgentLoop` |
| 88 | MessageContextMenuStop | 停止的是消息自己的 conversationID，而非当前选中会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsOwnConversationNotSelectedOne` |
| 89 | MessageContextMenuStop | 用户消息且有正文时提供重新发送 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resendAvailableForUserMessage` |
| 90 | MessageContextMenuStop | 非用户消息不提供重新发送 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resendHiddenForNonUserMessages` |
| 91 | MessageContextMenuStop | 空正文不提供重新发送 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `resendHiddenForEmptyContent` |
| 92 | MessageContextMenuStop | 缺少能力时不提供重新发送 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resendHiddenWithoutCapability` |
| 93 | MessageHeaderVisibility | V2 / V3 / V4 / V5 显示消息头 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `richModesShowHeader` |
| 94 | MessageHeaderVisibility | V1 与 V6 不显示消息头 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `briefAndStandardNoHeaderHideHeader` |
| 95 | MessageHeaderVisibility | 调用方显式关闭时任何级别都不显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitFalseWins` |
| 96 | MessageRendererPlugin | V1 assistant 内容使用 V2 布局，仅隐藏 Header | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantContentVerbosity` |
| 97 | MessageRendererPlugin | V1 模式下 ask_user 等挂起交互不走自定义工具渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v1DoesNotUseCustomToolRenderers` |
| 98 | MessageRendererPlugin | 工具调用参数保留真实 JSON 与历史异常内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsToolCallArguments` |
| 99 | MessageRendererPlugin | 已有最终结果的旧 pending 工具调用不重复显示授权 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `completedPendingToolCallDoesNotRenderApproval` |
| 100 | MessageRendererPlugin | 用户授权后不显示授权界面 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userApprovedToolCallDoesNotRenderApproval` |
| 101 | MessageRendererPlugin | 用户拒绝后不显示授权界面 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `userRejectedToolCallDoesNotRenderApproval` |
| 102 | MessageRendererPlugin | V1 风险审批只显示在当前 brief 会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskApprovalVisibility` |
| 103 | MessageRendererPlugin | 审批事件创建 pending 状态，授权完成后清除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskApprovalEventLifecycle` |
| 104 | MessageRendererPlugin | 13 个内置渲染器全部注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAllBuiltinRenderers` |
| 105 | MessageRendererPlugin | 按 role 分发到对应渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dispatchesByRole` |
| 106 | MessageRendererPlugin | turn-completed 与 tool-step-group 特殊渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dispatchesSpecialKinds` |
| 107 | MessageRendererPlugin | preferredRendererID 显式路由优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prefersExplicitRenderer` |
| 108 | MessageRendererPlugin | 兜底渲染器接管未匹配消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackRenderer` |
| 109 | MessageRendererPlugin | 渲染闭包返回可渲染视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderClosureProducesView` |
| 110 | MessageRendererPlugin | 插件注册并移除 V1 风险审批固定区 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersRiskApprovalChatItem` |
| 111 | ModelSwitchSummary | 同模型跨供应商时主行保留供应商（回归 #907） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameModelAcrossProvidersKeepsProviders` |
| 112 | ModelSwitchSummary | 同模型跨供应商时两端标签都带供应商 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `labelsPrefixProvidersOnlyWhenDisambiguating` |
| 113 | ModelSwitchSummary | 模型名不同时保持紧凑文案，不追加供应商 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `differentModelsStayCompact` |
| 114 | ModelSwitchSummary | 同供应商同名模型仍按模型名展示 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sameProviderKeepsModelOnlyLabels` |
| 115 | ModelSwitchSummary | 缺少任一供应商时不拼接半边供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingProviderDoesNotPrefix` |
| 116 | ModelSwitchSummary | 首次选择模型时只显示切换后的模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstSelectionHasNoSource` |
| 117 | ModelSwitchSummary | 只有供应商 ID 时退回显示供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerOnlyFallsBackToIDs` |
| 118 | ModelSwitchSummary | 摘要片段经过注入的本地化解析（回归 #905） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryUsesInjectedLocalization` |
| 119 | ModelSwitchSummary | 模型切换词条在所有规范语言下都有译文（回归 #905） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `switchLabelsHaveTranslationsInCompiledBundle` |
| 120 | RetryTurnButton | 失败回合仍在当前回合上时可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryableWhenTurnMatches` |
| 121 | RetryTurnButton | 回合已被新回合取代后不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `notRetryableAfterTurnSuperseded` |
| 122 | RetryTurnButton | 消息缺少 turnID 时不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `notRetryableWithoutTurnID` |
| 123 | RetryTurnButton | 没有 capability 时不可重试（插件未装配 AgentLoop） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `notRetryableWithoutCapability` |
| 124 | RetryTurnButton | 重试请求携带触发消息的回合 ID 与会话 ID | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryRequestCarriesTurnAndConversation` |
| 125 | RetryTurnButton | 不可重试的消息不应发出任何重试请求 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `noRetryRequestWhenNotRetryable` |
| 126 | ToolApprovalAfterConversationSwitch | 用户已允许后切换对话再切回，授权卡片不再出现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvalCardDoesNotReappearAfterSwitchingBack` |
| 127 | ToolApprovalAfterConversationSwitch | 用户已拒绝后切换对话再切回，授权卡片不再出现 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `approvalCardDoesNotReappearAfterRejecting` |
| 128 | ToolApprovalAfterConversationSwitch | 缓存命中不得复活等待授权的占位结果 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cacheDoesNotResurrectAwaitingUserResponseResult` |
| 129 | ToolApprovalAfterConversationSwitch | 缓存仍可补齐消息里缺失的工具结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheStillFillsMissingResults` |
| 130 | ToolApprovalAfterConversationSwitch | 未处理的授权仍然显示授权卡片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingApprovalStillRendersCard` |
| 131 | ToolApprovalCancellation | Stop 后底部授权缓存立即失效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledTurnClearsPendingApproval` |
| 132 | ToolApprovalCancellation | 完成与失败同样清理待授权缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalEventsClearPendingApproval` |
| 133 | ToolApprovalCancellation | 迟到的旧回合终态不会误删新回合授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleTerminalEventKeepsNewerTurnApproval` |
| 134 | ToolApprovalCancellation | 停止的回合点击允许不会执行工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledTurnRefusesAllow` |
| 135 | ToolApprovalCancellation | 已结束或失败的回合同样拒绝执行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `terminalTurnsRefuseExecution` |
| 136 | ToolApprovalCancellation | 挂起指向其他工具时旧卡片不得执行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `mismatchedSuspensionRefusesExecution` |
| 137 | ToolApprovalCancellation | 挂起匹配时正常执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingSuspensionExecutes` |
| 138 | ToolApprovalCancellation | 应用重启后的 idle 回合仍允许授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idleTurnStillAllowsRestartApproval` |
| 139 | ToolApprovalCancellation | 未提供 AgentLoop 时保持旧行为 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAgentLoopKeepsLegacyBehavior` |
| 140 | ToolApprovalMisclaim | 挂起的 ask_user 不被通用授权卡片接管 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserSuspensionIsNotClaimedByApprovalRenderer` |
| 141 | ToolApprovalMisclaim | 被误接管时授权请求必然构造不出来 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `misclaimedToolCallCannotBuildRequest` |
| 142 | ToolApprovalMisclaim | 真正的工具授权请求仍然被接管 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `realPermissionRequestIsStillClaimed` |
| 143 | ToolApprovalMisclaim | 挂起加 pendingAuthorization 不足以判定为授权请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionAloneDoesNotImplyAuthorization` |
| 144 | ToolApprovalVisibilityAfterResolution | 等待授权时显示授权卡片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `showsApprovalWhilePending` |
| 145 | ToolApprovalVisibilityAfterResolution | 用户已允许后重新打开不再显示授权卡片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hidesApprovalAfterUserApproved` |
| 146 | ToolApprovalVisibilityAfterResolution | 用户已拒绝后重新打开不再显示授权卡片 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `hidesApprovalAfterUserRejected` |
| 147 | ToolApprovalVisibilityAfterResolution | 授权状态丢失的形态会重新显示授权卡片（症状定义） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stalePendingFormRedisplayApproval` |
| 148 | ToolCallGroupCollapsePolicy | 单个工具调用不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleCallIsNotCollapsed` |
| 149 | ToolCallGroupCollapsePolicy | 空组不折叠 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyGroupIsNotCollapsed` |
| 150 | ToolCallGroupCollapsePolicy | 多个已完成的工具调用折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleCompletedCallsAreCollapsed` |
| 151 | ToolCallGroupCollapsePolicy | 多个进行中的工具调用折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleRunningCallsAreCollapsed` |
| 152 | ToolCallGroupCollapsePolicy | V6（standardNoHeader）与 V2 一样折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `standardNoHeaderCollapsesLikeStandard` |
| 153 | ToolCallGroupCollapsePolicy | V3（detailed）保持逐条铺开，不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detailedIsNotCollapsed` |
| 154 | ToolCallGroupCollapsePolicy | V1（brief）保持逐条铺开，不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `briefIsNotCollapsed` |
| 155 | ToolCallGroupCollapsePolicy | brief 会被升格为 standard，折叠判定必须用原始级别 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `briefIsUpgradedToStandard` |
| 156 | ToolCallGroupCollapsePolicy | 等待授权的调用不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingAuthorizationIsNotCollapsed` |
| 157 | ToolCallGroupCollapsePolicy | 等待用户作答的调用不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `awaitingUserResponseIsNotCollapsed` |
| 158 | ToolCallGroupCollapsePolicy | 授权状态缺失且结果未出时按等待授权处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAuthorizationStateWithoutResultIsTreatedAsPending` |
| 159 | ToolCallGroupCollapsePolicy | 授权状态缺失但已有结果时不算挂起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAuthorizationStateWithResultIsNotPending` |
| 160 | ToolCallGroupCollapsePolicy | 用户已授权的调用不阻止折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvedCallDoesNotBlockCollapsing` |
| 161 | ToolCallGroupCollapsePolicy | 用户已拒绝的调用不阻止折叠 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectedCallDoesNotBlockCollapsing` |
| 162 | ToolCallGroupCollapsePolicy | 挂起检测只看组内是否有交互调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsAwaitingInteraction` |
| 163 | ToolCallRendererDispatchDecoding | 匹配用桥接不解码任何图片字节 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingBridgeDoesNotDecodeImages` |
| 164 | ToolCallRendererDispatchDecoding | 匹配用桥接保留了匹配所需的全部信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingBridgeKeepsMatchingInformation` |
| 165 | ToolCallRendererDispatchDecoding | 匹配用桥接与完整桥接在匹配维度上完全一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingBridgeMatchesFullBridgeOnMatchingDimensions` |
| 166 | ToolCallRendererDispatchDecoding | 匹配用桥接在授权状态缺失时回退为待授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingBridgeFallsBackToPendingAuthorization` |
| 167 | ToolCallRendererDispatchDecoding | 匹配用桥接在没有结果时也能构造 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingBridgeHandlesMissingResult` |
| 168 | ToolCallRendererDispatchDecoding | 完整桥接解码出的图片与原始字节一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullBridgeDecodesImagesCorrectly` |
| 169 | ToolCallRendererDispatchDecoding | 完整桥接保留全部图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullBridgeKeepsAllImages` |
| 170 | ToolCallRendererDispatchDecoding | 非法 base64 的图片被跳过而不是让整个结果失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidBase64ImageIsSkipped` |
| 171 | ToolCallRendererDispatchDecoding | 重复访问完整桥接不会重复解码 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedFullBridgeUsesCache` |
| 172 | ToolCallRendererDispatchDecoding | 完整桥接的重复访问产出完全相同的结果 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedFullBridgeProducesSameResult` |
| 173 | ToolJobSummary | 所有 Job 状态都有稳定的用户文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `mapsAllStatuses` |
| 174 | ToolJobSummary | 运行中的 Job 计算经过时间和进度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectsLiveJob` |
| 175 | ToolJobSummary | 终态 Job 不再标记为进行中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalJobIsNotStale` |
| 176 | ToolJobSummary | 停止中的 Job 仍算进行中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingJobIsStillInFlight` |
| 177 | ToolJobSummary | 步骤组摘要覆盖进行中、失败和完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summarizesJobGroup` |
| 178 | ZCodeAssistantMessageView | 正文是 14pt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bodyFontSizeIs14` |
| 179 | ZCodeAssistantMessageView | tracking 是 0.35 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trackingIs035` |
| 180 | ZCodeAssistantMessageView | 目标行高是 24.5 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `targetLineHeightIs245` |
| 181 | ZCodeAssistantMessageView | strong 字重是 500 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `strongWeightIs500` |
| 182 | ZCodeAssistantMessageView | lineSpacing 由实际 NSFont 行高换算，不等于 24.5 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineSpacingIsDerivedFromFontLineHeight` |
| 183 | ZCodeAssistantMessageView | 助手正文没有气泡、没有头像、没有名称 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantBodyHasNoChrome` |
| 184 | ZCodeAssistantMessageView | 正文占满内容列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bodyFillsContentColumn` |
| 185 | ZCodeAssistantMessageView | 流式正文没有 cursor、没有淡入、没有 pulse | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingBodyHasNoCursorOrPulse` |
| 186 | ZCodeAssistantMessageView | 操作栏只在轮尾助手正文且已完成且 hover 时显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actionBarVisibilityRules` |
| 187 | ZCodeAssistantMessageView | 复制文本为空时不显示复制 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyCopyTextHidesCopyButton` |
| 188 | ZCodeAssistantMessageView | 操作栏时间字号是 12 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `timeLabelFontSizeIs12` |
| 189 | ZCodeAssistantMessageView | 轮尾已完成且有内容时预留常驻占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `reservesSlotForCompletedTailWithContent` |
| 190 | ZCodeAssistantMessageView | 占位与 hover 无关：未 hover 也占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `slotReservationIsIndependentOfHover` |
| 191 | ZCodeAssistantMessageView | 非轮尾正文不预留操作栏占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonTailRowReservesNoSlot` |
| 192 | ZCodeAssistantMessageView | 运行中不预留操作栏占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `runningTurnReservesNoSlot` |
| 193 | ZCodeAssistantMessageView | 既无复制文本也无完成时间时不预留占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyTailReservesNoSlot` |
| 194 | ZCodeAssistantMessageView | context 为 nil 时不预留占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nilContextReservesNoSlot` |
| 195 | ZCodeAssistantMessageView | 操作栏占位高度是 32，淡入淡出 150ms | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `actionBarSlotMetrics` |
| 196 | ZCodeAssistantMessageView | context 为 nil 时 V1–V3 保持旧行为 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nilContextKeepsLegacyBehavior` |
| 197 | ZCodeAssistantMessageView | context 存在时按 context 字段决定操作栏 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextDrivesActionBar` |
| 198 | ZCodeAssistantMessageView | context 缺失时 completedAt 为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nilContextHasNoCompletedAt` |
| 199 | ZCodeAssistantMessageView | context 的完成时间被透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedAtIsForwarded` |
| 200 | ZCodeAssistantMessageView | V4 不会被升格为 standard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zcodeIsNotPromotedToStandard` |
| 201 | ZCodeChatMarkdownTheme | 旧 make(from:) 的每个字段逐值不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyMakeKeepsEveryField` |
| 202 | ZCodeChatMarkdownTheme | 旧 make(from:) 不带 V4 的几何覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyMakeDoesNotApplyZCodeGeometry` |
| 203 | ZCodeChatMarkdownTheme | makeZCode 继承 MarkdownTheme.zcode 的全部几何 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zcodeMakeInheritsZCodeGeometry` |
| 204 | ZCodeChatMarkdownTheme | makeZCode 叠加宿主文字颜色 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zcodeMakeAppliesHostColors` |
| 205 | ZCodeChatMarkdownTheme | 正文 lineSpacing 由 NSFont 实际行高换算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zcodeBodyLineSpacingDerivedFromFont` |
| 206 | ZCodeMessageTimeLabel | 非正时间戳不显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonPositiveTimestampIsHidden` |
| 207 | ZCodeMessageTimeLabel | 非有限时间戳不显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonFiniteTimestampIsHidden` |
| 208 | ZCodeMessageTimeLabel | 无效的 now 不显示 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidNowIsHidden` |
| 209 | ZCodeMessageTimeLabel | 今天显示本地 HH:mm | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `todayShowsTimeOnly` |
| 210 | ZCodeMessageTimeLabel | 昨天显示昨天前缀加 HH:mm | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `yesterdayShowsLocalizedPrefix` |
| 211 | ZCodeMessageTimeLabel | 今年其他日期显示月日加 HH:mm | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameYearShowsMonthDayAndTime` |
| 212 | ZCodeMessageTimeLabel | 非今年显示年月日加 HH:mm | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentYearShowsFullDate` |
| 213 | ZCodeMessageTimeLabel | 同一输入总是得到同一结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formattingIsDeterministic` |
| 214 | ZCodeMessageTimeLabel | 昨天前缀可本地化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `yesterdayPrefixIsLocalizable` |
| 215 | ZCodeReasoningSummary | 与全量分割实现语义一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchesReferenceImplementation` |
| 216 | ZCodeReasoningSummary | 空内容返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyContentReturnsNil` |
| 217 | ZCodeReasoningSummary | 取最后一个非空行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `picksLastNonEmptyLine` |
| 218 | ZCodeReasoningSummary | 首尾空白被去掉 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsSurroundingWhitespace` |
| 219 | ZCodeReasoningSummary | CRLF 行尾按两个分隔符处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `handlesCRLF` |
| 220 | ZCodeReasoningView | 空 streaming reasoning 不渲染 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyStreamingReasoningIsHidden` |
| 221 | ZCodeReasoningView | 空白的 streaming reasoning 也不渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `blankStreamingReasoningIsHidden` |
| 222 | ZCodeReasoningView | 有内容的 reasoning 渲染 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonEmptyReasoningIsRendered` |
| 223 | ZCodeReasoningView | streaming 与 complete 默认都收起 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bothPhasesDefaultCollapsed` |
| 224 | ZCodeReasoningView | 用户显式展开后完成自动 collapse 不得覆盖 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `explicitExpandSurvivesAutoCollapse` |
| 225 | ZCodeReasoningView | 用户显式收起后完成自动 collapse 保持收起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitCollapseSurvivesAutoCollapse` |
| 226 | ZCodeReasoningView | 用户从未操作过时完成自动 collapse 生效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `autoCollapseAppliesWhenUserNeverChose` |
| 227 | ZCodeReasoningView | 显式选择后自动 collapse 不再改变状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `autoCollapseIsNoopAfterExplicitChoice` |
| 228 | ZCodeReasoningView | streaming 收起时显示最后非空行摘要 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `streamingSummaryUsesLastNonEmptyLine` |
| 229 | ZCodeReasoningView | 摘要忽略尾部空白行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryIgnoresTrailingBlankLines` |
| 230 | ZCodeReasoningView | 全空白文本没有摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `blankTextHasNoSummary` |
| 231 | ZCodeReasoningView | 内容顶部间距是 12、最大高 240 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentGeometry` |
| 232 | ZCodeReasoningView | 左 margin 8、左 padding 14 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentInsets` |
| 233 | ZCodeReasoningView | Brain 图标是 16 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `brainIconIs16` |
| 234 | ZCodeReasoningView | 默认吸底，用户离底超过 2 后停止跟随 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `followThresholdIs2` |
| 235 | ZCodeReasoningView | 没有真实时长字段时不显示时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noDurationWithoutRealField` |
| 236 | ZCodeReasoningView | 有真实时长字段时显示时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationShownWhenRealFieldExists` |
| 237 | ZCodeReasoningView | 时长字段非正数时不显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonPositiveDurationIsHidden` |
| 238 | ZCodeReasoningView | reasoning 折叠状态键与 turn 折叠状态键不同 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateKeysAreDistinct` |
| 239 | ZCodeReasoningView | 同一 turn 不同 reasoning 行的状态键不同 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateKeysDifferPerRow` |
| 240 | ZCodeReasoningView | 状态键是确定性的 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateKeysAreDeterministic` |
| 241 | ZCodeTimelineMarker | 空正文且无元数据的事件不渲染 marker | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyEventIsHidden` |
| 242 | ZCodeTimelineMarker | 有正文的事件渲染 marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `eventWithContentIsRendered` |
| 243 | ZCodeTimelineMarker | turn-completed 是 timeline marker 而不是气泡 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnCompletedIsMarkerNotBubble` |
| 244 | ZCodeTimelineMarker | timeline marker 没有头像与旧 chrome | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `markerHasNoAvatarOrLegacyChrome` |
| 245 | ZCodeTimelineMarker | timeline marker 是紧凑行，不占用大间距 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `markerIsCompact` |
| 246 | ZCodeTimelineMarker | 没有真实模型字段时不显示模型名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelSwitchWithoutModelFieldHidesModelName` |
| 247 | ZCodeTimelineMarker | 有真实模型字段时显示模型名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelSwitchWithModelFieldShowsModelName` |
| 248 | ZCodeTimelineMarker | 没有真实 goal 信息时不伪造进度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `goalWithoutInfoDoesNotFakeProgress` |
| 249 | ZCodeTimelineMarker | 有真实 goal 字段时显示 goal 标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `goalWithInfoShowsTitles` |
| 250 | ZCodeTimelineMarker | 没有真实重试原因时不显示重试原因 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryWithoutReasonHidesReason` |
| 251 | ZCodeTimelineMarker | 有真实重试原因时显示 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryWithReasonShowsReason` |
| 252 | ZCodeTimelineMarker | 错误 marker 不冒充工具错误样式 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorMarkerIsNotToolErrorStyle` |
| 253 | ZCodeTimelineMarker | 错误内容非空时渲染 marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorWithContentIsRendered` |
| 254 | ZCodeTimelineMarker | preferredRendererID 仍然优先于核心 renderer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preferredRendererIDStillWins` |
| 255 | ZCodeTimelineMarker | 没有 preferredRendererID 时为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nilPreferredRendererID` |
| 256 | ZCodeToolWorkHistoryView | 单个工具不形成父分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleToolIsNotGrouped` |
| 257 | ZCodeToolWorkHistoryView | 空工具不形成父分组 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyToolsAreNotGrouped` |
| 258 | ZCodeToolWorkHistoryView | 两个以上连续 Explore/Execute 形成父分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `consecutiveExploreExecuteAreGrouped` |
| 259 | ZCodeToolWorkHistoryView | 单个 Explore 不形成父分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleExploreIsNotGrouped` |
| 260 | ZCodeToolWorkHistoryView | 跨正文的工具不合并 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolsAcrossBodiesAreNotMerged` |
| 261 | ZCodeToolWorkHistoryView | Changes 类工具不参与 Explore/Execute 分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `changesToolsAreNotGrouped` |
| 262 | ZCodeToolWorkHistoryView | 未知工具名不参与分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownToolNamesAreNotGrouped` |
| 263 | ZCodeToolWorkHistoryView | 嵌套容器左 margin 8、左 padding 14、子项间距 8 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedContainerGeometry` |
| 264 | ZCodeToolWorkHistoryView | 摘要字号 14、图标 16 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `summaryTypography` |
| 265 | ZCodeToolWorkHistoryView | 展开内容与摘要间距 8 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expandedContentSpacing` |
| 266 | ZCodeToolWorkHistoryView | 收起后 300ms 卸载重内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapsedUnloadsAfter300ms` |
| 267 | ZCodeToolWorkHistoryView | 收起后重内容立即卸载 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapsedUnloadsImmediately` |
| 268 | ZCodeToolWorkHistoryView | Execute 输出最多 5 行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeOutputMaxLinesIs5` |
| 269 | ZCodeToolWorkHistoryView | Execute 输出离底超过 8 后停止跟随 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeOutputFollowThresholdIs8` |
| 270 | ZCodeToolWorkHistoryView | Execute 输出是 mono 14/20 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeOutputTypography` |
| 271 | ZCodeToolWorkHistoryView | Read 不展开结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readDoesNotExpandResults` |
| 272 | ZCodeToolWorkHistoryView | Edit 可展开 inline diff | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editExpandsInlineDiff` |
| 273 | ZCodeToolWorkHistoryView | 通用工具预览最大高 240 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `genericPreviewMaxHeightIs240` |
| 274 | ZCodeToolWorkHistoryView | Edit 的 inline diff 最大高 240 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editDiffMaxHeightIs240` |
| 275 | ZCodeToolWorkHistoryView | Explore/Execute/Terminal 归入可分组家族 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `groupableFamilyMapping` |
| 276 | ZCodeToolWorkHistoryView | Read/Write/Edit 不归入可分组家族 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonGroupableFamilyMapping` |
| 277 | ZCodeToolWorkHistoryView | 工具名归一化忽略大小写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `familyMappingIsCaseInsensitive` |
| 278 | ZCodeToolWorkHistoryView | 展开命令带 $ 前缀且用 mono | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expandedCommandIsMonospacedWithDollarPrefix` |
| 279 | ZCodeToolWorkHistoryView | 摘要命令不使用 $ 前缀 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryCommandHasNoDollarPrefix` |
| 280 | ZCodeUserBubbleCollapseState | 默认收起 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultCollapsed` |
| 281 | ZCodeUserBubbleCollapseState | 显式展开后是展开 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitExpand` |
| 282 | ZCodeUserBubbleCollapseState | 显式收起后是收起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitCollapse` |
| 283 | ZCodeUserBubbleCollapseState | 首次观察只记录身份，不改变展开状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstObservationDoesNotReset` |
| 284 | ZCodeUserBubbleCollapseState | 身份变化后重置为收起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `identityChangeResets` |
| 285 | ZCodeUserBubbleCollapseState | 行 id 变化后重置为收起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rowIDChangeResets` |
| 286 | ZCodeUserBubbleCollapseState | 展开与收起的文案不同，供辅助功能朗读 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `expandedAndCollapsedLabelsDiffer` |
| 287 | ZCodeUserBubbleCollapseState | 身份不变时保持展开 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameIdentityKeepsExpanded` |
| 288 | ZCodeUserMessageView | 圆角是四角 12、右上角 2 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cornerRadiiMatchZCode` |
| 289 | ZCodeUserMessageView | 内边距是水平 16、垂直 12 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paddingMatchesZCode` |
| 290 | ZCodeUserMessageView | 内部间距是 8 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `innerSpacingIs8` |
| 291 | ZCodeUserMessageView | 正文是 14pt、行高 24 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bodyTypographyMatchesZCode` |
| 292 | ZCodeUserMessageView | 气泡宽度阈值在 624 处切换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bubbleWidthThreshold` |
| 293 | ZCodeUserMessageView | 气泡宽度不会超过内容列宽 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bubbleNeverExceedsContentColumn` |
| 294 | ZCodeUserMessageView | 长文可见高度是 120 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visibleHeightIs120` |
| 295 | ZCodeUserMessageView | overflow tolerance 为 1：120/121 不折叠，122 折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapseThresholdHasOnePixelTolerance` |
| 296 | ZCodeUserMessageView | 非有限高度不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonFiniteHeightDoesNotCollapse` |
| 297 | ZCodeUserMessageView | 折叠状态在内容或行身份变化后重置为收起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapseStateResetsOnIdentityChange` |
| 298 | ZCodeUserMessageView | 内容与行身份都不变时保持折叠状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapseStateKeepsWhenIdentityUnchanged` |
| 299 | ZCodeUserMessageView | 复制使用原始正文而不是裁剪后的内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyUsesRawContent` |
| 300 | ZCodeUserMessageView | 复制按钮尺寸 24×24、图标 14 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `copyButtonMetrics` |
| 301 | ZCodeUserMessageView | 复制成功反馈在 1200ms 后恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyFeedbackDurationIs1200ms` |
| 302 | ZCodeUserMessageView | 复制状态机在 1200ms 后回到未复制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyStateResetsAfterFeedbackDuration` |
| 303 | ZCodeUserMessageView | 复制状态在再次标记后重新计时 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyStateRestartsOnRepeatedCopy` |
| 304 | ZCodeUserMessageView | 空正文且无附件时不绘制气泡 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noBubbleWithoutContentOrAttachments` |
| 305 | ZCodeUserMessageView | 只有附件时也不绘制气泡 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noBubbleForAttachmentOnly` |
| 306 | ZCodeUserMessageView | 有正文时绘制气泡 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bubbleForTextContent` |
| 307 | ZCodeUserMessageView | 媒体缩略图是 80×80、圆角 12 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mediaThumbnailMetrics` |
| 308 | ZCodeUserMessageView | 非媒体文件 pill 是水平 12、垂直 6、全圆角 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filePillMetrics` |
| 309 | ZCodeUserMessageView | 附件列最大宽度是 576、底间距 8 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attachmentColumnMetrics` |
| 310 | ZCodeUserMessageView | 展开收起动画是 300ms ease-out | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapseAnimationDuration` |
| 311 | ZCodeUserMessageView | reduceMotion 下没有动画 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reducedMotionDisablesAnimation` |

> 说明：全部 **311 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 39 / 39
- P1: 已覆盖 232 / 232
- P2: 已覆盖 40 / 40
- **合计: 311 / 311**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（39 条）
- **P1**: 其余功能性用例（232 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（40 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 311 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMessageRenderer
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
