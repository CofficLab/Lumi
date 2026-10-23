# TestPlan — PluginMessageListBrief

## 包概述

PluginMessageListBrief 是消息列表 V1（Brief 模式）的实现包。它按 **Agent Turn** 分组
会话消息——每个 turn 包含触发它的用户消息、可折叠的过程（process）区段、以及最终回复。
实时进度由固定在列表底部的状态卡统一汇报，而非嵌入 turn 内部。

核心组件:
- `PluginMessageListBriefPlugin` - 装配插件（`onBoot` 解析 Provider 并注册 ChatSection 项，
  `onShutdown` 拆除监听）
- `ConversationMessageListVM` - 消息列表主 ViewModel（加载、翻页、状态聚合）
- `ConversationStateVM` - 会话级状态 VM（turn 行集合、加载态、activity projection、
  timeline events）
- `AgentTurnVM` - 单个 turn 的 ViewModel（projection 发布、展开/折叠）
- `ListV1Presentation` - 将原始消息序列投影为 turn 行（`ListV1Row`）
- `AgentTurnSummaryBuilder` - 从 turn 记录构建 disclosure 摘要（步骤数 / 耗时）
- `AgentActivityProjection` - 将 agent loop activity 映射为底部状态卡标题 / 详情，
  并用 `statusLineText` 合成状态卡那一行的完整文本
- `MessageListPaginationService` - 首页加载 + 向前翻页
- `MessageListScrollCoordinator` - 滚动锚点、append/prepend 延迟、自动跟随判定
- `MessageListSendPositioning` - 发送后新 turn 定位到视口上 1/4
- `MessageListTailRefreshGate` - 尾部刷新去重（合并突发事件为单次刷新）
- `MessageObserver` / `SelectedConversationObserver` / `ConversationStateObserver` /
  `DeveloperModeObserver` - 四类事件订阅

## 公开 API

### ConversationMessageListVM
- `isLoading` / `isLoadingEarlier` / `hasEarlierTurns`
- `loadFirstPage()` / `loadEarlierMessages()` → `Bool?`
- 内部持有 `ConversationStateVM` 并按选中会话切换

### ConversationStateVM
- `rows: [ListV1Row]` - turn 行集合
- `isLoading` / `hasEarlierTurns` / `activity` / `timelineEvents`
- `detailText` - 状态卡细节（与标题合并到同一行，缺省时只显示标题）
- `turnVMs` - `[AgentTurnVM]` 字典，按 turnID 索引

### AgentTurnVM
- `projection: AgentTurnProjection` - 用户消息 / process 消息 / lastMessage
- `isExpanded` - 过程区段展开/折叠
- `disclosureTitle` - 折叠行摘要文本

### AgentTurnProjection
- `userMessage` / `processMessages` / `lastMessage`
- `hasToolCalls` / `toolCallCount` / `elapsedTime`

### AgentActivityProjection
- `phase` / `title` / `detail` / `iconName`
- 从 `AgentLoopActivity` 映射：sending → thinking → generating → running N tasks → waiting

### 关键行为契约（实现约定，非协议要求）
- **Brief 模式互斥**：toolbar Response Detail chip 在 L (Brief) 时才显示本列表；
  其他级别由别的消息列表接管
- **首次打开定位底部**：加载完成后列表直接停在底部，不出现从顶部跳转的动画
- **Turn 分组确定性**：每条 user 消息各起一个 turn，不合并；tool/system 不出现在
  process / last 投影中
- **流式回复不入 turn**：回合进行中 `lastMessage` 为 nil，实时进度仅由底部状态卡汇报
- **发送后上 1/4 定位**：新 turn 顶部对齐视口 25% 处（`targetTopFraction == 0.25`）
- **翻页无跳动**：prepend 后原顶部 turn 保持位置（`postPrependDelayNs == 50ms`）
- **消息窗口有上限且回收按 turn 整段**：窗口上限 `maxRetainedCount = 300`。
  翻页把更早一页整段加进窗口，不回收的话长会话会把整个会话拉进内存。
  回收不能只按条数裁 —— brief 视图的行由窗口消息按 `turnID` 聚合，裁半个 turn
  会让那行显示成残缺内容；最新 turn 是用户当前所在的对话，裁掉会让当前对话整行消失。
  裁掉的段落在下次尾部刷新时由空档回填接回，不会永久丢失
