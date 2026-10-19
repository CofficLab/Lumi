# TestPlan — PluginMessageListDetailed

## 包概述

PluginMessageListDetailed 的实现包，包含 14 个主要类型；当前测试覆盖 73 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 73

核心组件（源码目录）:
- `Capabilities/`
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

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
- `MessageListToolbarCapability`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **BottomEdgeEvaluator**（8 条）：由 `flushBottomIsAtBottom`、`farFromBottomDoesNotNotify`、`hysteresisUsesLeaveToleranceWhenPreviouslyAtBottom` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListV3ViewModel**（39 条）：由 `activateLoadsFirstPage`、`activateWithoutConversationStaysEmpty`、`activateIgnoresStaleConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListScrollCoordinator**（17 条）：由 `prepareInitialBottomScrollsTwiceWhenNotAttached`、`prepareInitialBottomSkipsWhenNoMessages`、`prepareInitialBottomAbortsWhenConditionFails` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageListService**（9 条）：由 `messageRowsFilterAndMergeToolExecutionMessages`、`messageRowsPreserveUnscopedMessagesAndLegacyGroups`、`messageDerivedPredicatesDistinguishEmptyResponses` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 9 | ListV3ViewModel | 激活会话后加载首屏并更新加载态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateLoadsFirstPage` |
| 10 | ListV3ViewModel | 没有选中会话时保持空态 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activateWithoutConversationStaysEmpty` |
| 11 | ListV3ViewModel | 激活过期会话的请求被丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateIgnoresStaleConversation` |
| 12 | ListV3ViewModel | activateCurrentConversation 读取执行时刻的选中会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateCurrentConversationUsesCurrentSelection` |
| 13 | ListV3ViewModel | 向上翻页 prepend 更早消息并返回锚点 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierPrependsAndReturnsAnchor` |
| 14 | ListV3ViewModel | 无更早消息时翻页返回 nil 且不改变窗口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadEarlierReturnsNilWithoutEarlierMessages` |
| 15 | ListV3ViewModel | 窗口为空时翻页直接返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `loadEarlierReturnsNilWhenEmpty` |
| 16 | ListV3ViewModel | 尾部刷新检测到新消息时覆盖窗口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailAppliesNewMessages` |
| 17 | ListV3ViewModel | 尾部刷新无变化时返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailDetectsNoChange` |
| 18 | ListV3ViewModel | 没有选中会话时尾部刷新返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailWithoutConversationReturnsFalse` |
| 19 | ListV3ViewModel | 会话设置变化后重建历史行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshConversationSettingsRebuildsRows` |
| 20 | ListV3ViewModel | 会话设置变化后 verbosity 透传更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityFollowsConversationSettings` |
| 21 | ListV3ViewModel | 没有渲染能力时 renderer 返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererDegradesWhenMissing` |
| 22 | ListV3ViewModel | 插入用户消息后记录 id 并按时间排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedUserMessageSortsAndRecords` |
| 23 | ListV3ViewModel | 插入同 id 消息时原地替换而不重复追加 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `insertedSameIDReplacesInPlace` |
| 24 | ListV3ViewModel | 忽略其他会话插入的消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedForeignConversationIgnored` |
| 25 | ListV3ViewModel | 忽略独立的工具结果行插入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedToolMessageIgnored` |
| 26 | ListV3ViewModel | 窗口超过上限时裁剪最早的消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertedEvictsBeyondWindow` |
| 27 | ListV3ViewModel | 持久化/更新/删除事件触发尾部刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistedEventsTriggerTailRefresh` |
| 28 | ListV3ViewModel | 其他会话的持久化事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistedForeignConversationIgnored` |
| 29 | ListV3ViewModel | 会话状态变化更新活动消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateChangeUpdatesActivity` |
| 30 | ListV3ViewModel | 其他会话的状态事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateChangeForeignIgnored` |
| 31 | ListV3ViewModel | 非 updated 的状态事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateRemovedIgnored` |
| 32 | ListV3ViewModel | 切换会话后活动消息反映新会话状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageReflectsConversationState` |
| 33 | ListV3ViewModel | 会话状态无活动时活动消息为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityMessageNilWhenNoActivity` |
| 34 | ListV3ViewModel | 流式开关关闭时不产生流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowSuppressedWhenDisabled` |
| 35 | ListV3ViewModel | 流式开启且生成中时产生流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowShownWhenEnabled` |
| 36 | ListV3ViewModel | 流式行属于其他会话时被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowForeignConversationIgnored` |
| 37 | ListV3ViewModel | brief 详细程度下不显示流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowHiddenInBriefMode` |
| 38 | ListV3ViewModel | 非当前会话的流式事件被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingChangeForeignConversationIgnored` |
| 39 | ListV3ViewModel | idle 阶段结束流式时清除流式行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRowClearedWhenIdle` |
| 40 | ListV3ViewModel | 汇总回合工具调用的统计信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySummariesAggregated` |
| 41 | ListV3ViewModel | 没有工具能力时不产生汇总 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `turnActivitySummariesEmptyWithoutToolManager` |
| 42 | ListV3ViewModel | 消息没有 turnID 时不查询工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySkipsWhenNoTurnIDs` |
| 43 | ListV3ViewModel | 单回合活动快照按开始时间排序工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivitySortsToolCalls` |
| 44 | ListV3ViewModel | 没有工具能力时回合活动为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `turnActivityNilWithoutToolManager` |
| 45 | ListV3ViewModel | 流式行可见时丢弃 status 行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyRowsHideStatusWhenStreamingVisible` |
| 46 | ListV3ViewModel | 历史行剔除独立工具结果行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyRowsDropToolResultMessages` |
| 47 | ListV3ViewModel | 切换会话后历史行不残留上一会话内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyRowsResetOnConversationSwitch` |
| 48 | MessageListScrollCoordinator | 首屏定位前会先滚到底，等待重试窗口后再滚一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `prepareInitialBottomScrollsTwiceWhenNotAttached` |
| 49 | MessageListScrollCoordinator | 首屏无消息时无需滚动，直接就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prepareInitialBottomSkipsWhenNoMessages` |
| 50 | MessageListScrollCoordinator | 首屏前置条件中途不成立时放弃定位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prepareInitialBottomAbortsWhenConditionFails` |
| 51 | MessageListScrollCoordinator | 首屏前置条件中途转为 false 时不再执行重试滚动 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `prepareInitialBottomSkipsRetryWhenConditionFlips` |
| 52 | MessageListScrollCoordinator | 新的一轮准备使上一轮失效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `newPreparationInvalidatesPrevious` |
| 53 | MessageListScrollCoordinator | 取消挂起任务后重试滚动不再执行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelPendingTasksStopsRetry` |
| 54 | MessageListScrollCoordinator | 空消息或前置条件不成立时不发起滚动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scrollToBottomGuards` |
| 55 | MessageListScrollCoordinator | 延迟滚动在布局窗口后执行，并在重试窗口后补一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `scheduleScrollToBottomAfterLayoutRunsDelayed` |
| 56 | MessageListScrollCoordinator | 已有滚动任务在执行时，新的延迟请求被忽略（防饿死） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scheduleIgnoresWhileTaskPending` |
| 57 | MessageListScrollCoordinator | 延迟滚动时取消任务可阻止后续滚动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scheduleRespectsCancel` |
| 58 | MessageListScrollCoordinator | 延迟滚动在消息为空或前置条件不成立时不执行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `scheduleGuardsEmptyMessagesAndCondition` |
| 59 | MessageListScrollCoordinator | 已附着底层滚动视图时进入多帧钉底收敛 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `settleBottomPinsUntilStable` |
| 60 | MessageListScrollCoordinator | 钉底不可用时立即停止收敛 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settleBottomStopsWhenPinUnavailable` |
| 61 | MessageListScrollCoordinator | 钉底收敛在前置条件不成立时中止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settleBottomRespectsCondition` |
| 62 | MessageListScrollCoordinator | prepend 后把锚点行钉回视口顶部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToAnchorScrollsToTop` |
| 63 | MessageListScrollCoordinator | 取消后不再执行锚点定位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinToAnchorRespectsCancel` |
| 64 | MessageListScrollCoordinator | 底部锚点 id 与协调器常量一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bottomAnchorIDIsStable` |
| 65 | MessageListService | 消息行过滤工具结果，并把空正文工具调用合并为 turn activity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsFilterAndMergeToolExecutionMessages` |
| 66 | MessageListService | 没有选中会话时保留原始行，且历史工具组使用兼容 render kind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageRowsPreserveUnscopedMessagesAndLegacyGroups` |
| 67 | MessageListService | 空响应判断排除错误和工具调用消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageDerivedPredicatesDistinguishEmptyResponses` |
| 68 | MessageListService | 首屏取最近 pageSize 条并探测是否存在更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsLatestPageAndDetectsEarlierMessages` |
| 69 | MessageListService | 向上翻页保留锚点，并重新检查是否还有更早消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationLoadsEarlierPageAroundAnchor` |
| 70 | MessageListService | 尾部刷新覆盖重叠窗口，避免无重叠时打断历史浏览 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationRefreshesOnlyAnOverlappingTail` |
| 71 | MessageListService | 空窗口首刷补查 earlier，尾部回收只在离开底部时执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationInitialRefreshAndTailEviction` |
| 72 | MessageListService | 尾部刷新门将并发通知合并成当前轮和至多一轮尾随刷新 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tailRefreshGateCoalescesOverlappingRequests` |
| 73 | MessageListService | 通知按当前会话筛选，消息时间相同时按 UUID 稳定排序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `messageNotificationAndOrderingAreStable` |

> 说明：全部 **73 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 57 / 57
- P2: 已覆盖 9 / 9
- **合计: 73 / 73**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（57 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（9 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 73 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
