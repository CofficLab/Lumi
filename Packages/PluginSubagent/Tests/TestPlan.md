# TestPlan — PluginSubagent

## 包概述

PluginSubagent 的实现包：子代理委托（#1313）的隐藏子会话管道、`run_subagent` 工具、工具栏活动指示器与委托时间线卡片；#1328 增加的树内寻址、`list_subagents` / `send_subagent_message`、收件箱协调器与活动优先的工具栏。当前测试覆盖 58 条用例。

平台: macOS 14+, iOS 17+
测试文件: 7 个，用例总数: 58

核心组件（源码目录）:
- `SubagentConversationBridge.swift`
- `RunSubagentTool.swift`
- `ListSubagentsTool.swift`
- `SendSubagentMessageTool.swift`
- `SubagentInboxCoordinator.swift`
- `SubagentPlugin.swift`
- `SubagentActivityViewModel.swift`
- `SubagentActivityToolbarButton.swift`
- `Models/SubagentIdentity.swift`
- `Models/SubagentRegistry.swift`
- `Models/SubagentTimeline.swift`
- `Renderers/SubagentCardRenderer.swift`
- `Views/SubagentCardView.swift`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `SubagentConversationError`
- `SubagentConversationBridge`
- `SubagentIdentity`
- `SubagentRegistry`
- `RunSubagentTool`
- `ListSubagentsTool`
- `SendSubagentMessageTool`
- `SubagentInboxCoordinator`
- `SubagentPlugin`
- `SubagentActivityViewModel`
- `SubagentTimeline`
- `SubagentCardRenderer`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **SubagentChildConversation**（7 条）：由 `childIsHiddenFromListAndKeepsSelection`、`childInheritsParentProjectModelAndAutomation`、`unboundParentDoesNotBindChildToCurrentProject` 等用例锁定。子会话以 `parentConversationID` 标记归属：不进入会话列表缓存、不改变选中、不发 `.created`；继承父会话的项目绑定（含「明确不绑定」，不得回退当前项目）、模型与自动化等级；消息与父会话完全隔离；删除父会话时连带取消回合、清消息、删工具记录、删库行。
- **SubagentIdentity**（11 条）：由 `acceptsValidNames`、`rejectsInvalidNames`、`resolveThrowsForReservedName`、`legacyPayloadWithoutNameDecodes` 等用例锁定。名字 3-32 位、小写字母开头、只含小写字母/数字/连字符；`lead` 保留给根会话；重名拒绝；默认名取第一个空位；名字随卡片载荷往返，旧载荷无名字时解码为 nil 且历史卡片仍可读。
- **SubagentRegistry**（8 条）：由 `rebuildsMembersFromPersistedCards`、`rejectsUnknownAndForeignNames`、`deletedChildIsNotAddressable`、`mergesJobAndAgentLoopState` 等用例锁定。成员只从持久化卡片与 `parentConversationID` 派生，新建实例即可重建；寻址严格限制在当前树内，未知/跨树/已删除/重名目标一律拒绝；无名字的历史卡片保留展示但不可寻址。
- **ListSubagentsTool**（7 条）：由 `listsLeadAndMembers`、`childCallerSeesItselfAndSiblings`、`legacyCardIsNotAddressable`、`toolMetadata` 等用例锁定。输出 lead 与成员的实时状态、耗时、任务标签与投递方式；从子代理视角发起时标明「你是谁」；缺少上下文或会话已不存在时抛错；工具声明为只读并发、低风险。
- **SendSubagentMessageTool**（8 条）：由 `queueDeliversWithoutStartingTurn`、`followupWakesIdleTarget`、`followupWaitsForRunningTurnExactlyOnce`、`rejectsInvalidTargets`、`childToolAllowlist` 等用例锁定。`queue` 只写入不启动回合并恢复自动回复状态；`followup` 对空闲目标立即唤醒、对运行中目标等终态且恰好一次；子代理可联系 lead 与兄弟；自发、未知、跨树、重名目标与非法参数均抛错；子会话工具表显式放行通信工具但仍排除 `run_subagent`。
- **SubagentActivityViewModel**（14 条）：由 `onlySubagentJobsCountTowardBadge`、`staleEventsAfterConversationSwitchAreDropped`、`tickingFollowsActiveJobsAndSilentDurationAdvances`、`attentionGroupingOrdersWaitingThenFailed`、`itemsExposeIdentityAndChildActivity` 等用例锁定。只有当前选中会话的 `run_subagent` Job 计入徽标；其他会话与切换后的晚到事件不得写回状态；运行中驱动计时、全部终态后停止（ToolActivity #960 同款回归）。活动层从卡片载荷取名字、从子会话 Job 取当前工具与工具数、从收件箱取待读取消息数；排序为等待/失败 → 运行中 → 已结束；胶囊颜色按失败 > 等待 > 运行 > 空闲降级。
- **SubagentTimeline**（3 条）：由 `payloadRoundTrip`、`corruptedPayloadDecodesToNil`、`messageShape` 锁定。卡片载荷只存标识（label、父/子会话 ID、jobID），经 metadata 编解码往返一致；损坏载荷解码为 nil 走回退视图；卡片消息为系统角色、携带渲染标识且被 `isTimelineEvent` 排除出 LLM 上下文。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | SubagentChildConversation | 子会话不进入列表、不改变选中、不发 created 事件 | 真实 ConversationStore + ConversationManager，已创建根会话 | 经桥接创建子会话 | 列表只含根会话；选中不变；无 `.created(child)`；库行 parentConversationID 指向根 | P0 | ✅ 已覆盖 | `childIsHiddenFromListAndKeepsSelection` |
| 2 | SubagentChildConversation | 子会话继承父会话的项目、模型与自动化等级 | 根会话绑定项目与模型，全局自动化为 chat，根会话覆盖为 autonomous | 经桥接创建子会话 | 子会话 projectPath/modelID 与根一致；automationLevel(for: child) 为 autonomous | P1 | ✅ 已覆盖 | `childInheritsParentProjectModelAndAutomation` |
| 3 | SubagentChildConversation | 父会话明确不绑定项目时，子会话不回退到当前项目 | 当前项目存在，根会话以 binding=.none 创建 | 经桥接创建子会话 | 子会话 projectPath 为 nil | P0 | ✅ 已覆盖 | `unboundParentDoesNotBindChildToCurrentProject` |
| 4 | SubagentChildConversation | 子会话消息不进入父会话历史，父会话消息不进入子会话历史 | 父子会话各插入消息 | 分别读取 messagesForLLM | 两侧历史只含各自消息 | P0 | ✅ 已覆盖 | `childMessagesStayOutOfParentHistory` |
| 5 | SubagentChildConversation | 删除父会话连带删除子会话库行并清空子会话消息 | 子会话已有消息 | deleteConversation(父) 后等待异步清理 | 父子库行均消失；子会话消息为空 | P0 | ✅ 已覆盖 | `deletingParentCascadesChildRowAndMessages` |
| 6 | SubagentChildConversation | 删除父会话连带取消子会话回合并删除其工具调用记录 | 注入 AgentLoop/ToolManager 替身 | deleteConversation(父) 后等待异步清理 | 替身收到父与子的 cancelTurn/deleteToolCalls | P0 | ✅ 已覆盖 | `deletingParentCancelsChildTurnAndClearsToolCalls` |
| 7 | SubagentChildConversation | 父会话不存在时抛出 parentConversationNotFound | 空会话管理器 | 用不存在的父 ID 创建子会话 | 抛出 SubagentConversationError.parentConversationNotFound | P1 | ✅ 已覆盖 | `missingParentThrows` |
| 8 | SubagentActivityViewModel | run_subagent 计入徽标，其他工具不计入 | 选中会话存在，注入 Job 事件替身 | 发送两个 run_subagent 与一个 read_file 的 started 事件 | activeCount 为 2，只含两个子代理 Job | P1 | ✅ 已覆盖 | `onlySubagentJobsCountTowardBadge` |
| 9 | SubagentActivityViewModel | Job 进入终态后退出运行中并进入已结束列表 | 子代理 Job 运行中 | 发送 completed 事件 | activeCount 归零；已结束列表含该 Job；不判为失败 | P1 | ✅ 已覆盖 | `terminalJobsLeaveActiveAndEnterFinished` |
| 10 | SubagentActivityViewModel | 执行抛异常与结构化错误结果都视为失败 | 注入 failed 事件与 isError 的 completed 结果 | 查询 isFailed | 两种形态均判为失败 | P0 | ✅ 已覆盖 | `failureShapesAreRecognized` |
| 11 | SubagentActivityViewModel | 其他会话的子代理事件不得写入当前会话状态 | 选中会话 A | 发送会话 B 的 started 事件 | jobs 为空，指示器不显示外部委托 | P0 | ✅ 已覆盖 | `eventsFromOtherConversationsAreIgnored` |
| 12 | SubagentActivityViewModel | 切换会话后旧会话晚到事件被丢弃，列表重读为新会话 | 旧会话有运行中子代理 | 切换到新会话后发送旧 Job 的 progress 事件 | 切换后列表清空；晚到事件不得写回新会话状态 | P0 | ✅ 已覆盖 | `staleEventsAfterConversationSwitchAreDropped` |
| 13 | SubagentActivityViewModel | 恢复批量快照补进列表 | 工具管理器持有已完成的 Job 快照 | 发送 restored 事件 | 已结束列表含恢复的 Job | P1 | ✅ 已覆盖 | `restoredEventRefreshesSnapshot` |
| 14 | SubagentActivityViewModel | 标签取 description 参数，缺失或空白回退默认文案 | 三个 Job 分别带有/空白/缺失 description | 查询 label(for:) | 有值取 description；空白与缺失回退本地化默认文案 | P2 | ✅ 已覆盖 | `labelFallsBackWhenDescriptionMissing` |
| 15 | SubagentActivityViewModel | 运行中必须驱动计时刷新，全部终态后停止；静默期耗时随时间增长 | 注入可控时钟 | started 后推进时钟并 tick，再 completed 后继续推进 | 运行中 isTicking 且耗时增长；终态后停止计时、耗时固定 | P0 | ✅ 已覆盖 | `tickingFollowsActiveJobsAndSilentDurationAdvances` |
| 16 | SubagentTimeline | 卡片载荷可编码进 metadata 并原样解码 | 构造含 label、父/子会话 ID、jobID 的载荷 | metadata 编码后解码 | 解码载荷与原始载荷相等 | P1 | ✅ 已覆盖 | `payloadRoundTrip` |
| 17 | SubagentTimeline | 损坏或缺失的载荷解码为 nil 而不崩溃 | metadata 为空或非法 JSON | decodePayload | 返回 nil，渲染走回退视图 | P0 | ✅ 已覆盖 | `corruptedPayloadDecodesToNil` |
| 18 | SubagentTimeline | 时间线卡片消息携带系统角色、渲染标识与载荷 | 构造载荷 | 生成卡片消息 | role 为 system；renderKind/preferredRendererID 指向子代理渲染器；isTimelineEvent 为真；正文含 label | P1 | ✅ 已覆盖 | `messageShape` |
| 19 | SubagentIdentity | 合法名字：3-32 位、小写字母开头、允许数字与连字符 | 一组合法名字 | 调用名字校验 | 全部通过 | P1 | ✅ 已覆盖 | `acceptsValidNames` |
| 20 | SubagentIdentity | 非法名字：长度、大小写、首字符与字符集 | 一组非法名字 | 调用名字校验 | 全部拒绝 | P0 | ✅ 已覆盖 | `rejectsInvalidNames` |
| 21 | SubagentIdentity | 没有子代理时默认 agent-1 | 已有名字为空 | defaultName(existing:) | 返回 agent-1 | P1 | ✅ 已覆盖 | `defaultNameStartsAtOne` |
| 22 | SubagentIdentity | 默认名取第一个空位，不因中间空号继续增长 | 已有 agent-1、agent-3 | defaultName(existing:) | 返回 agent-2 | P1 | ✅ 已覆盖 | `defaultNameUsesFirstFreeSlot` |
| 23 | SubagentIdentity | 未提供名字时使用默认名 | 已有 agent-1 | resolve(requested: nil, existing:) | 返回 agent-2 | P1 | ✅ 已覆盖 | `resolveWithoutRequestedUsesDefault` |
| 24 | SubagentIdentity | 提供合法且唯一的名字时原样返回 | 已有 agent-1 | resolve(requested: "explorer", existing:) | 返回 explorer | P1 | ✅ 已覆盖 | `resolveKeepsUniqueRequestedName` |
| 25 | SubagentIdentity | 提供非法名字时抛出 invalidName | requested 为 "Explorer" | resolve(requested:existing:) | 抛出 SubagentIdentityError.invalidName | P0 | ✅ 已覆盖 | `resolveThrowsForInvalidName` |
| 26 | SubagentIdentity | lead 是根代理保留名，不能分配给子代理 | requested 为 "lead" | resolve(requested:existing:) | 抛出 SubagentIdentityError.reservedName | P0 | ✅ 已覆盖 | `resolveThrowsForReservedName` |
| 27 | SubagentIdentity | 提供同名子代理时抛出 duplicateName | 已有 explorer | resolve(requested: "explorer", existing:) | 抛出 SubagentIdentityError.duplicateName | P0 | ✅ 已覆盖 | `resolveThrowsForDuplicateName` |
| 28 | SubagentIdentity | 名字随卡片载荷往返 | 构造含 name 的载荷 | 编码后再解码 | 解码载荷的 name 与原值一致 | P1 | ✅ 已覆盖 | `payloadRoundTripsName` |
| 29 | SubagentIdentity | 旧载荷没有 name 字段时解码为 nil，历史委托仍可读 | 无 name 字段的旧 JSON | decodePayload | name 为 nil，其余字段正常解码 | P2 | ✅ 已覆盖 | `legacyPayloadWithoutNameDecodes` |
| 30 | SubagentRegistry | 从根会话的委托卡片重建成员与 Job 关联 | 夹具创建根会话与两张委托卡片 | snapshot(for: root) | 成员含名字、子会话 ID、Job ID，按创建时间排序 | P0 | ✅ 已覆盖 | `rebuildsMembersFromPersistedCards` |
| 31 | SubagentRegistry | 子会话视角能解析 lead 与兄弟代理 | 根会话下有两个带名字的子会话 | resolve(name:from: child) | lead 指向根会话；兄弟解析到各自子会话 | P1 | ✅ 已覆盖 | `resolvesLeadAndSiblingsFromChild` |
| 32 | SubagentRegistry | 新建注册表实例仍能从同一份持久化数据重建 | 同一份持久化卡片数据 | 新建 SubagentRegistry 后 snapshot | 成员与旧实例一致，不依赖内存缓存 | P1 | ✅ 已覆盖 | `rebuildsInFreshRegistryInstance` |
| 33 | SubagentRegistry | 未知名字与另一棵树的成员都被拒绝 | 当前树与其他树各有一个子代理 | resolve(name:from:) | 均抛出 unknownName | P0 | ✅ 已覆盖 | `rejectsUnknownAndForeignNames` |
| 34 | SubagentRegistry | 已删除的子会话不参与寻址 | 子会话已被删除 | snapshot / resolve | 成员不含该子会话，按名字解析失败 | P0 | ✅ 已覆盖 | `deletedChildIsNotAddressable` |
| 35 | SubagentRegistry | 没有名字的历史卡片保留展示但不可寻址 | 插入无 name 的旧卡片 | snapshot | 成员仍在列表中，isAddressable 为 false | P2 | ✅ 已覆盖 | `legacyCardsStayVisibleButAreNotAddressable` |
| 36 | SubagentRegistry | 同一棵树内出现重名数据时拒绝猜测目标 | 持久化数据出现两个同名成员 | resolve(name:from:) | 抛出 ambiguousName | P0 | ✅ 已覆盖 | `duplicateNamesAreAmbiguous` |
| 37 | SubagentRegistry | 运行状态合并 Job 状态与 AgentLoop 活跃状态 | 注入 Job 快照与运行中的子会话 | snapshot | isRunning/isActive/jobStatus 与注入一致 | P1 | ✅ 已覆盖 | `mergesJobAndAgentLoopState` |
| 38 | ListSubagentsTool | 列出 lead 与子代理的实时状态、时长和投递方式 | 固定时钟；一个运行中、一个已完成成员 | executeResult | 表格含 lead 行与两成员；状态、耗时、messageable/resumable 正确 | P1 | ✅ 已覆盖 | `listsLeadAndMembers` |
| 39 | ListSubagentsTool | 没有名字的历史卡片标记为不可寻址 | 插入无 name 的旧卡片 | executeResult | 行显示 (unnamed) 与 not addressable | P2 | ✅ 已覆盖 | `legacyCardIsNotAddressable` |
| 40 | ListSubagentsTool | 子代理视角知道自己是谁并能看到兄弟 | 从子会话调用工具 | executeResult | 页脚标明调用方名字，列表含其他成员 | P1 | ✅ 已覆盖 | `childCallerSeesItselfAndSiblings` |
| 41 | ListSubagentsTool | 空树只显示 lead 与创建提示 | 根会话没有委托 | executeResult | 只有 lead 行，并提示暂无子代理 | P2 | ✅ 已覆盖 | `emptyTree` |
| 42 | ListSubagentsTool | 缺少会话上下文时抛错而不是返回空表 | 以无 context 调用工具 | execute(arguments:) | 抛出 ToolExecutionError | P1 | ✅ 已覆盖 | `missingContextThrows` |
| 43 | ListSubagentsTool | 调用方会话已不存在时抛错 | 传入不存在的会话 ID | executeResult | 抛错而不是返回空表 | P0 | ✅ 已覆盖 | `missingConversationThrows` |
| 44 | ListSubagentsTool | 工具元数据：只读并发、低风险、提示先查名字 | 构造工具 | 读取 capability、风险与 schema | parallelReadOnly、low 风险，描述提示先查名字再发消息 | P2 | ✅ 已覆盖 | `toolMetadata` |
| 45 | SendSubagentMessageTool | queue 只写入消息，不启动回合，并恢复自动回复状态 | 目标空闲且未抑制自动回复 | 发送 queue 消息 | 不调用 runTurn；自动回复恢复；待读取数为 1；消息带来源 metadata | P0 | ✅ 已覆盖 | `queueDeliversWithoutStartingTurn` |
| 46 | SendSubagentMessageTool | followup 到空闲目标会立即启动回合 | 目标空闲 | 发送 followup 给 editor | runTurn 调用列表为 [editor] | P0 | ✅ 已覆盖 | `followupWakesIdleTarget` |
| 47 | SendSubagentMessageTool | followup 到运行中目标要等终态，重复终态只唤醒一次 | 目标运行中 | 发送 followup 后连续发两次 completed | 首次终态后唤醒一次，重复事件不再启动 | P0 | ✅ 已覆盖 | `followupWaitsForRunningTurnExactlyOnce` |
| 48 | SendSubagentMessageTool | queue 到运行中目标在回合结束后也不会被唤醒 | 目标运行中 | 发送 queue 后发 completed | 不调用 runTurn | P0 | ✅ 已覆盖 | `queueDoesNotWakeOnTurnEnd` |
| 49 | SendSubagentMessageTool | 子代理可以联系 lead 与兄弟，来源名是它自己 | 从 explorer 子会话调用 | 分别发给 lead 与 editor | 消息落入目标会话，senderName 为 explorer | P1 | ✅ 已覆盖 | `childCanMessageLeadAndSibling` |
| 50 | SendSubagentMessageTool | 不能给自己、未知名字、跨树成员或重名目标发消息 | 当前树、其他树与重名数据 | 逐个发送 | 均抛错；根会话消息数不变 | P0 | ✅ 已覆盖 | `rejectsInvalidTargets` |
| 51 | SendSubagentMessageTool | 缺少参数、非法模式或会话不存在时抛错 | 构造非法调用 | executeResult | 分别抛错并给出可纠正的提示 | P1 | ✅ 已覆盖 | `rejectsInvalidArguments` |
| 52 | SendSubagentMessageTool | 子会话工具表显式放行通信工具，但仍排除委托工具 | 构造只读与副作用工具 | SubagentToolPolicy.childTools | 通信工具保留、run_subagent 与其余副作用工具被排除 | P0 | ✅ 已覆盖 | `childToolAllowlist` |
| 53 | SubagentActivityViewModel | 活动行带出名字、当前工具与已完成工具数 | 卡片载荷 + 子会话两个 Job | 读取 items | name/currentToolName/completedToolCount 正确 | P1 | ✅ 已覆盖 | `itemsExposeIdentityAndChildActivity` |
| 54 | SubagentActivityViewModel | 待读取消息数来自注入的收件箱 | 注入对目标返回 2 的 pending provider | 读取 item.pendingMessageCount | 为 2 | P1 | ✅ 已覆盖 | `pendingMessageCountComesFromInjectedProvider` |
| 55 | SubagentActivityViewModel | 注意力优先：等待在前、失败其次、运行与结束各归组 | 等待/失败/运行/已完成各一个 | 读取分组与 status | attention 为 [waiting, failed]、running 为 [running]、finished 为 [finished]、status 为 failure | P1 | ✅ 已覆盖 | `attentionGroupingOrdersWaitingThenFailed` |
| 56 | SubagentActivityViewModel | 胶囊状态按失败、等待、运行、空闲降级 | 依次注入不同状态组合 | 读取 status | idle → running → waiting → idle | P1 | ✅ 已覆盖 | `capsuleStatusFollowsPriority` |
| 57 | SubagentActivityViewModel | 卡片晚到也能补上身份；没有名字的旧委托显示 unnamed | 先发 started 事件，后插入卡片 | 等待异步载荷读取 | childConversationID 补上；无名字时 name(for:) 为 (unnamed) | P1 | ✅ 已覆盖 | `lateCardEnrichesIdentity` |
| 58 | SubagentActivityViewModel | 子会话工具事件刷新活动行但不进入父会话徽标 | 父 Job 运行中且已关联子会话 | 发送子会话 started/completed 事件 | 当前工具与工具数更新；activeCount 恒为 1 | P0 | ✅ 已覆盖 | `childToolEventsRefreshItemsOnly` |

> 说明：全部 **58 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 26 / 26
- P1: 已覆盖 26 / 26
- P2: 已覆盖 6 / 6
- **合计: 58 / 58**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得等失效类信号的用例（26 条）
- **P1**: 其余功能性用例（26 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 58 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginSubagent
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」