- **Activity 生命周期**：agent loop 进入端态（completed / failed / cancelled）后
  activity projection 立即为 nil；切换会话时 activity 被清空
- **装配降级**：缺 Provider 时不注册 ChatSection 项，不抛错

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 活动投影 | 流式思考阶段映射为思考活动 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `thinking` |
| 2 | 活动投影 | 生成阶段映射为生成活动 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `generating` |
| 3 | 活动投影 | 工具阶段展示具体工具描述 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `executingTool` |
| 4 | 活动投影 | 多个工具任务显示任务数量 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `multipleTools` |
| 5 | 活动投影 | 等待用户阶段不暴露工具输出 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `waitingForUser` |
| 6 | 活动投影 | 回合运行中但 activity 短暂为空时保留状态视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runningWithoutActivity` |
| 7 | 活动投影 | 回合暂停但 activity 短暂为空时保留等待状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedWithoutActivity` |
| 8 | 活动投影 | 空闲阶段不显示活动视图 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `idle` |
| 9 | Turn 布局 | finished turn 包含 user、process、last 三段且 user 恰好一条 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `finishedTurnLayout` |
| 10 | Turn 布局 | 同一时间线里两条 user 消息各属于一个 turn 不会合并 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `twoUserMessagesRemainSeparateTurns` |
| 11 | Turn 布局 | tool 与 system 不会进入 process / last 投影 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolAndSystemRowsAreHidden` |
| 12 | Turn 布局 | failed turn 仍把 error 消息作为 last 渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedTurnSurfacesErrorAsLastMessage` |
| 13 | Turn 布局 | 流式回合进行中 `lastMessage` 为 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingTurnHasNoLastMessage` |
| 14 | Turn 布局 | 空回复回合不暴露 `lastMessage` | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyReplyTurnHidesLastMessage` |
| 15 | Disclosure | 完成回合的 disclosure 标题显示步骤数与耗时 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `finishedDisclosureTitleShowsStepsAndDuration` |
| 16 | Disclosure | 没有工具调用时步骤数回退到 process 消息数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `disclosureFallsBackToProcessCount` |
| 17 | Disclosure | 运行中回合的 disclosure 标题使用运行标签 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runningDisclosureTitleUsesRunningLabel` |
| 18 | Turn VM | AgentTurnVM 发布 projection 变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `agentTurnVMPublishesProjectionChanges` |
| 19 | Turn VM | 活动工具调用留在 process disclosure 内 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `activeToolCallStaysInsideProcessDisclosure` |
| 20 | Turn VM | 待处理与已记录 turn 保持稳定的列表身份 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingAndRecordedTurnKeepStableListIdentity` |
| 21 | 状态 VM | ConversationStateVM 只接受选中会话的活动投影 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conversationStateVMAcceptsOnlySelectedConversation` |
| 22 | 加载 | activate 期间 `isLoading == true`，结束后为 false | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadingStateDuringActivate` |
| 23 | 加载 | 未选中该会话时 activate 被 guard 挡下 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateRequiresSelectedConversation` |
| 24 | 翻页 | 消息数少于 pageSize 时 `hasEarlierTurns == false` | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierHiddenWhenPageFits` |
| 25 | 翻页 | 历史超过一页时 `hasEarlierTurns` 为 true | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierVisibleWhenHistoryExceedsPage` |
| 26 | 会话切换 | 切换会话后旧数据被清空 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `switchConversationClearsState` |
| 27 | Compaction | 真实 compaction 事件被收集为 timelineEvent；预热事件不展示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextCompactionTimelineEvents` |
| 28 | 翻页 | 历史耗尽后重复触发 `loadEarlier` 不再插入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierDoesNotDuplicateWhenReentrant` |
| 29 | 翻页 | 翻页到顶后 `hasEarlierTurns` 翻转为 false 且行不重复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierHidesButtonWhenExhausted` |
| 30 | 状态卡 | agent loop 端态后 activity projection 为 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `activityClearedOnTerminalState` |
| 31 | 状态卡 | 非选中会话的 activity 不进入 stateVM | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `activityIsolatedPerSelectedConversation` |
| 32 | 状态卡 | 缺 detail 时状态行只显示标题，不留占位空格 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusLineWithoutDetailHasNoPlaceholder` |
| 33 | 边界 | 空对话激活后 `isLoading == false`，列表为空 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyConversationLoadsCleanly` |
| 34 | 边界 | 整段对话能放进一页时 `hasEarlierTurns == false` | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singlePageConversationHasNoEarlier` |
| 35 | 边界 | 快速切换会话后旧会话的加载任务不会泄漏到新会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rapidConversationSwitchingIsSafe` |
| 36 | 定位 | 流式回合使用与内容高度无关的稳定尾部留白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conservativeReserveIsStable` |
| 37 | 服务 | tail gate 第一次 run 返回真实结果，事件突发合并为尾随一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tailGateCollapsesBursts` |
| 38 | 服务 | tail gate 在 active run 期间重叠的 caller 不会插入任务 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overlappingRunnersReturnFalse` |
| 39 | 服务 | `loadFirstPage` 用 pageSize+1 探测 hasEarlier | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadFirstPageProbesEarlier` |
| 40 | 服务 | `loadEarlier` 翻到顶后返回 hasEarlierMessages = false | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadEarlierExhaustsAtTop` |
| 41 | 服务 | `refreshTail` 找到重叠位置时拼接保留头部历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailMergesAtOverlap` |
| 42 | 服务 | `refreshTail` 当 current 为空时使用最新页并补查 hasEarlier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshTailSeedsFromEmpty` |
| 43 | 服务 | `refreshTail` 无重叠且 current 非空时返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refreshTailAbortsOnUserScrolling` |
| 44 | 定位 | post-send 锚点常量 = 视口高度的 0.75 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `postSendAnchorTopFraction` |
| 45 | 定位 | post-send reserve 在无效视口高度下返回 0 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `postSendReserveZeroOnInvalidViewport` |
| 46 | 常量 | `ScrollCoordinator` 静态常量与 README 描述一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scrollCoordinatorConstantsMatchREADME` |
| 47 | 常量 | `ScrollCoordinator.bottomAnchorID` 是稳定常量，UI 测试可按此定位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bottomAnchorIDIsStable` |
| 48 | 观察 | 消息观察者转发选中会话的变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageObserverForwardsChanges` |
| 49 | 观察 | 消息观察者忽略非选中会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `messageObserverIgnoresOtherConversations` |
| 50 | 观察 | 消息观察者 cancel 后不再投递 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageObserverCancelStopsDelivery` |
| 51 | 观察 | 开发者模式观察者同步初始状态并跟随变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `developerModeObserverSyncsAndFollows` |
| 52 | 观察 | 无会话状态观察者时，选中会话观察者独立工作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedConversationObserverWithoutStateObserver` |
| 53 | 观察 | 同时存在两者时优先使用会话状态观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedConversationObserverPrefersStateObserver` |
| 54 | 观察 | 会话状态观察者构造时立即发布一次初始投影 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverPublishesInitialProjection` |
| 55 | 观察 | 会话状态观察者处理 `.updated` 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverHandlesUpdated` |
| 56 | 观察 | 会话状态观察者处理 `.removed` 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverHandlesRemoved` |
| 57 | 观察 | 会话状态观察者忽略非选中会话的状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conversationStateObserverIgnoresOtherConversations` |
| 58 | 观察 | 会话状态观察者跟随 streaming 阶段更新活动 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conversationStateObserverFollowsStreamingStage` |
| 59 | 观察 | 切换会话时会话状态观察者复位状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conversationStateObserverResetsOnSwitch` |
| 60 | 观察 | 重复切换到同一会话不重复重置 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `conversationStateObserverSkipsRedundantSwitch` |
| 61 | 观察 | 会话状态观察者 cancel 后不再投递 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationStateObserverCancelStopsDelivery` |
| 62 | Verbosity | verbosity 框注册与注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityBoxRegistersAndUnregisters` |
| 63 | Verbosity | verbosity 变化时刷新 verbosity 框 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityBoxRefreshesOnVerbosityChange` |
| 64 | Verbosity | verbosity 框激活态跟随 verbosity 值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verbosityBoxIsActiveFollowsVerbosity` |
| 65 | Verbosity | verbosity 框 cancel 后停止刷新 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `verbosityBoxCancelStopsRefresh` |
| 66 | InitialPositionGate | 首屏就绪：收敛成功后放行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateBecomesReadyAfterSuccessfulSettle` |
| 67 | InitialPositionGate | 首屏就绪：同一会话重复请求被去重 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateDeduplicatesSameConversation` |
| 68 | InitialPositionGate | 首屏就绪：切换会话作废上一轮等待，不被旧结果污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateDiscardsPreviousConversationOnSwitch` |
| 69 | InitialPositionGate | 首屏就绪：相关性失效时不置为就绪 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateIgnoresResultWhenNoLongerRelevant` |
| 70 | InitialPositionGate | 首屏就绪：收敛失败也在预算内放行，绝不永久卡死 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesEvenWhenSettleFails` |
| 71 | InitialPositionGate | 首屏就绪：收敛挂死时由超时兜底放行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateReleasesWhenSettleHangs` |
| 72 | InitialPositionGate | 首屏就绪：会话切换复位后不再就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateResetClearsReady` |
| 73 | InitialPositionGate | 首屏遮罩：会话切换的复位不得作废已在当前会话上启动的收敛 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotCancelConvergenceAlreadyStarted` |
| 74 | InitialPositionGate | 首屏遮罩：复位不得让已失效的旧一轮放行遮罩 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gateResetMustNotReleaseMaskFromStaleRound` |
| 75 | InitialPositionGate | 首屏就绪：没有选中会话时直接就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateWithoutConversationIsImmediatelyReady` |
| 76 | ListV1LargeData | 窗口回收不得裁掉最新 turn 的消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictionKeepsNewestTurnMessages` |
| 77 | ListV1LargeData | 翻页裁剪窗口后，刷新必须把中间段消息接回来 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refreshBackfillsTheEvictedGap` |
| 78 | ListV1LargeData | 持续翻页时内存窗口不得无上限增长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `windowStaysBoundedWhilePaging` |
| 79 | MessageListStateLifetime | 简洁模式消息列表视图：首屏就绪必须由带超时兜底的编排器承载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustCarryInitialPositionGate` |
| 80 | MessageListStateLifetime | 简洁模式消息列表视图：运行时状态容器必须由 StateObject 承载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustCarryRuntimeInStateObject` |
| 81 | MessageListStateLifetime | 简洁模式消息列表视图：不得用普通存储属性持有引用类型状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listViewMustNotHoldReferenceStateInPlainStoredProperty` |
| 82 | MessageListStateLifetime | 简洁模式运行时容器：必须持有底部标记、滚动协调器与底部几何控制器 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeCarriesAllThreeMembers` |
| 83 | MessageListStateLifetime | 简洁模式运行时容器：成员在多次访问之间必须保持同一实例 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimeMembersKeepStableIdentity` |
| 84 | MessageListStateLifetime | 简洁模式运行时容器：不得发布任何 @Published（避免重新打开 invalidation 反馈环） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runtimePublishesNothing` |
| 85 | 状态卡 | 状态行在细节缺失时只显示标题 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusLineWithoutDetail` |
| 86 | 状态卡 | 状态行在细节为空字符串时也不产生尾部分隔符 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusLineWithEmptyDetail` |
| 87 | 状态卡 | 状态行把标题与细节合并到同一行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `statusLineMergesDetail` |
| 88 | 状态卡 | 状态行恒为单行文本，不含换行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `statusLineIsSingleLine` |
| 89 | 状态卡 | 每个活动阶段都能产出一行状态文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyStageProducesSingleLineStatusText` |
| 90 | 状态卡 | 状态卡高度只容得下一行文字（渲染级，两行版式为 46pt 会失败） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cardHeightFitsSingleLine` |
| 91 | 状态卡 | 有无细节时状态卡高度不变（渲染级） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cardHeightStableWithoutDetail` |

## 仅人工验收场景

以下场景依赖真实 `NSScrollView` 行为 / 鼠标 / 视觉，目前仅人工验收（README 标记 🖱）。

| ID | 描述 | 原因 |
|----|------|------|
| M1 | §1.2 加载完成后列表直接停在底部，无跳转动画 | 依赖真实 NSScrollView 动画 |
| M2 | §1.3 视口顶部显示完整 turn 起始，不对半切 | 依赖真实布局 |
| M3 | §3.1 disclosure 默认折叠态视觉 | 纯视觉 |
| M4 | §3.7 反复展开/折叠不引起外部行跳动或 Markdown 闪烁 | 依赖 SwiftUI 动画 |
| M5 | §3.8 展开后点击过程消息内容不被 disclosure 吞掉 | 依赖 SwiftUI Button 命中测试 |
| M6 | §4.2 点击 Load earlier 后显示 spinner | 依赖真实 UI 交互 |
| M7 | §5.1 流式回复时列表自动跟随 | 依赖真实 NSScrollView |
| M8 | §5.2 向上滚动时列表不拉回底部 | 依赖真实 NSScrollView |
| M9 | §5.3 滚回底部后自动跟随恢复 | 依赖真实 NSScrollView |
| M10 | §5.4 滚动到历史时发送消息，新 turn 被拉入视口 | 依赖真实 AgentLoop + NSScrollView |
| M11 | §5.6 turn 结束后列表回到真实底部 | 依赖真实 NSScrollView |
| M12 | §5.8 首次打开时底部 turn 完整可见，无空白 | 纯视觉 |
| M13 | §5.9 窗口 resize 时无跳动/空白/重叠 | 依赖真实 NSScrollView |
| M14 | §5.10 代码块水平滚动不影响列表垂直滚动 | 依赖嵌套 NSScrollView |
| M15 | §5.11 短对话不能滚过内容末尾 | 依赖真实 NSScrollView |
| M16 | §6.6 长时间运行跨多工具/阶段时状态卡不闪烁 | 依赖真实 AgentLoop 时序 |
| M17 | §7.1/§7.2 用户消息 / 助手回复的渲染外观 | 纯视觉 |
| M18 | §8.3 翻页后发送消息，旧历史保持 + 新 turn 上 1/4 定位 | 依赖真实 AgentLoop |

## 覆盖率统计

- P0: 已覆盖 48 / 48
- P1: 已覆盖 40 / 40
- P2: 已覆盖 3 / 3
- **合计: 91 / 91**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 首次加载定位、turn 分组正确性、流式回复隔离、底部状态卡生命周期、
  翻页无跳动/无重复、会话切换安全、发送后定位常量、首屏遮罩编排、
  运行时状态持有方式、窗口上限与回收规则
- **P1**: Disclosure 摘要文本、activity 防闪烁、VM 投影发布、边界条件（空对话/单页）、
  服务层拼接逻辑、ScrollCoordinator 常量、大数据量下的回填与窗口有序性
- **P2**: `bottomAnchorID` 稳定性

## 跨平台说明

- Package 声明 macOS 14+ / iOS 17+，但消息列表基于 AppKit `NSScrollView`
  （`ScrollViewBottomTracker` / `AtBottomBox`），**滚动相关用例为 macOS 专属**
- `ConversationStateVM` / `AgentTurnVM` / `AgentActivityProjection` /
  `AgentTurnSummaryBuilder` 为纯 Foundation 逻辑，macOS 与 iOS 行为一致
- 所有被测类型标注 `@MainActor`，测试套件同样标注 `@MainActor` 并在主线程执行
- UI 测试夹具由 `MessageListBriefUITestingSupport`（仅 `#if DEBUG`）提供，
  通过 `--lumi-ui-testing-message-list-brief` 启动参数开启

## 测试执行

```bash
# 单元测试（只跑本包）
cd Packages/PluginMessageListBrief
swift test

# UI 测试（需要 Xcode 完整 fetch 完所有依赖）
xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListBriefUITests
```

UI 测试夹具由 `MessageListBriefUITestingSupport` 提供（仅 `DEBUG` 编译），
通过 `--lumi-ui-testing-message-list-brief` 启动参数开启；建议同时开启
`--lumi-ui-testing-isolated-storage` 避免污染用户数据库。

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件（ID 27 即「快速切换会话后旧数据泄漏」的回归）
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **README 同步** → 新增/修改测试用例后同步更新 README 测试矩阵的覆盖标记
