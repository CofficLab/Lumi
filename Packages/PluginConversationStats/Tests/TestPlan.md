# TestPlan — PluginConversationStats

## 包概述

PluginConversationStats 的实现包，包含 3 个主要类型；当前测试覆盖 8 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 8

核心组件（源码目录）:
- `Observers/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentTurnStatusToolbarView`
- `ConversationAgentTurnCountPlugin`
- `AgentTurnStatusObserver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **Observer**（1 条）：由 `agentTurnObserverLifecycle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（3 条）：由 `statisticsPackageCanBeImported`、`toolbarStatesForwardTypedEvents`、`agentTurnStateSeparatesObserversAndMakesCancellationIdempotent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Agent turn 工具栏 Running 判定**（4 条）：由 `suspendedDoesNotShowRunning`、`runningShowsRunning`、`idleAndTerminalDoNotShowRunning`、`nilConversationDoesNotShowRunning` 锁定；工具栏只在 `state(for:) == .running` 时显示 Running，挂起等待用户回答（`.suspended`）时不得亮 Running，且不得改动全局 `isRunning` 语义（issue #802）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | Observer | agent-turn observer forwards every event's conversation and stops after cancellation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `agentTurnObserverLifecycle` |
| 2 | 综合 | statisticsPackageCanBeImported | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statisticsPackageCanBeImported` |
| 3 | 综合 | toolbarStatesForwardTypedEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarStatesForwardTypedEvents` |
| 4 | 综合 | agentTurnStateSeparatesObserversAndMakesCancellationIdempotent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `agentTurnStateSeparatesObserversAndMakesCancellationIdempotent` |
| 5 | 工具栏 Running 判定 | 挂起等待用户回答时不得显示 Running（即使 isRunning 为真）（**回归 #802**） | mock 的 state=.suspended 且 isRunning=true | 调用 `showsRunning` | 返回 false | P0 | ✅ 已覆盖 | `suspendedDoesNotShowRunning` |
| 6 | 工具栏 Running 判定 | 真正执行 LLM/工具时显示 Running | state=.running 且 isRunning=true | 调用 `showsRunning` | 返回 true | P1 | ✅ 已覆盖 | `runningShowsRunning` |
| 7 | 工具栏 Running 判定 | 空闲与终态都不显示 Running | state 为 idle/completed/failed/cancelled | 调用 `showsRunning` | 均返回 false | P1 | ✅ 已覆盖 | `idleAndTerminalDoNotShowRunning` |
| 8 | 工具栏 Running 判定 | 没有选中会话时不显示 Running | conversationID 为 nil | 调用 `showsRunning` | 返回 false | P1 | ✅ 已覆盖 | `nilConversationDoesNotShowRunning` |

> 说明：全部 **8 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> **#802 变异验证**：对 `AgentTurnStatusToolbarView.showsRunning` 注入 2 个变异均被相应用例捕获——M1 还原原始 bug（用 `agentLoop.isRunning(for:)`，其语义含 `.awaitingUser`），被 `suspendedDoesNotShowRunning` 唯一捕获（mock 令 isRunning=true 且 state=.suspended，断言 false 失败）；M2 改为 `state(for:) != .suspended`（空闲/终态也亮灯），被 `idleAndTerminalDoNotShowRunning` 唯一捕获（idle/completed/failed/cancelled 四处断言失败），此时挂起与运行用例仍通过，证明两个守卫各自独立。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 7 / 7
- P2: 已覆盖 0 / 0
- **合计: 8 / 8**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（7 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 8 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationStats
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
