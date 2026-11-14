# TestPlan — PluginSubagent

## 包概述

PluginSubagent 的实现包：子代理委托（#1313）的隐藏子会话管道、`run_subagent` 工具、工具栏活动指示器与委托时间线卡片。当前测试覆盖 18 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 18

核心组件（源码目录）:
- `SubagentConversationBridge.swift`
- `RunSubagentTool.swift`
- `SubagentPlugin.swift`
- `SubagentActivityViewModel.swift`
- `Models/SubagentTimeline.swift`
- `Renderers/SubagentCardRenderer.swift`
- `Views/SubagentCardView.swift`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `SubagentConversationError`
- `SubagentConversationBridge`
- `RunSubagentTool`
- `SubagentPlugin`
- `SubagentActivityViewModel`
- `SubagentTimeline`
- `SubagentCardRenderer`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **SubagentChildConversation**（7 条）：由 `childIsHiddenFromListAndKeepsSelection`、`childInheritsParentProjectModelAndAutomation`、`unboundParentDoesNotBindChildToCurrentProject` 等用例锁定。子会话以 `parentConversationID` 标记归属：不进入会话列表缓存、不改变选中、不发 `.created`；继承父会话的项目绑定（含「明确不绑定」，不得回退当前项目）、模型与自动化等级；消息与父会话完全隔离；删除父会话时连带取消回合、清消息、删工具记录、删库行。
- **SubagentActivityViewModel**（8 条）：由 `onlySubagentJobsCountTowardBadge`、`staleEventsAfterConversationSwitchAreDropped`、`tickingFollowsActiveJobsAndSilentDurationAdvances` 等用例锁定。只有当前选中会话的 `run_subagent` Job 计入徽标；其他会话与切换后的晚到事件不得写回状态；运行中驱动计时、全部终态后停止（ToolActivity #960 同款回归）。
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

> 说明：全部 **18 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 7 / 7
- P2: 已覆盖 1 / 1
- **合计: 18 / 18**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（7 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 18 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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