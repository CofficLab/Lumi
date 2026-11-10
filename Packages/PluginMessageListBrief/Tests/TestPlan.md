# TestPlan — PluginMessageListBrief

## 包概述

PluginMessageListBrief — Message List V1 (Brief) Manual + automated test reference for the V1 message list. V1 groups a conversation by **Agent Turn** and keeps everything else out of the way. Each turn shows the user message that triggered it, a collapsible process section, and the final reply. Live progress is reported by a single status card pinned to the bottom of the list, not inside the turns.

平台: macOS 14+, iOS 17+
测试文件: 27 个，用例总数: 165

核心组件（源码目录）:
- `Capabilities/`
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MessageListBriefUITestingSupport`
- `PluginMessageListBriefPlugin`
- `MessageListAgentLoopCapability`
- `MessageListConversationCapability`
- `MessageListDeveloperModeCapability`
- `MessageListMessageCapability`
- `MessageListRenderingCapability`
- `AgentActivityPhase`
- `AgentTurnRecord`
- `AgentTurnSummaryItem`
- `ListV1Presentation`
- `MessageListServices`
- `ProcessSectionAnchor`
- `ProcessSectionExpansionState`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ActivityLocalization**（5 条）：由 `activityTitlesUseInjectedLocalization`、`toolActivityUsesInjectedLocalization`、`disclosureTitleUsesInjectedLocalization` 等用例锁定；活动行与过程摘要必须经本地化解析，词条需覆盖 5 种语言（#893）。
- **AgentActivityProjection**（13 条）：由 `thinking`、`generating`、`executingTool` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentTurnProjection**（9 条）：由 `finishedTurnLayout`、`twoUserMessagesRemainSeparateTurns`、`toolAndSystemRowsAreHidden` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentTurnVM**（3 条）：由 `agentTurnVMPublishesProjectionChanges`、`activeToolCallStaysInsideProcessDisclosure`、`pendingAndRecordedTurnKeepStableListIdentity` 等用例锁定；改动该模块时优先跑对应测试文件。
- **BottomStickyPin**（5 条）：由 `bottomStaysPinnedWhenDocumentGrowsAfterSettle`、`bottomStaysPinnedAcrossConsecutiveGrowths`、`bottomStateStaysTrueAfterDocumentGrowth` 等用例锁定；改动该模块时优先跑对应测试文件。
- **BoundedProcessSectionRender**（2 条）：由 `overflowingContentIsCapped`、`shortContentUsesContentHeight` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStateLineRender**（2 条）：由 `cardHeightFitsSingleLine`、`cardHeightStableWithoutDetail` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStateVM**（1 条）：由 `conversationStateVMAcceptsOnlySelectedConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **InitialPositionGate**（10 条）：由 `gateBecomesReadyAfterSuccessfulSettle`、`gateReleasesEvenWhenSettleFails`、`gateReleasesWhenSettleHangs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListPresentation**（14 条）：由 `loadingStateDuringActivate`、`activateRequiresSelectedConversation`、`loadEarlierHiddenWhenPageFits` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV1LargeData**（3 条）：由 `windowStaysBoundedWhilePaging`、`evictionKeepsNewestTurnMessages`、`refreshBackfillsTheEvictedGap` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListSendPositioning**（7 条）：由 `conservativeReserveIsStable`、`cancelBeforeFirstAssistantEndsPostSendPositioning`、`liveTurnEndingEndsPostSendPositioning` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListServices**（11 条）：由 `tailGateCollapsesBursts`、`overlappingRunnersReturnFalse`、`loadFirstPageProbesEarlier` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListStateLifetime**（6 条）：由 `listViewMustNotHoldReferenceStateInPlainStoredProperty`、`listViewMustCarryRuntimeInStateObject`、`listViewMustCarryInitialPositionGate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Observer**（18 条）：由 `messageObserverForwardsChanges`、`messageObserverIgnoresOtherConversations`、`messageObserverCancelStopsDelivery` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionAutoExpandRender**（3 条）：由 `activeTurnShowsProcessByDefault`、`historicalTurnHidesProcessByDefault`、`activeTurnIsTallerThanHistoricalTurn` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionAutoPinRender**（4 条）：由 `initialPositionIsAtBottom`、`contentGrowthPinsToBottom`、`userScrollBreaksAutoPin` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionExpansion**（9 条）：由 `activeTurnExpandsByDefault`、`historicalTurnCollapsesByDefault`、`userCollapseIsNotOverridden` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionFollowState**（8 条）：由 `followsByDefault`、`stopsFollowingAfterUserScrollsUp`、`resumesFollowingWhenUserReturnsToBottom` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionInnerScrollResponse**（2 条）：由 `innerRespondsToScrollWheel`、`innerIsNestedInsideOuterList` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionLayout**（9 条）：由 `maxHeightUsesViewportFraction`、`maxHeightFallsBackToMinimum`、`maxHeightHandlesInvalidViewport` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionMinHeight**（2 条）：由 `overflowingContentKeepsNonZeroViewport`、`shortContentStaysAdaptive` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionScrollDirection**（3 条）：由 `swiftUIInnerUsesOppositeDirection`、`relayDrivesInnerWithNativeDirection`、`scrollingUpFromBottomMovesInnerOffset` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProcessSectionScrollRelay**（10 条）：由 `forwardsWhenInnerReachesBottom`、`keepsScrollInsideInnerWhenNotAtBoundary`、`forwardsWhenInnerReachesTop` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StuckLoadingMask**（4 条）：由 `gateReleasesMaskWithinBudgetWithoutAnySettleRound`、`gateReleasesMaskWithinBudgetAfterConversationSwitch`、`gateAcceptsNewRoundForSameConversationAfterStaleRound` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentActivityProjection | 流式思考阶段映射为思考活动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `thinking` |
| 2 | AgentActivityProjection | 生成阶段映射为生成活动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generating` |
| 3 | AgentActivityProjection | 工具阶段展示具体工具描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executingTool` |
| 4 | AgentActivityProjection | 多个工具任务显示任务数量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleTools` |
| 5 | AgentActivityProjection | 等待用户阶段不暴露工具输出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `waitingForUser` |
| 6 | AgentActivityProjection | 回合运行中但 activity 短暂为空时保留状态视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runningWithoutActivity` |
| 7 | AgentActivityProjection | 回合暂停但 activity 短暂为空时保留等待状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedWithoutActivity` |
| 8 | AgentActivityProjection | 空闲阶段不显示活动视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idle` |
| 9 | AgentActivityProjection | 状态行在细节缺失时只显示标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `statusLineWithoutDetail` |
| 10 | AgentActivityProjection | 状态行在细节为空字符串时也不产生尾部分隔符 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `statusLineWithEmptyDetail` |
| 11 | AgentActivityProjection | 状态行把标题与细节合并到同一行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `statusLineMergesDetail` |
| 12 | AgentActivityProjection | 状态行恒为单行文本，不含换行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusLineIsSingleLine` |
| 13 | AgentActivityProjection | 每个活动阶段都能产出一行状态文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyStageProducesSingleLineStatusText` |
| 14 | AgentTurnProjection | finished turn 包含 user、process、last 三段且 user 恰好一条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finishedTurnLayout` |
| 15 | AgentTurnProjection | 同一时间线里两条 user 消息各属于一个 turn 不会合并 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `twoUserMessagesRemainSeparateTurns` |
| 16 | AgentTurnProjection | tool 与 system 不会进入 process / last 投影 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolAndSystemRowsAreHidden` |
| 17 | AgentTurnProjection | failed turn 仍然把 error 消息作为 last 渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedTurnSurfacesErrorAsLastMessage` |
| 18 | AgentTurnProjection | 流式回合进行中 lastMessage 为 nil，不出现 streaming reply block | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingTurnHasNoLastMessage` |
| 19 | AgentTurnProjection | 空回复（仅有占位符）回合不暴露 lastMessage | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyReplyTurnHidesLastMessage` |
| 20 | AgentTurnProjection | §3.2 完成回合的 disclosure 标题显示步骤数与耗时 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `finishedDisclosureTitleShowsStepsAndDuration` |
| 21 | AgentTurnProjection | §3.3 没有工具调用时步骤数回退到 process 消息数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `disclosureFallsBackToProcessCount` |
| 22 | AgentTurnProjection | §3.6 运行中回合的 disclosure 标题使用运行标签 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `runningDisclosureTitleUsesRunningLabel` |
| 23 | AgentTurnVM | agentTurnVMPublishesProjectionChanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `agentTurnVMPublishesProjectionChanges` |
| 24 | AgentTurnVM | activeToolCallStaysInsideProcessDisclosure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeToolCallStaysInsideProcessDisclosure` |
| 25 | AgentTurnVM | pendingAndRecordedTurnKeepStableListIdentity | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pendingAndRecordedTurnKeepStableListIdentity` |
| 26 | BottomStickyPin | 内容在钉底之后继续变高：列表必须重新钉住底部，否则底部被输入框遮住 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomStaysPinnedWhenDocumentGrowsAfterSettle` |
| 27 | BottomStickyPin | 内容连续变高：每一轮增长后都必须重新钉底 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomStaysPinnedAcrossConsecutiveGrowths` |
| 28 | BottomStickyPin | 内容在钉底之后变高：底部状态必须保持为 true | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomStateStaysTrueAfterDocumentGrowth` |
| 29 | BottomStickyPin | 用户已上滚：文档变高不得把列表拽回底部 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomIsNotYankedBackWhenUserScrolledAway` |
| 30 | BottomStickyPin | 解绑后：文档变高不得再被自动钉底 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `noAutoPinAfterDetach` |
| 31 | BoundedProcessSectionRender | 内容超过上限时，行高封顶在上限附近（不随内容增长） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overflowingContentIsCapped` |
| 32 | BoundedProcessSectionRender | 内容短于上限时，行高随内容自适应（不占满上限） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shortContentUsesContentHeight` |
| 33 | ConversationStateLineRender | 状态卡高度只容得下一行文字 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cardHeightFitsSingleLine` |
| 34 | ConversationStateLineRender | 没有细节时状态卡高度不变 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cardHeightStableWithoutDetail` |
| 35 | ConversationStateVM | conversationStateVMAcceptsOnlySelectedConversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateVMAcceptsOnlySelectedConversation` |
| 36 | InitialPositionGate | 首屏就绪：收敛成功后放行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateBecomesReadyAfterSuccessfulSettle` |
| 37 | InitialPositionGate | 首屏就绪：收敛失败也在预算内放行，绝不永久卡死 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateReleasesEvenWhenSettleFails` |
| 38 | InitialPositionGate | 首屏就绪：收敛挂死时由超时兜底放行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesWhenSettleHangs` |
| 39 | InitialPositionGate | 首屏就绪：同一会话重复请求被去重 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateDeduplicatesSameConversation` |
| 40 | InitialPositionGate | 首屏就绪：切换会话作废上一轮等待，不被旧结果污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateDiscardsPreviousConversationOnSwitch` |
| 41 | InitialPositionGate | 首屏就绪：会话切换复位后不再就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateResetClearsReady` |
| 42 | InitialPositionGate | 首屏就绪：相关性失效时不置为就绪 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateIgnoresResultWhenNoLongerRelevant` |
| 43 | InitialPositionGate | 首屏就绪：没有选中会话时直接就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateWithoutConversationIsImmediatelyReady` |
| 44 | InitialPositionGate | 首屏遮罩：会话切换的复位不得作废已在当前会话上启动的收敛 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotCancelConvergenceAlreadyStarted` |
| 45 | InitialPositionGate | 首屏遮罩：复位不得让已失效的旧一轮放行遮罩 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotReleaseMaskFromStaleRound` |
| 46 | ListPresentation | §1.1 activate 期间 isLoading == true，结束后 isLoading == false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadingStateDuringActivate` |
| 47 | ListPresentation | §1.1 conversations 未选中该会话时 activate 被 guard 挡下 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateRequiresSelectedConversation` |
| 48 | ListPresentation | §1.4 完整消息序列短于一页时 hasEarlierTurns == false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierHiddenWhenPageFits` |
| 49 | ListPresentation | §1.4 历史超过一页时 hasEarlierTurns 为 true | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierVisibleWhenHistoryExceedsPage` |
| 50 | ListPresentation | §1.5 切换到另一个会话后旧数据被清空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `switchConversationClearsState` |
| 51 | ListPresentation | §2.6 真实 context compaction 事件被收集为 timelineEvent；预热事件不展示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextCompactionTimelineEvents` |
| 52 | ListPresentation | §4.4 历史耗尽后重复触发 loadEarlier 返回 nil 不再插入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierDoesNotDuplicateWhenReentrant` |
| 53 | ListPresentation | §4.5 翻页到顶后 hasEarlierTurns 翻转为 false 且行不重复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierHidesButtonWhenExhausted` |
| 54 | ListPresentation | §6.7 / §6.9 agent loop 端态后 activity projection 为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityClearedOnTerminalState` |
| 55 | ListPresentation | §6.8 切换到非选中会话后该会话的 activity 不会进入 stateVM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityIsolatedPerSelectedConversation` |
| 56 | ListPresentation | §6.3 缺 detail 时状态行只显示标题，不留占位空格 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `statusLineWithoutDetailHasNoPlaceholder` |
| 57 | ListPresentation | §8.1 空对话激活后 isLoading == false，列表为空，没有 Load earlier | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyConversationLoadsCleanly` |
| 58 | ListPresentation | §8.2 整段对话能放进一页时 hasEarlierTurns == false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singlePageConversationHasNoEarlier` |
| 59 | ListPresentation | §8.5 快速切换会话后旧会话的加载任务不会泄漏到新会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rapidConversationSwitchingIsSafe` |
| 60 | ListV1LargeData | 持续翻页时内存窗口不得无上限增长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `windowStaysBoundedWhilePaging` |
| 61 | ListV1LargeData | 窗口回收不得裁掉最新 turn 的消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictionKeepsNewestTurnMessages` |
| 62 | ListV1LargeData | 翻页裁剪窗口后，刷新必须把中间段消息接回来 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refreshBackfillsTheEvictedGap` |
| 63 | MessageListSendPositioning | 流式回合使用与内容高度无关的稳定尾部留白 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `conservativeReserveIsStable` |
| 64 | MessageListServices | tail gate 第一次 run 返回真实结果，事件突发合并为尾随一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tailGateCollapsesBursts` |
| 65 | MessageListServices | tail gate 在 active run 期间重叠的 caller 不会插入任务 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overlappingRunnersReturnFalse` |
| 66 | MessageListServices | §4.1 loadFirstPage 用 pageSize+1 探测 hasEarlier，溢出才返回 true | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadFirstPageProbesEarlier` |
| 67 | MessageListServices | §4.3 / §4.5 loadEarlier 翻到顶后返回的 hasEarlierMessages 为 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierExhaustsAtTop` |
| 68 | MessageListServices | refreshTail 找到重叠位置时拼接保留头部历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailMergesAtOverlap` |
| 69 | MessageListServices | refreshTail 当 current 为空时使用最新页并补查 hasEarlier | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `refreshTailSeedsFromEmpty` |
| 70 | MessageListServices | refreshTail 无重叠且 current 非空时返回 nil，避免覆盖用户历史位置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailAbortsOnUserScrolling` |
| 71 | MessageListServices | post-send 锚点常量 = 视口高度的 0.75，符合 README §5.5「上 1/4」描述 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `postSendAnchorTopFraction` |
| 72 | MessageListServices | post-send reserve 在无效视口高度下返回 0 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `postSendReserveZeroOnInvalidViewport` |
| 73 | MessageListServices | ScrollCoordinator 静态常量与 README §4/§5 描述一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `scrollCoordinatorConstantsMatchREADME` |
| 74 | MessageListServices | ScrollCoordinator.bottomAnchorID 是稳定常量，UI 测试可按此定位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bottomAnchorIDIsStable` |
| 75 | MessageListStateLifetime | 简洁模式消息列表视图：不得用普通存储属性持有引用类型状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustNotHoldReferenceStateInPlainStoredProperty` |
| 76 | MessageListStateLifetime | 简洁模式消息列表视图：运行时状态容器必须由 StateObject 承载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustCarryRuntimeInStateObject` |
| 77 | MessageListStateLifetime | 简洁模式消息列表视图：首屏就绪必须由带超时兜底的编排器承载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustCarryInitialPositionGate` |
| 78 | MessageListStateLifetime | 简洁模式运行时容器：成员在多次访问之间必须保持同一实例 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeMembersKeepStableIdentity` |
| 79 | MessageListStateLifetime | 简洁模式运行时容器：必须持有底部标记、滚动协调器与底部几何控制器 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeCarriesAllThreeMembers` |
| 80 | MessageListStateLifetime | 简洁模式运行时容器：不得发布任何 @Published（避免重新打开 invalidation 反馈环） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimePublishesNothing` |
| 81 | Observer | MessageObserver 把消息变化转发给 VM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageObserverForwardsChanges` |
| 82 | Observer | MessageObserver 对其他会话的变更不响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageObserverIgnoresOtherConversations` |
| 83 | Observer | MessageObserver cancel 后不再收到事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageObserverCancelStopsDelivery` |
| 84 | Observer | DeveloperModeObserver 构造时同步初始状态并订阅变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeObserverSyncsAndFollows` |
| 85 | Observer | SelectedConversationObserver 无 ConversationStateObserver 时直接同步 stateVM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedConversationObserverWithoutStateObserver` |
| 86 | Observer | SelectedConversationObserver 优先走 ConversationStateObserver 转发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedConversationObserverPrefersStateObserver` |
| 87 | Observer | ConversationStateObserver 构造时发布当前会话的活动投影 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverPublishesInitialProjection` |
| 88 | Observer | ConversationStateObserver 处理会话状态 updated 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverHandlesUpdated` |
| 89 | Observer | ConversationStateObserver 处理会话状态 removed 事件回到 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverHandlesRemoved` |
| 90 | Observer | ConversationStateObserver 忽略非选中会话的状态事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverIgnoresOtherConversations` |
| 91 | Observer | ConversationStateObserver 流式阶段变化会刷新投影 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverFollowsStreamingStage` |
| 92 | Observer | ConversationStateObserver updateSelectedConversation 切换时清空并重取状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverResetsOnSwitch` |
| 93 | Observer | ConversationStateObserver 重复传入同一会话不重复发布 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conversationStateObserverSkipsRedundantSwitch` |
| 94 | Observer | ConversationStateObserver cancel 后不再收到事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverCancelStopsDelivery` |
| 95 | Observer | VerbosityObservationBox 构造时注册 item，cancel 时移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityBoxRegistersAndUnregisters` |
| 96 | Observer | VerbosityObservationBox 在 verbosity 变化时请求刷新 item | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityBoxRefreshesOnVerbosityChange` |
| 97 | Observer | VerbosityObservationBox 的 isActive 跟随选中会话的详细程度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityBoxIsActiveFollowsVerbosity` |
| 98 | Observer | VerbosityObservationBox cancel 后不再刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityBoxCancelStopsRefresh` |
| 99 | ProcessSectionAutoExpandRender | 活跃回合的过程区默认展开：用户不用点按钮就能看到 agent 的动作 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activeTurnShowsProcessByDefault` |
| 100 | ProcessSectionAutoExpandRender | 历史回合的过程区默认折叠：长会话不会被过程区刷屏 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `historicalTurnHidesProcessByDefault` |
| 101 | ProcessSectionAutoExpandRender | 活跃回合比历史回合高：差值就是自动展开的过程区 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeTurnIsTallerThanHistoricalTurn` |
| 102 | ProcessSectionAutoPinRender | 展开后初始即定位到底部，最新内容在底部可见 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initialPositionIsAtBottom` |
| 103 | ProcessSectionAutoPinRender | 内容增长时自动钉到底部，新内容始终在底部出现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentGrowthPinsToBottom` |
| 104 | ProcessSectionAutoPinRender | 用户上滚打断后，内容增长不再把视口拽回底部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userScrollBreaksAutoPin` |
| 105 | ProcessSectionAutoPinRender | 用户滚回底部后，跟随恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumesFollowingWhenBackAtBottom` |
| 106 | ProcessSectionExpansion | 活跃回合默认展开：用户发送消息后不用点按钮就能看到过程 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activeTurnExpandsByDefault` |
| 107 | ProcessSectionExpansion | 历史回合默认折叠：长会话不会被几十个过程区刷屏 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `historicalTurnCollapsesByDefault` |
| 108 | ProcessSectionExpansion | 用户手动折叠后，自动展开不覆盖用户的选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userCollapseIsNotOverridden` |
| 109 | ProcessSectionExpansion | 用户手动展开后保持展开 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userExpandSticks` |
| 110 | ProcessSectionExpansion | 回合结束后保持用户最后看到的状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnEndKeepsCurrentState` |
| 111 | ProcessSectionExpansion | 用户手动折叠后，回合结束仍保持折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userCollapseSurvivesTurnEnd` |
| 112 | ProcessSectionExpansion | 自动展开态不等于用户展开态：前者可被自动逻辑覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `automaticStateIsDistinctFromUserState` |
| 113 | ProcessSectionExpansion | 折叠态不展开 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collapsedIsNotExpanded` |
| 114 | ProcessSectionExpansion | 用户切换状态：展开↔折叠双向 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userToggleSwitchesBothWays` |
| 115 | ProcessSectionFollowState | 初始状态跟随底部 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `followsByDefault` |
| 116 | ProcessSectionFollowState | 用户上滚后不再被拽回底部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsFollowingAfterUserScrollsUp` |
| 117 | ProcessSectionFollowState | 用户滚回底部后恢复跟随 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumesFollowingWhenUserReturnsToBottom` |
| 118 | ProcessSectionFollowState | 上滚后再次贴底，跟随恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recoversAfterRepeatedInterruptions` |
| 119 | ProcessSectionFollowState | 离开底部但未回到底部时，跟随保持关闭 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `leavingBottomAloneDoesNotResumeFollowing` |
| 120 | ProcessSectionFollowState | 同一 UUID 的稳定哈希恒定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stableHashIsDeterministic` |
| 121 | ProcessSectionFollowState | 不同 UUID 的稳定哈希不同 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stableHashDistinguishesIDs` |
| 122 | ProcessSectionFollowState | 稳定哈希非负 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stableHashIsNonNegative` |
| 123 | ProcessSectionInnerScrollResponse | 内层滚动视图对滚轮事件有反应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `innerRespondsToScrollWheel` |
| 124 | ProcessSectionInnerScrollResponse | 内层确实嵌在外层 List 里（嵌套结构成立） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `innerIsNestedInsideOuterList` |
| 125 | ProcessSectionLayout | 上限取视口的 60% | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `maxHeightUsesViewportFraction` |
| 126 | ProcessSectionLayout | 视口过矮时上限落到绝对下限，不会小到看不见 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `maxHeightFallsBackToMinimum` |
| 127 | ProcessSectionLayout | 视口未就绪时退回下限，折叠区不会消失 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `maxHeightHandlesInvalidViewport` |
| 128 | ProcessSectionLayout | 内容短于上限时高度自适应，不补空白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shortContentUsesContentHeight` |
| 129 | ProcessSectionLayout | 内容超过上限时封顶 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `longContentIsCapped` |
| 130 | ProcessSectionLayout | 内容恰好等于上限时按上限取值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exactContentUsesMaxHeight` |
| 131 | ProcessSectionLayout | 尚未测量时先按上限占位，内容不会凭空消失 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unmeasuredContentUsesMaxHeight` |
| 132 | ProcessSectionLayout | 内容超出上限才判定为溢出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overflowDetection` |
| 133 | ProcessSectionLayout | 非法高度不判定为溢出 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `overflowIgnoresInvalidHeights` |
| 134 | ProcessSectionMinHeight | 内容超限时：内层有非零可视高度，且内容完整未被裁剪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overflowingContentKeepsNonZeroViewport` |
| 135 | ProcessSectionMinHeight | 内容短于上限时：高度自适应，不占满上限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shortContentStaysAdaptive` |
| 136 | ProcessSectionScrollDirection | 事实基准：SwiftUI 内层的方向语义是 offset -= deltaY | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `swiftUIInnerUsesOppositeDirection` |
| 137 | ProcessSectionScrollDirection | 修复：relay 主动驱动内层时用原生语义（offset += deltaY） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relayDrivesInnerWithNativeDirection` |
| 138 | ProcessSectionScrollDirection | 用户场景：贴底时向上滚，内层确实能滚 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scrollingUpFromBottomMovesInnerOffset` |
| 139 | ProcessSectionScrollRelay | 内层已到底时向下滚，增量让给外层 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsWhenInnerReachesBottom` |
| 140 | ProcessSectionScrollRelay | 内层未到底时向下滚，增量留在内层 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsScrollInsideInnerWhenNotAtBoundary` |
| 141 | ProcessSectionScrollRelay | 内层已到顶时向上滚，增量让给外层 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsWhenInnerReachesTop` |
| 142 | ProcessSectionScrollRelay | 内层不在顶部时向上滚，增量留在内层 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsScrollInsideInnerWhenNotAtTop` |
| 143 | ProcessSectionScrollRelay | 边界判定留 1pt 容差，不会出现「差一点点就卡住」 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `boundaryUsesOnePointTolerance` |
| 144 | ProcessSectionScrollRelay | 内容不足以滚动时不接力 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotForwardWhenContentFits` |
| 145 | ProcessSectionScrollRelay | 零增量与非法几何不接力 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidInput` |
| 146 | ProcessSectionScrollRelay | 登记与注销是幂等的 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registrationIsIdempotent` |
| 147 | ProcessSectionScrollRelay | 最后一个观察者注销后移除滚轮监视器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesMonitorWhenLastObserverUnregisters` |
| 148 | ProcessSectionScrollRelay | 重新登记会重新启用监视器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reactivatesMonitorOnNewRegistration` |
| 149 | StuckLoadingMask | 首屏遮罩：加载开始后即使没有收敛轮次，遮罩也必须在预算内落下 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesMaskWithinBudgetWithoutAnySettleRound` |
| 150 | StuckLoadingMask | 首屏遮罩：会话切换复位后即使没有收敛轮次，遮罩也必须在预算内落下 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesMaskWithinBudgetAfterConversationSwitch` |
| 151 | StuckLoadingMask | 首屏遮罩：失效的一轮结束后，同一会话必须能重新开始一轮 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateAcceptsNewRoundForSameConversationAfterStaleRound` |
| 152 | StuckLoadingMask | 首屏遮罩：失效的一轮不得放行遮罩，但必须允许后续轮次接手 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateStaleRoundMustNotReleaseMaskButMustHandOver` |
| 153 | ConversationMessageListVM | 切换会话释放上一会话的 Turn VM（**回归 #963**） | 会话 A 有 2 个 Turn、会话 B 有 1 个，先为 A 的行创建 VM | 切到 B 并重新 activate | B 的可见行重新出现，`trackedAgentTurnVMCount` 归零 | P1 | ✅ 已覆盖 | `switchingConversationReleasesPreviousTurnVMs` |
| 154 | ConversationMessageListVM | Turn 离开窗口后释放其 VM（**回归 #963**） | 为 2 个可见 Turn 与 1 个已失效的 pending item 创建 VM | 插入一条新消息触发 rebuild | 失效 item 不再可见，VM 数回落到 2 | P1 | ✅ 已覆盖 | `prunesVMsForTurnsThatLeaveTheWindow` |
| 155 | MessageListSendPositioning | 首条助手消息前取消：活动清空必须结束发送后定位（**回归 #894**） | 定位已开启且观察到活动，turn 投影仍为 pending | 先收到 turn 投影事件，再收到活动清空事件 | 投影事件不结束定位；活动清空结束定位并撤掉尾部留白 | P0 | ✅ 已覆盖 | `cancelBeforeFirstAssistantEndsPostSendPositioning` |
| 156 | MessageListSendPositioning | 回合投影去掉实时活动时必须结束发送后定位 | 定位已开启 | 收到「没有接收实时活动的回合」事件 | 定位结束 | P0 | ✅ 已覆盖 | `liveTurnEndingEndsPostSendPositioning` |
| 157 | MessageListSendPositioning | 活动从未出现前的清空不算回合收尾 | 定位已开启但活动尚未出现 | 先收到清空事件，再依次收到出现/清空事件 | 首次清空保持定位；出现后再清空才结束定位 | P1 | ✅ 已覆盖 | `activityClearingWithoutObservedActivityKeepsPositioning` |
| 158 | MessageListSendPositioning | 回合运行中的活动变化保持定位 | 定位已开启且活动已出现 | 连续收到非空活动变化 | 定位保持开启 | P1 | ✅ 已覆盖 | `activityChangesWhileTurnRunsKeepPositioning` |
| 159 | MessageListSendPositioning | 未开启定位时活动变化不影响状态 | 尚未发送 | 收到活动与 turn 投影事件 | 状态保持未激活 | P2 | ✅ 已覆盖 | `activityChangesBeforeSendAreIgnored` |
| 160 | MessageListSendPositioning | 结束定位是幂等操作 | 定位已开启 | 连续调用两次 `end()`，再收到活动清空 | 不崩溃，定位保持结束 | P2 | ✅ 已覆盖 | `endIsIdempotent` |
| 161 | ActivityLocalization | 活动标题经过注入的本地化解析（**回归 #893**） | — | 用 `[key]` 标记解析器解析发送/思考/生成/处理阶段 | 标题分别返回 `[Sending message…]`、`[Thinking…]`、`[Generating reply…]`、`[Processing…]` | P1 | ✅ 已覆盖 | `activityTitlesUseInjectedLocalization` |
| 162 | ActivityLocalization | 工具与等待阶段的活动文案经过注入的本地化解析（**回归 #893**） | — | 用标记解析器解析单/多任务与等待确认状态 | 单任务 `[Executing]`；多任务 `[Executing 2 tasks]` + `[Latest: …]`；等待 `[Waiting for your confirmation]` | P1 | ✅ 已覆盖 | `toolActivityUsesInjectedLocalization` |
| 163 | ActivityLocalization | 过程折叠标题与耗时经过注入的本地化解析（**回归 #893**） | — | 用标记解析器生成运行中与已完成回合的标题 | 运行中 `[Running] · [1 steps] · [12s]`；已完成 `[Completed after 1 steps] · [12s]` | P1 | ✅ 已覆盖 | `disclosureTitleUsesInjectedLocalization` |
| 164 | ActivityLocalization | 耗时单位依次切换为秒/分/时（**回归 #893**） | — | 用标记解析器生成 45s / 90s / 3600s / 3900s 的标题 | 分别以 `[45s]`、`[1m]`、`[1h]`、`[1h 5m]` 结尾 | P1 | ✅ 已覆盖 | `durationUnitsUseInjectedLocalization` |
| 165 | ActivityLocalization | 活动与过程摘要词条在所有规范语言下都有译文（**回归 #893**） | — | 读取编译后 `.lproj/Localizable.strings` | 15 个词条在 5 种语言下均符合预期 | P1 | ✅ 已覆盖 | `activityLabelsHaveTranslationsInCompiledBundle` |

> 说明：全部 **165 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 34 / 34
- P1: 已覆盖 105 / 105
- P2: 已覆盖 26 / 26
- **合计: 165 / 165**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（34 条）
- **P1**: 其余功能性用例（105 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（26 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 165 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMessageListBrief
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
