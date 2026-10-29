# TestPlan — PluginMessageListDetailed

## 包概述

PluginMessageListDetailed Lumi 消息列表 **V3（详细）** 实现包。工具栏 **Response Detail** 处于 `V3 (详细)` 时， 聊天区由本包接管；`V1` / `V2` 分别由 `PluginMessageListBrief` / `PluginMessageListStandard` 接管。

平台: macOS 14+, iOS 17+
测试文件: 13 个，用例总数: 111

核心组件（源码目录）:
- `Capabilities/`
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MessageListDetailedUITestingSupport`
- `PluginMessageListDetailedPlugin`
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

- **BottomEdgeEvaluator**（8 条）：由 `flushBottomIsAtBottom`、`farFromBottomDoesNotNotify`、`hysteresisUsesLeaveToleranceWhenPreviouslyAtBottom` 等用例锁定；改动该模块时优先跑对应测试文件。
- **InitialPositionGate**（10 条）：由 `gateBecomesReadyAfterSuccessfulSettle`、`gateReleasesEvenWhenSettleFails`、`gateReleasesWhenSettleHangs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV3AuthorizationAfterSwitch**（3 条）：由 `approvedToolCallKeepsTerminalStateAfterSwitchingBack`、`rejectedToolCallKeepsTerminalStateAfterSwitchingBack`、`authorizationStateChangeAloneTriggersRebuild` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV3LargeData**（5 条）：由 `tailEvictionDoesNotCreatePermanentGap`、`sameLengthContentEditRebuildsRows`、`windowStaysBoundedWhilePaging` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV3ViewModel**（39 条）：由 `activateLoadsFirstPage`、`activateWithoutConversationStaysEmpty`、`activateIgnoresStaleConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListDetailedUITestingSupport**（5 条）：由 `fixtureSeedsAllConversations`、`fixtureSeedsMessagesForAllConversations`、`fixtureToolGroupUsesDetailedVerbosity` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListScrollCoordinator**（17 条）：由 `prepareInitialBottomScrollsTwiceWhenNotAttached`、`prepareInitialBottomSkipsWhenNoMessages`、`prepareInitialBottomAbortsWhenConditionFails` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListService**（9 条）：由 `messageRowsFilterAndMergeToolExecutionMessages`、`messageRowsPreserveUnscopedMessagesAndLegacyGroups`、`messageDerivedPredicatesDistinguishEmptyResponses` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListStateLifetime**（6 条）：由 `listViewMustNotHoldReferenceStateInPlainStoredProperty`、`listViewMustCarryRuntimeInStateObject`、`listViewMustCarryInitialPositionGate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StuckLoadingMask**（4 条）：由 `gateReleasesMaskWithinBudgetWithoutAnySettleRound`、`gateReleasesMaskWithinBudgetAfterConversationSwitch`、`gateAcceptsNewRoundForSameConversationAfterStaleRound` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | BottomEdgeEvaluator | 文档底沿正好贴合视口底时判定为在底部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `flushBottomIsAtBottom` |
| 2 | BottomEdgeEvaluator | 远离底部且上次不在底部时不触发回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `farFromBottomDoesNotNotify` |
| 3 | BottomEdgeEvaluator | 迟滞：上次在底部时用宽容的离开阈值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hysteresisUsesLeaveToleranceWhenPreviouslyAtBottom` |
| 4 | BottomEdgeEvaluator | 迟滞：真正越过后翻转并触发回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crossingToleranceFlipsAndNotifies` |
| 5 | BottomEdgeEvaluator | 回到容差内时重新翻转回在底部并触发回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returningWithinToleranceNotifies` |
| 6 | BottomEdgeEvaluator | degenerateGeometryReturnsNil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `degenerateGeometryReturnsNil` |
| 7 | BottomEdgeEvaluator | 可视高度大于文档高度时视为在底部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visibleTallerThanDocumentIsAtBottom` |
| 8 | BottomEdgeEvaluator | 默认阈值取自滚动协调器的迟滞常量 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultTolerancesMatchCoordinatorConstants` |
| 9 | InitialPositionGate | 首屏就绪：收敛成功后放行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateBecomesReadyAfterSuccessfulSettle` |
| 10 | InitialPositionGate | 首屏就绪：收敛失败也在预算内放行，绝不永久卡死 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateReleasesEvenWhenSettleFails` |
| 11 | InitialPositionGate | 首屏就绪：收敛挂死时由超时兜底放行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesWhenSettleHangs` |
| 12 | InitialPositionGate | 首屏就绪：同一会话重复请求被去重 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateDeduplicatesSameConversation` |
| 13 | InitialPositionGate | 首屏就绪：切换会话作废上一轮等待，不被旧结果污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateDiscardsPreviousConversationOnSwitch` |
| 14 | InitialPositionGate | 首屏就绪：会话切换复位后不再就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateResetClearsReady` |
| 15 | InitialPositionGate | 首屏就绪：相关性失效时不置为就绪 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateIgnoresResultWhenNoLongerRelevant` |
| 16 | InitialPositionGate | 首屏就绪：没有选中会话时直接就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateWithoutConversationIsImmediatelyReady` |
| 17 | InitialPositionGate | 首屏遮罩：会话切换的复位不得作废已在当前会话上启动的收敛 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotCancelConvergenceAlreadyStarted` |
| 18 | InitialPositionGate | 首屏遮罩：复位不得让已失效的旧一轮放行遮罩 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotReleaseMaskFromStaleRound` |
| 19 | ListV3AuthorizationAfterSwitch | 已允许的工具调用在切走再切回后仍是授权终态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvedToolCallKeepsTerminalStateAfterSwitchingBack` |
| 20 | ListV3AuthorizationAfterSwitch | 已拒绝的工具调用在切走再切回后仍是授权终态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectedToolCallKeepsTerminalStateAfterSwitchingBack` |
| 21 | ListV3AuthorizationAfterSwitch | 授权状态变化本身就会触发历史行重建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationStateChangeAloneTriggersRebuild` |
| 22 | ListV3LargeData | 翻页裁剪窗口后，新消息到达不得让中间段消息永久消失 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailEvictionDoesNotCreatePermanentGap` |
| 23 | ListV3LargeData | 内容被等长替换时历史行必须更新 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `sameLengthContentEditRebuildsRows` |
| 24 | ListV3LargeData | 持续翻页时内存窗口不得无上限增长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `windowStaysBoundedWhilePaging` |
| 25 | ListV3LargeData | 工具调用统计不应随窗口内 turn 数线性放大 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallQueriesDoNotScaleWithTurnCount` |
| 26 | ListV3LargeData | 大窗口下重建历史行的耗时应保持有界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebuildHistoryRowsStaysFastAtScale` |
| 27 | ListV3ViewModel | 激活会话后加载首屏并更新加载态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateLoadsFirstPage` |
| 28 | ListV3ViewModel | 没有选中会话时保持空态 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activateWithoutConversationStaysEmpty` |
| 29 | ListV3ViewModel | 激活过期会话的请求被丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateIgnoresStaleConversation` |
| 30 | ListV3ViewModel | activateCurrentConversation 读取执行时刻的选中会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateCurrentConversationUsesCurrentSelection` |
| 31 | ListV3ViewModel | 向上翻页 prepend 更早消息并返回锚点 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierPrependsAndReturnsAnchor` |
| 32 | ListV3ViewModel | 无更早消息时翻页返回 nil 且不改变窗口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierReturnsNilWithoutEarlierMessages` |
| 33 | ListV3ViewModel | 窗口为空时翻页直接返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `loadEarlierReturnsNilWhenEmpty` |
| 34 | ListV3ViewModel | 尾部刷新检测到新消息时覆盖窗口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailAppliesNewMessages` |
| 35 | ListV3ViewModel | 尾部刷新无变化时返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailDetectsNoChange` |
| 36 | ListV3ViewModel | 没有选中会话时尾部刷新返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailWithoutConversationReturnsFalse` |
| 37 | ListV3ViewModel | 会话设置变化后重建历史行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshConversationSettingsRebuildsRows` |
| 38 | ListV3ViewModel | 会话设置变化后 verbosity 透传更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityFollowsConversationSettings` |
| 39 | ListV3ViewModel | 没有渲染能力时 renderer 返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererDegradesWhenMissing` |
| 40 | ListV3ViewModel | 插入用户消息后记录 id 并按时间排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedUserMessageSortsAndRecords` |
| 41 | ListV3ViewModel | 插入同 id 消息时原地替换而不重复追加 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `insertedSameIDReplacesInPlace` |
| 42 | ListV3ViewModel | 忽略其他会话插入的消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedForeignConversationIgnored` |
| 43 | ListV3ViewModel | 忽略独立的工具结果行插入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedToolMessageIgnored` |
| 44 | ListV3ViewModel | 窗口超过上限时裁剪最早的消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedEvictsBeyondWindow` |
| 45 | ListV3ViewModel | 持久化/更新/删除事件触发尾部刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistedEventsTriggerTailRefresh` |
| 46 | ListV3ViewModel | 其他会话的持久化事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistedForeignConversationIgnored` |
| 47 | ListV3ViewModel | 会话状态变化更新活动消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateChangeUpdatesActivity` |
| 48 | ListV3ViewModel | 其他会话的状态事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateChangeForeignIgnored` |
| 49 | ListV3ViewModel | 非 updated 的状态事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateRemovedIgnored` |
| 50 | ListV3ViewModel | 切换会话后活动消息反映新会话状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageReflectsConversationState` |
| 51 | ListV3ViewModel | 会话状态无活动时活动消息为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageNilWhenNoActivity` |
| 52 | ListV3ViewModel | 流式开关关闭时不产生流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowSuppressedWhenDisabled` |
| 53 | ListV3ViewModel | 流式开启且生成中时产生流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowShownWhenEnabled` |
| 54 | ListV3ViewModel | 流式行属于其他会话时被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowForeignConversationIgnored` |
| 55 | ListV3ViewModel | brief 详细程度下不显示流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowHiddenInBriefMode` |
| 56 | ListV3ViewModel | 非当前会话的流式事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingChangeForeignConversationIgnored` |
| 57 | ListV3ViewModel | idle 阶段结束流式时清除流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowClearedWhenIdle` |
| 58 | ListV3ViewModel | 汇总回合工具调用的统计信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySummariesAggregated` |
| 59 | ListV3ViewModel | 没有工具能力时不产生汇总 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `turnActivitySummariesEmptyWithoutToolManager` |
| 60 | ListV3ViewModel | 消息没有 turnID 时不查询工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySkipsWhenNoTurnIDs` |
| 61 | ListV3ViewModel | 单回合活动快照按开始时间排序工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySortsToolCalls` |
| 62 | ListV3ViewModel | 没有工具能力时回合活动为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivityNilWithoutToolManager` |
| 63 | ListV3ViewModel | 流式行可见时丢弃 status 行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyRowsHideStatusWhenStreamingVisible` |
| 64 | ListV3ViewModel | 历史行剔除独立工具结果行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyRowsDropToolResultMessages` |
| 65 | ListV3ViewModel | 切换会话后历史行不残留上一会话内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyRowsResetOnConversationSwitch` |
| 66 | MessageListDetailedUITestingSupport | 夹具：seed 后三个会话都存在，且都带消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureSeedsAllConversations` |
| 67 | MessageListDetailedUITestingSupport | 夹具：三个会话都写入了消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureSeedsMessagesForAllConversations` |
| 68 | MessageListDetailedUITestingSupport | 夹具：工具调用组会话为 detailed 详细程度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureToolGroupUsesDetailedVerbosity` |
| 69 | MessageListDetailedUITestingSupport | 夹具：工具调用组会话含多条工具调用，且助手正文非空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fixtureToolGroupHasMultipleCallsWithNonEmptyBody` |
| 70 | MessageListDetailedUITestingSupport | 夹具：重复 seed 不产生重复会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fixtureSeedIsIdempotent` |
| 71 | MessageListScrollCoordinator | 首屏定位前会先滚到底，等待重试窗口后再滚一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `prepareInitialBottomScrollsTwiceWhenNotAttached` |
| 72 | MessageListScrollCoordinator | 首屏无消息时无需滚动，直接就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prepareInitialBottomSkipsWhenNoMessages` |
| 73 | MessageListScrollCoordinator | 首屏前置条件中途不成立时放弃定位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prepareInitialBottomAbortsWhenConditionFails` |
| 74 | MessageListScrollCoordinator | 首屏前置条件中途转为 false 时不再执行重试滚动 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `prepareInitialBottomSkipsRetryWhenConditionFlips` |
| 75 | MessageListScrollCoordinator | 新的一轮准备使上一轮失效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `newPreparationInvalidatesPrevious` |
| 76 | MessageListScrollCoordinator | 取消挂起任务后重试滚动不再执行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelPendingTasksStopsRetry` |
| 77 | MessageListScrollCoordinator | 空消息或前置条件不成立时不发起滚动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scrollToBottomGuards` |
| 78 | MessageListScrollCoordinator | 延迟滚动在布局窗口后执行，并在重试窗口后补一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `scheduleScrollToBottomAfterLayoutRunsDelayed` |
| 79 | MessageListScrollCoordinator | 已有滚动任务在执行时，新的延迟请求被忽略（防饿死） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scheduleIgnoresWhileTaskPending` |
| 80 | MessageListScrollCoordinator | 延迟滚动时取消任务可阻止后续滚动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scheduleRespectsCancel` |
| 81 | MessageListScrollCoordinator | 延迟滚动在消息为空或前置条件不成立时不执行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `scheduleGuardsEmptyMessagesAndCondition` |
| 82 | MessageListScrollCoordinator | 已附着底层滚动视图时进入多帧钉底收敛 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `settleBottomPinsUntilStable` |
| 83 | MessageListScrollCoordinator | 钉底不可用时立即停止收敛 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settleBottomStopsWhenPinUnavailable` |
| 84 | MessageListScrollCoordinator | 钉底收敛在前置条件不成立时中止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settleBottomRespectsCondition` |
| 85 | MessageListScrollCoordinator | prepend 后把锚点行钉回视口顶部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToAnchorScrollsToTop` |
| 86 | MessageListScrollCoordinator | 取消后不再执行锚点定位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToAnchorRespectsCancel` |
| 87 | MessageListScrollCoordinator | 底部锚点 id 与协调器常量一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bottomAnchorIDIsStable` |
| 88 | MessageListService | 消息行过滤工具结果，并把空正文工具调用合并为 turn activity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsFilterAndMergeToolExecutionMessages` |
| 89 | MessageListService | 没有选中会话时保留原始行，且历史工具组使用兼容 render kind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsPreserveUnscopedMessagesAndLegacyGroups` |
| 90 | MessageListService | 空响应判断排除错误和工具调用消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageDerivedPredicatesDistinguishEmptyResponses` |
| 91 | MessageListService | 首屏取最近 pageSize 条并探测是否存在更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsLatestPageAndDetectsEarlierMessages` |
| 92 | MessageListService | 向上翻页保留锚点，并重新检查是否还有更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsEarlierPageAroundAnchor` |
| 93 | MessageListService | 尾部刷新覆盖重叠窗口，避免无重叠时打断历史浏览 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationRefreshesOnlyAnOverlappingTail` |
| 94 | MessageListService | 空窗口首刷补查 earlier，窗口超上限时一律回收尾部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationInitialRefreshAndTailEviction` |
| 95 | MessageListService | 尾部刷新门将并发通知合并成当前轮和至多一轮尾随刷新 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailRefreshGateCoalescesOverlappingRequests` |
| 96 | MessageListService | 通知按当前会话筛选，消息时间相同时按 UUID 稳定排序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageNotificationAndOrderingAreStable` |
| 97 | MessageListStateLifetime | 详细模式消息列表视图：不得用普通存储属性持有引用类型状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustNotHoldReferenceStateInPlainStoredProperty` |
| 98 | MessageListStateLifetime | 详细模式消息列表视图：运行时状态容器必须由 StateObject 承载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustCarryRuntimeInStateObject` |
| 99 | MessageListStateLifetime | 详细模式消息列表视图：首屏就绪必须由带超时兜底的编排器承载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustCarryInitialPositionGate` |
| 100 | MessageListStateLifetime | 详细模式运行时容器：成员在多次访问之间必须保持同一实例 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeMembersKeepStableIdentity` |
| 101 | MessageListStateLifetime | 详细模式运行时容器：必须持有底部标记、滚动协调器与底部几何控制器 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeCarriesAllThreeMembers` |
| 102 | MessageListStateLifetime | 详细模式运行时容器：不得发布任何 @Published（避免重新打开 invalidation 反馈环） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimePublishesNothing` |
| 103 | StuckLoadingMask | 首屏遮罩：加载开始后即使没有收敛轮次，遮罩也必须在预算内落下 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesMaskWithinBudgetWithoutAnySettleRound` |
| 104 | StuckLoadingMask | 首屏遮罩：会话切换复位后即使没有收敛轮次，遮罩也必须在预算内落下 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesMaskWithinBudgetAfterConversationSwitch` |
| 105 | StuckLoadingMask | 首屏遮罩：失效的一轮结束后，同一会话必须能重新开始一轮 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateAcceptsNewRoundForSameConversationAfterStaleRound` |
| 106 | StuckLoadingMask | 首屏遮罩：失效的一轮不得放行遮罩，但必须允许后续轮次接手 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateStaleRoundMustNotReleaseMaskButMustHandOver` |
| 107 | BottomStickyPin | 文档在钉底之后继续变高（懒加载行物化 / Markdown 异步解析回填）时，列表必须重新钉住底沿，否则底部被输入框遮住 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomStaysPinnedWhenDocumentGrowsAfterSettle` |
| 108 | BottomStickyPin | 文档连续变高时每一轮都要重新钉底，只有最后一帧的位置算数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomStaysPinnedAcrossConsecutiveGrowths` |
| 109 | BottomStickyPin | 文档变高后「是否在底部」必须仍为 true，否则后续新消息彻底不再跟随滚到底 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomStateStaysTrueAfterDocumentGrowth` |
| 110 | BottomStickyPin | 用户已上滚时文档变高不得把列表拽回底部 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomIsNotYankedBackWhenUserScrolledAway` |
| 111 | BottomStickyPin | 解绑之后不得再自动钉底（换会话重建 List 时旧 tracker 不得继续操作） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noAutoPinAfterDetach` |

> 说明：全部 **106 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 30 / 30
- P1: 已覆盖 71 / 71
- P2: 已覆盖 10 / 10
- **合计: 111 / 111**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（27 条）
- **P1**: 其余功能性用例（69 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（10 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 106 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMessageListDetailed
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
