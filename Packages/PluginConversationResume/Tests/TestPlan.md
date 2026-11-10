# TestPlan — PluginConversationResume

## 包概述

PluginConversationResume 的实现包，提供对话异常中断后的「继续」能力；当前测试覆盖 43 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 43

核心组件（源码目录）:
- `Models/`
- `Managers/`
- `ViewModels/`
- `Capabilities/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationResumePlugin`
- `ResumeCoordinator`
- `ResumeViewModel`
- `ResumeBannerView`
- `ResumableTurnStore`
- `ResumeEligibility`
- `OrphanToolCallScanner`
- `OrphanToolCallRepair`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **孤儿 tool_call 扫描**（9 条）：由 `noToolCallsNoOrphans`、`missingResultIsOrphan`、`crossTurnResultDoesNotPair`、`repairRemovesOrphans` 等用例锁定——工具调用缺少配对的 tool result 才算孤儿，跨回合的 tool result 不能配对另一个回合的 tool_call。
- **回合记录存储**（12 条）：由 `marksRunning`、`marksFinished`、`survivesProcessRestart`、`corruptedFileFallsBackToEmpty`、`keepsOnlyLatestPerConversation` 等用例锁定——回合开始写「运行中」、结束时写终态，崩溃时最后一条停留在「运行中」，这正是区分用户主动停止与崩溃的唯一可靠依据。
- **可继续判定**（12 条）：由 `interruptedTurnIsResumable`、`cancelledTurnIsNotResumable`、`runningTurnIsNotResumable`、`finishedReplyIsNotResumable` 等用例锁定——判定必须依赖持久化记录而不是消息形状，用户主动停止与崩溃在消息层面完全无法区分。
- **协调器端到端**（7 条）：由 `completedTurnShowsNoBanner`、`crashedTurnShowsBanner`、`resumeRepairsOrphansAndStartsTurn`、`switchingConversationRefreshesState` 等用例锁定——回合正常完成后不显示提示，点击继续会补写占位 tool result 并启动新回合。
- **恢复按会话隔离**（3 条）：由 `otherConversationCanResumeWhileFirstIsRunning`、`repeatedResumeOfSameConversationIsStillBlocked`、`resumingStateIsReportedPerConversation` 等用例锁定——一个会话的恢复只抑制该会话自己的重复恢复动作，别的会话不受影响（**回归 #888**）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 孤儿 tool_call 扫描 | 没有工具调用时没有孤儿 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `noToolCallsNoOrphans` |
| 2 | 孤儿 tool_call 扫描 | 工具调用缺少 tool result 时被识别为孤儿 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `missingResultIsOrphan` |
| 3 | 孤儿 tool_call 扫描 | 已配对的工具调用不是孤儿 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pairedToolCallIsNotOrphan` |
| 4 | 孤儿 tool_call 扫描 | 部分配对时只报告未配对的那个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `partiallyPairedReportsOnlyUnpaired` |
| 5 | 孤儿 tool_call 扫描 | 跨回合的 tool result 不能配对另一个回合的 tool_call | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `crossTurnResultDoesNotPair` |
| 6 | 孤儿 tool_call 扫描 | 展示快照里已有结果的工具调用不算孤儿 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `snapshotWithResultIsNotOrphan` |
| 7 | 孤儿 tool_call 扫描 | 占位消息补上 tool_call_id 与错误标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `placeholderMessageCarriesToolCallID` |
| 8 | 孤儿 tool_call 扫描 | 占位正文明确说明结果未知 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `placeholderContentStatesOutcomeUnknown` |
| 9 | 孤儿 tool_call 扫描 | 修复后重新扫描不再有孤儿 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repairRemovesOrphans` |
| 10 | 回合记录存储 | 回合开始后写入运行中记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `marksRunning` |
| 11 | 回合记录存储 | 回合结束后记录终态，不再可继续 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `marksFinished` |
| 12 | 回合记录存储 | 用户取消的回合不会被标记为可继续 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledIsNotResumable` |
| 13 | 回合记录存储 | 终态记录保留回合开始时间 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `finishedKeepsStartedAt` |
| 14 | 回合记录存储 | 崩溃后重新打开存储仍能读出中断状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `survivesProcessRestart` |
| 15 | 回合记录存储 | 崩溃后正常收尾的回合不会复活 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `finishedTurnDoesNotResurrect` |
| 16 | 回合记录存储 | 存储文件损坏时退回空记录而不是崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `corruptedFileFallsBackToEmpty` |
| 17 | 回合记录存储 | 空文件不影响启动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyFileIsHarmless` |
| 18 | 回合记录存储 | 记录最后一个工具调用 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tracksLastToolCallID` |
| 19 | 回合记录存储 | 工具调用 ID 跨回合更新不被串写 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ignoresToolCallFromOtherTurn` |
| 20 | 回合记录存储 | 清除会话记录后不再可继续 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearRemovesRecord` |
| 21 | 回合记录存储 | 每个会话只保留最新一条记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsOnlyLatestPerConversation` |
| 22 | 可继续判定 | 中断的回合可以继续 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `interruptedTurnIsResumable` |
| 23 | 可继续判定 | 没有回合记录时不可继续 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingRecordIsNotResumable` |
| 24 | 可继续判定 | 用户主动停止的回合不可继续 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledTurnIsNotResumable` |
| 25 | 可继续判定 | 正常完成的回合不可继续 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedTurnIsNotResumable` |
| 26 | 可继续判定 | 回合仍在运行时不可继续 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runningTurnIsNotResumable` |
| 27 | 可继续判定 | 回合挂起时不可继续 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedTurnIsNotResumable` |
| 28 | 可继续判定 | 已产出最终回复的回合不可继续 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `finishedReplyIsNotResumable` |
| 29 | 可继续判定 | 没有用户消息的会话不可继续 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noUserMessageIsNotResumable` |
| 30 | 可继续判定 | 只有工具调用、没有最终回复的助手消息不算最终回复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantWithToolCallsIsNotFinalReply` |
| 31 | 可继续判定 | 带工具调用的助手消息即使有正文也不算最终回复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `assistantWithToolCallsAndTextIsNotFinalReply` |
| 32 | 可继续判定 | 空正文的助手消息不算最终回复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyAssistantIsNotFinalReply` |
| 33 | 可继续判定 | 错误消息不算最终回复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorAssistantIsNotFinalReply` |
| 34 | 协调器端到端 | 回合正常完成后不显示继续提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedTurnShowsNoBanner` |
| 35 | 协调器端到端 | 用户主动停止后不显示继续提示 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledTurnShowsNoBanner` |
| 36 | 协调器端到端 | 崩溃（无终态事件）后显示继续提示 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `crashedTurnShowsBanner` |
| 37 | 协调器端到端 | 点击继续会补写占位 tool result 并启动新回合 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeRepairsOrphansAndStartsTurn` |
| 38 | 协调器端到端 | 恢复后历史不再有孤儿 tool_call | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumeLeavesNoOrphans` |
| 39 | 协调器端到端 | 不可继续时点击继续不会有任何动作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumeIsNoopWhenNotResumable` |
| 40 | 协调器端到端 | 切换会话后状态按新会话重新判定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `switchingConversationRefreshesState` |
| 41 | 恢复按会话隔离 | A 恢复中时 B 仍可独立恢复（**回归 #888**） | 会话 A 的恢复回合挂起，B 有独立中断记录 | 对 B 执行恢复 | B 的回合被启动，不被 A 的全局锁拒绝 | P0 | ✅ 已覆盖 | `otherConversationCanResumeWhileFirstIsRunning` |
| 42 | 恢复按会话隔离 | 同一会话的重复恢复仍被抑制（**回归 #888 护栏**） | 某会话的恢复回合挂起 | 对同一会话再次恢复 | 不会并发启动第二个回合 | P0 | ✅ 已覆盖 | `repeatedResumeOfSameConversationIsStillBlocked` |
| 43 | 恢复按会话隔离 | 恢复状态按会话反映，别的会话不被标记为恢复中（**回归 #888 护栏**） | 会话 A 正在恢复 | 切到会话 B 并读取状态 | B 的 `isResuming` 为 false，按钮不被禁用 | P0 | ✅ 已覆盖 | `resumingStateIsReportedPerConversation` |

> 说明：全部 **43 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 17 / 17
- P1: 已覆盖 24 / 24
- P2: 已覆盖 2 / 2
- **合计: 43 / 43**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（17 条）
- **P1**: 其余功能性用例（24 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 43 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationResume
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
