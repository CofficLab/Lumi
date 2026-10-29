# TestPlan — PluginMessageListStandard

## 包概述

PluginMessageListStandard Lumi 消息列表 **V2（标准）** 实现包。工具栏 **Response Detail** 处于 `V2 (标准)` 时， 聊天区由本包接管；`V1` / `V3` 分别由 `PluginMessageListBrief` / `PluginMessageListDetailed` 接管。

平台: macOS 14+, iOS 17+
测试文件: 16 个，用例总数: 107

核心组件（源码目录）:
- `Capabilities/`
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MessageListStandardUITestingSupport`
- `PluginMessageListStandardPlugin`
- `VerbosityObservationBox`
- `MessageListAgentLoopCapability`
- `MessageListChatSectionCapability`
- `MessageListConversationCapability`
- `MessageListConversationStateCapability`
- `MessageListMessageCapability`
- `MessageListProjectCapability`
- `MessageListPromptSuggestionCapability`
- `MessageListPromptSuggestionExecutorCapability`
- `MessageListRenderingCapability`
- `MessageListStreamingCapability`
- `MessageListToolManagerCapability`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **BottomDecision**（8 条）：由 `bottomDecisionTrueAtExactBottom`、`bottomDecisionFalseFarFromBottom`、`bottomDecisionUsesHysteresisBand` 等用例锁定；改动该模块时优先跑对应测试文件。
- **InitialPositionGateBudget**（1 条）：由 `gateBudgetIsAbsoluteNotAdditiveUnderMainActorContention` 等用例锁定；改动该模块时优先跑对应测试文件。
- **InitialPositionGate**（10 条）：由 `gateBecomesReadyAfterSuccessfulSettle`、`gateReleasesEvenWhenSettleFails`、`gateReleasesWhenSettleHangs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **InitialPositionGateTiming**（5 条）：由 `gateReleasesImmediatelyWhenSettleSucceeds`、`gateReleasesImmediatelyWhenSettleFails`、`gateTreatsSuccessAndFailureIdentically` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV2AuthorizationAfterSwitch**（3 条）：由 `approvedToolCallKeepsTerminalStateAfterSwitchingBack`、`rejectedToolCallKeepsTerminalStateAfterSwitchingBack`、`authorizationStateChangeAloneTriggersRebuild` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV2LargeData**（6 条）：由 `tailEvictionDoesNotCreatePermanentGap`、`sameLengthContentEditRebuildsRows`、`windowStaysBoundedWhilePaging` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV2ViewModel**（24 条）：由 `activationLoadsFirstPage`、`activationWithoutConversationClearsState`、`activationResetsPreviousConversationState` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListBottomSettle**（3 条）：由 `bottomSettleStopsOnceGeometrySettles`、`bottomSettleToleratesSubPixelJitter`、`bottomSettleAbortsWhenGeometryUnavailable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListService**（10 条）：由 `messageRowsFilterAndMergeToolExecutionMessages`、`messageRowsPreserveUnscopedMessagesAndLegacyGroups`、`messageDerivedPredicatesDistinguishEmptyResponses` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListServices**（6 条）：由 `activityMessageCoversSimpleStates`、`activityMessageUsesJobDescription`、`activityMessageFallsBackWithoutRunningJob` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListStandardUITestingSupport**（6 条）：由 `fixtureSeedsBothConversations`、`fixtureSeedsMessagesForBothConversations`、`fixtureHugeConversationExceedsWindowLimit` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListStateLifetime**（6 条）：由 `listViewMustNotHoldReferenceStateInPlainStoredProperty`、`listViewMustCarryRuntimeInStateObject`、`runtimeMembersKeepStableIdentity` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListTurnActivity**（8 条）：由 `turnActivitySortsToolCallsStably`、`turnActivitySummarisesRecords`、`turnActivityHandlesEmptyAndUnfinished` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ScrollViewBottomController**（7 条）：由 `pinToBottomMovesOffsetToDocumentEnd`、`pinToBottomClampsOffsetWhenDocumentShorterThanViewport`、`controllerWithoutScrollViewIsNotAttached` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StuckLoadingMask**（4 条）：由 `gateReleasesMaskWithinBudgetWithoutAnySettleRound`、`gateReleasesMaskWithinBudgetAfterConversationSwitch`、`gateAcceptsNewRoundForSameConversationAfterStaleRound` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | BottomDecision | 底部判定：offset 落在底边时为真 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomDecisionTrueAtExactBottom` |
| 2 | BottomDecision | 底部判定：远离底部时为假 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomDecisionFalseFarFromBottom` |
| 3 | BottomDecision | 底部判定迟滞：留在底部时容忍更大距离，离开底部时要求更接近 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomDecisionUsesHysteresisBand` |
| 4 | BottomDecision | 底部判定：文档远短于视口时视口顶部即底部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomDecisionShortDocumentIsAtBottom` |
| 5 | BottomDecision | 底部判定：距离恰在进入阈值边界上判为真 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomDecisionEnterBoundaryIsInclusive` |
| 6 | BottomDecision | 底部判定：距离恰在离开阈值边界上判为真 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomDecisionLeaveBoundaryIsInclusive` |
| 7 | BottomDecision | 底部判定：视口高度为 0 或几何异常时放弃判定 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomDecisionIgnoresInvalidGeometry` |
| 8 | BottomDecision | 底部判定：距离为负（内容短于视口且已滚过头）仍视为在底部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomDecisionHandlesNegativeDistance` |
| 9 | InitialPositionGateBudget | 首屏遮罩：兜底预算是绝对期限，主线程被占用时不得再叠加一个完整预算 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateBudgetIsAbsoluteNotAdditiveUnderMainActorContention` |
| 10 | InitialPositionGate | 首屏就绪：收敛成功后放行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateBecomesReadyAfterSuccessfulSettle` |
| 11 | InitialPositionGate | 首屏就绪：收敛失败也在预算内放行，绝不永久卡死 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateReleasesEvenWhenSettleFails` |
| 12 | InitialPositionGate | 首屏就绪：收敛挂死时由超时兜底放行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesWhenSettleHangs` |
| 13 | InitialPositionGate | 首屏就绪：同一会话重复请求被去重 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateDeduplicatesSameConversation` |
| 14 | InitialPositionGate | 首屏就绪：切换会话作废上一轮等待，不被旧结果污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateDiscardsPreviousConversationOnSwitch` |
| 15 | InitialPositionGate | 首屏就绪：会话切换复位后不再就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateResetClearsReady` |
| 16 | InitialPositionGate | 首屏就绪：相关性失效时不置为就绪 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateIgnoresResultWhenNoLongerRelevant` |
| 17 | InitialPositionGate | 首屏就绪：没有选中会话时直接就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateWithoutConversationIsImmediatelyReady` |
| 18 | InitialPositionGate | 首屏遮罩：会话切换的复位不得作废已在当前会话上启动的收敛 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotCancelConvergenceAlreadyStarted` |
| 19 | InitialPositionGate | 首屏遮罩：复位不得让已失效的旧一轮放行遮罩 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotReleaseMaskFromStaleRound` |
| 20 | InitialPositionGateTiming | 首屏遮罩：收敛成功时立即放行，不等满预算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateReleasesImmediatelyWhenSettleSucceeds` |
| 21 | InitialPositionGateTiming | 首屏遮罩：收敛失败时立即放行，不等满预算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateReleasesImmediatelyWhenSettleFails` |
| 22 | InitialPositionGateTiming | 首屏遮罩：成功与失败路径的放行耗时同量级（收敛结果未生效） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateTreatsSuccessAndFailureIdentically` |
| 23 | InitialPositionGateTiming | 首屏遮罩：收敛挂死时预算兜底仍在有限时间内放行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateStillReleasesWhenSettleHangs` |
| 24 | InitialPositionGateTiming | 首屏遮罩：旧轮次醒来不清掉新轮次的准备状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleRoundDoesNotClearNewRoundPreparing` |
| 25 | ListV2AuthorizationAfterSwitch | 已允许的工具调用在切走再切回后仍是授权终态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvedToolCallKeepsTerminalStateAfterSwitchingBack` |
| 26 | ListV2AuthorizationAfterSwitch | 已拒绝的工具调用在切走再切回后仍是授权终态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectedToolCallKeepsTerminalStateAfterSwitchingBack` |
| 27 | ListV2AuthorizationAfterSwitch | 授权状态变化本身就会触发历史行重建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationStateChangeAloneTriggersRebuild` |
| 28 | ListV2LargeData | 翻页裁剪窗口后，新消息到达不得让中间段消息永久消失 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailEvictionDoesNotCreatePermanentGap` |
| 29 | ListV2LargeData | 内容被等长替换时历史行必须更新 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `sameLengthContentEditRebuildsRows` |
| 30 | ListV2LargeData | 持续翻页时内存窗口不得无上限增长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `windowStaysBoundedWhilePaging` |
| 31 | ListV2LargeData | 工具调用统计不应随窗口内 turn 数线性放大 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallQueriesDoNotScaleWithTurnCount` |
| 32 | ListV2LargeData | 大窗口下重建历史行的耗时应保持有界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebuildHistoryRowsStaysFastAtScale` |
| 33 | ListV2LargeData | 单个 turn 的大量工具消息合并后仍只产生一行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolOnlyMessagesMergeIntoSingleRow` |
| 34 | ListV2ViewModel | 激活当前会话后加载最近一页并退出 loading | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationLoadsFirstPage` |
| 35 | ListV2ViewModel | 没有选中会话时清空窗口且不进入 loading | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationWithoutConversationClearsState` |
| 36 | ListV2ViewModel | 切换会话时旧会话消息被清空，不残留上一会话内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationResetsPreviousConversationState` |
| 37 | ListV2ViewModel | 切换到非当前会话的激活请求被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationIgnoresStaleConversation` |
| 38 | ListV2ViewModel | 向上翻页把更早一页前插，并保留已有更早标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierPrependsPage` |
| 39 | ListV2ViewModel | 空窗口或无更早消息时向上翻页不产生锚点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierNoOpWithoutWindow` |
| 40 | ListV2ViewModel | 向上翻页在窗口未超上限时原样前插 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierPrependsPageWhenWithinWindowLimit` |
| 41 | ListV2ViewModel | 尾部刷新在内容变化时替换窗口并返回 true | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tailRefreshUpdatesWindow` |
| 42 | ListV2ViewModel | 尾部刷新在内容未变化时返回 false 且不重复发布 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailRefreshSkipsIdenticalSnapshot` |
| 43 | ListV2ViewModel | 尾部刷新在没有选中会话时直接返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tailRefreshWithoutConversation` |
| 44 | ListV2ViewModel | 生成阶段暴露流式行，闲置阶段隐藏流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowFollowsStage` |
| 45 | ListV2ViewModel | 非当前会话的流式事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingChangeForOtherConversationIgnored` |
| 46 | ListV2ViewModel | 插入消息直接进入窗口，用户消息记录为最近一条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedMessageLandsInWindow` |
| 47 | ListV2ViewModel | 插入同 id 消息为原地替换，不产生重复行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `insertedMessageWithSameIDReplaces` |
| 48 | ListV2ViewModel | 插入工具结果消息不进入展示窗口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedToolMessageIsIgnored` |
| 49 | ListV2ViewModel | 其他会话的插入事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedMessageForOtherConversationIgnored` |
| 50 | ListV2ViewModel | 持久化与更新事件触发尾部刷新，删除事件触发刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistenceEventsTriggerTailRefresh` |
| 51 | ListV2ViewModel | 其他会话的持久化事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistenceEventForOtherConversationIgnored` |
| 52 | ListV2ViewModel | 按窗口内 turn 汇总工具调用统计 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySummariesAggregateRecords` |
| 53 | ListV2ViewModel | 窗口内无 turn 时不发起工具查询 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySkipsWhenNoTurns` |
| 54 | ListV2ViewModel | turnActivity 在缺少工具能力时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivityWithoutToolManagerIsNil` |
| 55 | ListV2ViewModel | 渲染器与详细程度经由能力透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `accessorsDelegateToCapabilities` |
| 56 | ListV2ViewModel | 会话详细程度变化后重建历史行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationSettingsChangeRebuildsRows` |
| 57 | ListV2ViewModel | 会话状态变化会刷新活动消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateChangeRefreshesActivity` |
| 58 | MessageListBottomSettle | 底部收敛：几何逐帧增长时应在稳定后退出，而不是耗尽全部重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomSettleStopsOnceGeometrySettles` |
| 59 | MessageListBottomSettle | 底部收敛：微小的亚像素抖动不应导致重置稳定计数 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bottomSettleToleratesSubPixelJitter` |
| 60 | MessageListBottomSettle | 底部收敛：未绑定滚动视图时应立即放弃，而不是空转 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomSettleAbortsWhenGeometryUnavailable` |
| 61 | MessageListService | 消息行过滤工具结果，并把空正文工具调用合并为 turn activity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsFilterAndMergeToolExecutionMessages` |
| 62 | MessageListService | 没有选中会话时保留原始行，且历史工具组使用兼容 render kind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsPreserveUnscopedMessagesAndLegacyGroups` |
| 63 | MessageListService | 空响应判断排除错误和工具调用消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageDerivedPredicatesDistinguishEmptyResponses` |
| 64 | MessageListService | 首屏取最近 pageSize 条并探测是否存在更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsLatestPageAndDetectsEarlierMessages` |
| 65 | MessageListService | 向上翻页保留锚点，并重新检查是否还有更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsEarlierPageAroundAnchor` |
| 66 | MessageListService | 尾部刷新覆盖重叠窗口，避免无重叠时打断历史浏览 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationRefreshesOnlyAnOverlappingTail` |
| 67 | MessageListService | 尾部刷新回填空档后，窗口必须保持时间升序且无重复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `paginationBackfillsGapKeepingWindowOrdered` |
| 68 | MessageListService | 空窗口首刷补查 earlier，窗口超上限时一律回收尾部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationInitialRefreshAndTailEviction` |
| 69 | MessageListService | 尾部刷新门将并发通知合并成当前轮和至多一轮尾随刷新 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailRefreshGateCoalescesOverlappingRequests` |
| 70 | MessageListService | 通知按当前会话筛选，消息时间相同时按 UUID 稳定排序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageNotificationAndOrderingAreStable` |
| 71 | MessageListServices | 活动消息：sending / thinking / waitingForUser 各映射到对应文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activityMessageCoversSimpleStates` |
| 72 | MessageListServices | 活动消息：executingTool 有运行中任务时带上任务描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageUsesJobDescription` |
| 73 | MessageListServices | 活动消息：executingTool 无运行中任务时退回通用文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activityMessageFallsBackWithoutRunningJob` |
| 74 | MessageListServices | 活动消息：无活动或缺少会话/状态能力时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageReturnsNilWhenUnavailable` |
| 75 | MessageListServices | 服务容器：选中会话与详细程度经由会话能力透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `servicesProxyConversationCapability` |
| 76 | MessageListServices | 服务容器：缺少会话能力时详细程度回落到默认值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `servicesFallsBackWhenConversationCapabilityMissing` |
| 77 | MessageListStandardUITestingSupport | 夹具：seed 后五个会话都存在，且都带消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureSeedsBothConversations` |
| 78 | MessageListStandardUITestingSupport | 夹具：五个会话都写入了消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureSeedsMessagesForBothConversations` |
| 79 | MessageListStandardUITestingSupport | 夹具：超大会话消息数远超窗口上限 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fixtureHugeConversationExceedsWindowLimit` |
| 80 | MessageListStandardUITestingSupport | 夹具：大会话消息数显著多于小会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureLargeConversationIsHarder` |
| 81 | MessageListStandardUITestingSupport | 夹具：默认选中大会话且为 standard 详细程度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureSelectsLargeConversation` |
| 82 | MessageListStandardUITestingSupport | 夹具：重复 seed 不产生重复会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fixtureSeedIsIdempotent` |
| 83 | MessageListStateLifetime | 消息列表视图：不得用普通存储属性持有引用类型状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustNotHoldReferenceStateInPlainStoredProperty` |
| 84 | MessageListStateLifetime | 消息列表视图：运行时状态容器必须由 StateObject 承载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustCarryRuntimeInStateObject` |
| 85 | MessageListStateLifetime | 运行时容器：成员在多次访问之间必须保持同一实例 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeMembersKeepStableIdentity` |
| 86 | MessageListStateLifetime | 运行时容器：必须持有底部标记、滚动协调器与底部几何控制器 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeCarriesAllThreeMembers` |
| 87 | MessageListStateLifetime | 运行时容器：不得发布任何 @Published（避免重新打开 invalidation 反馈环） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimePublishesNothing` |
| 88 | MessageListStateLifetime | 底部 tracker：控制器换实例后必须重新绑定滚动视图 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `trackerRebindsReplacedController` |
| 89 | MessageListTurnActivity | Turn 活动按开始时间升序排序，时间相同按 id 稳定排序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `turnActivitySortsToolCallsStably` |
| 90 | MessageListTurnActivity | Turn 活动统计总数、完成数、失败数与总时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySummarisesRecords` |
| 91 | MessageListTurnActivity | Turn 活动无完成记录时总时长为 nil，失败计数不重复计入完成数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `turnActivityHandlesEmptyAndUnfinished` |
| 92 | MessageListTurnActivity | isToolExecutionOnly 仅对空白或省略号正文且带工具调用的助手消息成立 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolExecutionOnlyPredicateIsNarrow` |
| 93 | MessageListTurnActivity | isEmptyResponse 排除错误消息与带工具调用的消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyResponsePredicateExcludesErrorAndTools` |
| 94 | MessageListTurnActivity | 开发者模式状态只传播真实变化，避免无效刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeStateOnlyPublishesRealChanges` |
| 95 | MessageListTurnActivity | 开发者模式观察器把外部初始值与变更事件写入共享状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeObserverBridgesProviderEvents` |
| 96 | MessageListTurnActivity | 开发者模式观察器在 provider 缺失时按未启用处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeObserverToleratesMissingProvider` |
| 97 | ScrollViewBottomController | 钉底后 contentOffset 落在 documentView 底边 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToBottomMovesOffsetToDocumentEnd` |
| 98 | ScrollViewBottomController | 文档高度小于视口时 offset 夹紧为 0，不产生负偏移 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToBottomClampsOffsetWhenDocumentShorterThanViewport` |
| 99 | ScrollViewBottomController | 未绑定滚动视图时 isAttached 为 false 且钉底返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `controllerWithoutScrollViewIsNotAttached` |
| 100 | ScrollViewBottomController | 脱离绑定后 isAttached 回到 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detachClearsAttachment` |
| 101 | ScrollViewBottomController | 视口高度为 0 时拒绝返回几何快照 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pinToBottomRejectsZeroViewport` |
| 102 | ScrollViewBottomController | 文档高度持续增长时，收敛循环可在高度稳定后退出 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `settleConvergesAfterDocumentHeightStabilizes` |
| 103 | ScrollViewBottomController | 非有限或异常尺寸的文档不会被钉底 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pinToBottomRejectsInvalidGeometry` |
| 104 | StuckLoadingMask | 首屏遮罩：加载开始后即使没有收敛轮次，遮罩也必须在预算内落下 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesMaskWithinBudgetWithoutAnySettleRound` |
| 105 | StuckLoadingMask | 首屏遮罩：会话切换复位后即使没有收敛轮次，遮罩也必须在预算内落下 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesMaskWithinBudgetAfterConversationSwitch` |
| 106 | StuckLoadingMask | 首屏遮罩：失效的一轮结束后，同一会话必须能重新开始一轮 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateAcceptsNewRoundForSameConversationAfterStaleRound` |
| 107 | StuckLoadingMask | 首屏遮罩：失效的一轮不得放行遮罩，但必须允许后续轮次接手 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateStaleRoundMustNotReleaseMaskButMustHandOver` |

> 说明：全部 **107 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 31 / 31
- P1: 已覆盖 67 / 67
- P2: 已覆盖 9 / 9
- **合计: 107 / 107**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（31 条）
- **P1**: 其余功能性用例（67 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（9 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 107 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMessageListStandard
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
