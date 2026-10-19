# TestPlan — PluginMessageListStandard

## 包概述

PluginMessageListStandard 的实现包，包含 14 个主要类型；当前测试覆盖 73 条用例。

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 73

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
- **InitialPositionGate**（8 条）：由 `gateBecomesReadyAfterSuccessfulSettle`、`gateReleasesEvenWhenSettleFails`、`gateReleasesWhenSettleHangs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV2ViewModel**（24 条）：由 `activationLoadsFirstPage`、`activationWithoutConversationClearsState`、`activationResetsPreviousConversationState` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListBottomSettle**（3 条）：由 `bottomSettleStopsOnceGeometrySettles`、`bottomSettleToleratesSubPixelJitter`、`bottomSettleAbortsWhenGeometryUnavailable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListService**（9 条）：由 `messageRowsFilterAndMergeToolExecutionMessages`、`messageRowsPreserveUnscopedMessagesAndLegacyGroups`、`messageDerivedPredicatesDistinguishEmptyResponses` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListServices**（6 条）：由 `activityMessageCoversSimpleStates`、`activityMessageUsesJobDescription`、`activityMessageFallsBackWithoutRunningJob` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListTurnActivity**（8 条）：由 `turnActivitySortsToolCallsStably`、`turnActivitySummarisesRecords`、`turnActivityHandlesEmptyAndUnfinished` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ScrollViewBottomController**（7 条）：由 `pinToBottomMovesOffsetToDocumentEnd`、`pinToBottomClampsOffsetWhenDocumentShorterThanViewport`、`controllerWithoutScrollViewIsNotAttached` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 9 | InitialPositionGate | 首屏就绪：收敛成功后放行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateBecomesReadyAfterSuccessfulSettle` |
| 10 | InitialPositionGate | 首屏就绪：收敛失败也在预算内放行，绝不永久卡死 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateReleasesEvenWhenSettleFails` |
| 11 | InitialPositionGate | 首屏就绪：收敛挂死时由超时兜底放行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesWhenSettleHangs` |
| 12 | InitialPositionGate | 首屏就绪：同一会话重复请求被去重 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateDeduplicatesSameConversation` |
| 13 | InitialPositionGate | 首屏就绪：切换会话作废上一轮等待，不被旧结果污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateDiscardsPreviousConversationOnSwitch` |
| 14 | InitialPositionGate | 首屏就绪：会话切换复位后不再就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateResetClearsReady` |
| 15 | InitialPositionGate | 首屏就绪：相关性失效时不置为就绪 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateIgnoresResultWhenNoLongerRelevant` |
| 16 | InitialPositionGate | 首屏就绪：没有选中会话时直接就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateWithoutConversationIsImmediatelyReady` |
| 17 | ListV2ViewModel | 激活当前会话后加载最近一页并退出 loading | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationLoadsFirstPage` |
| 18 | ListV2ViewModel | 没有选中会话时清空窗口且不进入 loading | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationWithoutConversationClearsState` |
| 19 | ListV2ViewModel | 切换会话时旧会话消息被清空，不残留上一会话内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationResetsPreviousConversationState` |
| 20 | ListV2ViewModel | 切换到非当前会话的激活请求被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationIgnoresStaleConversation` |
| 21 | ListV2ViewModel | 向上翻页把更早一页前插，并保留已有更早标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierPrependsPage` |
| 22 | ListV2ViewModel | 空窗口或无更早消息时向上翻页不产生锚点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierNoOpWithoutWindow` |
| 23 | ListV2ViewModel | 向上翻页在超过窗口上限且离开底部时回收较新消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierEvictsTailWhenAwayFromBottom` |
| 24 | ListV2ViewModel | 尾部刷新在内容变化时替换窗口并返回 true | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tailRefreshUpdatesWindow` |
| 25 | ListV2ViewModel | 尾部刷新在内容未变化时返回 false 且不重复发布 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailRefreshSkipsIdenticalSnapshot` |
| 26 | ListV2ViewModel | 尾部刷新在没有选中会话时直接返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tailRefreshWithoutConversation` |
| 27 | ListV2ViewModel | 生成阶段暴露流式行，闲置阶段隐藏流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowFollowsStage` |
| 28 | ListV2ViewModel | 非当前会话的流式事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingChangeForOtherConversationIgnored` |
| 29 | ListV2ViewModel | 插入消息直接进入窗口，用户消息记录为最近一条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedMessageLandsInWindow` |
| 30 | ListV2ViewModel | 插入同 id 消息为原地替换，不产生重复行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `insertedMessageWithSameIDReplaces` |
| 31 | ListV2ViewModel | 插入工具结果消息不进入展示窗口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedToolMessageIsIgnored` |
| 32 | ListV2ViewModel | 其他会话的插入事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedMessageForOtherConversationIgnored` |
| 33 | ListV2ViewModel | 持久化与更新事件触发尾部刷新，删除事件触发刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistenceEventsTriggerTailRefresh` |
| 34 | ListV2ViewModel | 其他会话的持久化事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistenceEventForOtherConversationIgnored` |
| 35 | ListV2ViewModel | 按窗口内 turn 汇总工具调用统计 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySummariesAggregateRecords` |
| 36 | ListV2ViewModel | 窗口内无 turn 时不发起工具查询 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySkipsWhenNoTurns` |
| 37 | ListV2ViewModel | turnActivity 在缺少工具能力时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivityWithoutToolManagerIsNil` |
| 38 | ListV2ViewModel | 渲染器与详细程度经由能力透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `accessorsDelegateToCapabilities` |
| 39 | ListV2ViewModel | 会话详细程度变化后重建历史行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationSettingsChangeRebuildsRows` |
| 40 | ListV2ViewModel | 会话状态变化会刷新活动消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateChangeRefreshesActivity` |
| 41 | MessageListBottomSettle | 底部收敛：几何逐帧增长时应在稳定后退出，而不是耗尽全部重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `bottomSettleStopsOnceGeometrySettles` |
| 42 | MessageListBottomSettle | 底部收敛：微小的亚像素抖动不应导致重置稳定计数 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bottomSettleToleratesSubPixelJitter` |
| 43 | MessageListBottomSettle | 底部收敛：未绑定滚动视图时应立即放弃，而不是空转 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomSettleAbortsWhenGeometryUnavailable` |
| 44 | MessageListService | 消息行过滤工具结果，并把空正文工具调用合并为 turn activity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsFilterAndMergeToolExecutionMessages` |
| 45 | MessageListService | 没有选中会话时保留原始行，且历史工具组使用兼容 render kind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsPreserveUnscopedMessagesAndLegacyGroups` |
| 46 | MessageListService | 空响应判断排除错误和工具调用消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageDerivedPredicatesDistinguishEmptyResponses` |
| 47 | MessageListService | 首屏取最近 pageSize 条并探测是否存在更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsLatestPageAndDetectsEarlierMessages` |
| 48 | MessageListService | 向上翻页保留锚点，并重新检查是否还有更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsEarlierPageAroundAnchor` |
| 49 | MessageListService | 尾部刷新覆盖重叠窗口，避免无重叠时打断历史浏览 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationRefreshesOnlyAnOverlappingTail` |
| 50 | MessageListService | 空窗口首刷补查 earlier，尾部回收只在离开底部时执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationInitialRefreshAndTailEviction` |
| 51 | MessageListService | 尾部刷新门将并发通知合并成当前轮和至多一轮尾随刷新 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailRefreshGateCoalescesOverlappingRequests` |
| 52 | MessageListService | 通知按当前会话筛选，消息时间相同时按 UUID 稳定排序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageNotificationAndOrderingAreStable` |
| 53 | MessageListServices | 活动消息：sending / thinking / waitingForUser 各映射到对应文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activityMessageCoversSimpleStates` |
| 54 | MessageListServices | 活动消息：executingTool 有运行中任务时带上任务描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageUsesJobDescription` |
| 55 | MessageListServices | 活动消息：executingTool 无运行中任务时退回通用文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activityMessageFallsBackWithoutRunningJob` |
| 56 | MessageListServices | 活动消息：无活动或缺少会话/状态能力时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageReturnsNilWhenUnavailable` |
| 57 | MessageListServices | 服务容器：选中会话与详细程度经由会话能力透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `servicesProxyConversationCapability` |
| 58 | MessageListServices | 服务容器：缺少会话能力时详细程度回落到默认值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `servicesFallsBackWhenConversationCapabilityMissing` |
| 59 | MessageListTurnActivity | Turn 活动按开始时间升序排序，时间相同按 id 稳定排序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `turnActivitySortsToolCallsStably` |
| 60 | MessageListTurnActivity | Turn 活动统计总数、完成数、失败数与总时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySummarisesRecords` |
| 61 | MessageListTurnActivity | Turn 活动无完成记录时总时长为 nil，失败计数不重复计入完成数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `turnActivityHandlesEmptyAndUnfinished` |
| 62 | MessageListTurnActivity | isToolExecutionOnly 仅对空白或省略号正文且带工具调用的助手消息成立 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolExecutionOnlyPredicateIsNarrow` |
| 63 | MessageListTurnActivity | isEmptyResponse 排除错误消息与带工具调用的消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyResponsePredicateExcludesErrorAndTools` |
| 64 | MessageListTurnActivity | 开发者模式状态只传播真实变化，避免无效刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeStateOnlyPublishesRealChanges` |
| 65 | MessageListTurnActivity | 开发者模式观察器把外部初始值与变更事件写入共享状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeObserverBridgesProviderEvents` |
| 66 | MessageListTurnActivity | 开发者模式观察器在 provider 缺失时按未启用处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeObserverToleratesMissingProvider` |
| 67 | ScrollViewBottomController | 钉底后 contentOffset 落在 documentView 底边 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToBottomMovesOffsetToDocumentEnd` |
| 68 | ScrollViewBottomController | 文档高度小于视口时 offset 夹紧为 0，不产生负偏移 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToBottomClampsOffsetWhenDocumentShorterThanViewport` |
| 69 | ScrollViewBottomController | 未绑定滚动视图时 isAttached 为 false 且钉底返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `controllerWithoutScrollViewIsNotAttached` |
| 70 | ScrollViewBottomController | 脱离绑定后 isAttached 回到 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detachClearsAttachment` |
| 71 | ScrollViewBottomController | 视口高度为 0 时拒绝返回几何快照 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pinToBottomRejectsZeroViewport` |
| 72 | ScrollViewBottomController | 文档高度持续增长时，收敛循环可在高度稳定后退出 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `settleConvergesAfterDocumentHeightStabilizes` |
| 73 | ScrollViewBottomController | 非有限或异常尺寸的文档不会被钉底 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pinToBottomRejectsInvalidGeometry` |

> 说明：全部 **73 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 53 / 53
- P2: 已覆盖 9 / 9
- **合计: 73 / 73**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（11 条）
- **P1**: 其余功能性用例（53 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（9 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 73 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
