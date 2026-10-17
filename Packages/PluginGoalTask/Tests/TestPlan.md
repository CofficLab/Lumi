# TestPlan — PluginGoalTask

## 包概述

GoalTaskPlugin 目标导向的任务管理插件，为 Lumi 提供 Goal（目标）+ Task（任务）两层结构的任务追踪能力。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 20

核心组件（源码目录）:
- `Hooks/`
- `Models/`
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `GoalTaskPlugin`
- `GoalTaskPluginSupport`
- `GoalTaskTimeline`
- `GoalTaskTurnFinishedHook`
- `Goal`
- `GoalDisplayItem`
- `GoalListItem`
- `GoalTaskDisplayItem`
- `GoalTask`
- `GoalChangeCenter`
- `GoalTaskConversationBridge`
- `GoalForkCoordinator`
- `GoalStateManager`
- `AddTasksToGoalV2Tool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **GoalStateManager**（9 条）：由 `testCreateGoal`、`testUpdateTaskStatusDerivesGoalStatus`、`testUpdateGoalStatusBlocked` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskTimeline**（2 条）：由 `continuationMessage`、`limitReachedMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskV2**（9 条）：由 `preservesPluginIdentityAndPolicy`、`preservesLegacyToolNamesAndRequiredArguments`、`createGoalUsesExecutionConversation` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | GoalStateManager | Create goal with tasks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCreateGoal` |
| 2 | GoalStateManager | Update task status auto-derives goal status | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateTaskStatusDerivesGoalStatus` |
| 3 | GoalStateManager | Update goal status to blocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateGoalStatusBlocked` |
| 4 | GoalStateManager | Marking an incomplete goal as failed preserves the goal and tasks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFailedGoalPreservesTasks` |
| 5 | GoalStateManager | Task progress resets the automatic continuation budget | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContinuationBudgetReset` |
| 6 | GoalStateManager | Fetch goals by conversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFetchGoals` |
| 7 | GoalStateManager | Create then immediately fetch returns the goal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCreateThenFetchImmediately` |
| 8 | GoalStateManager | Sidebar hides when all goals reach terminal state | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSidebarHidesWhenAllDone` |
| 9 | GoalStateManager | Sidebar visible when work is in progress | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSidebarVisibleWhenInProgress` |
| 10 | GoalTaskTimeline | continuation message is a timeline event with progress metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `continuationMessage` |
| 11 | GoalTaskTimeline | limit message explains why automatic continuation stopped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `limitReachedMessage` |
| 12 | GoalTaskV2 | preservesPluginIdentityAndPolicy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesPluginIdentityAndPolicy` |
| 13 | GoalTaskV2 | preservesLegacyToolNamesAndRequiredArguments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesLegacyToolNamesAndRequiredArguments` |
| 14 | GoalTaskV2 | create_goal 使用 Agent 回合会话而非 UI 当前选中会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createGoalUsesExecutionConversation` |
| 15 | GoalTaskV2 | Goal 会话 Bridge 收到切换后的新会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `goalConversationBridgeUsesUpdatedSelection` |
| 16 | GoalTaskV2 | create_goal 没有执行上下文时拒绝写入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createGoalRejectsContextlessExecution` |
| 17 | GoalTaskV2 | create_goal 返回 Goal ID，后续工具可用它 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createGoalExposesGoalId` |
| 18 | GoalTaskV2 | update_goal_status 可以用标题解析 goal_id（id 丢失时的恢复路径） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `goalIdResolvesByTitle` |
| 19 | GoalTaskV2 | 省略 goal_id 时自动解析会话内唯一活跃 goal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `omittedGoalIdResolvesActiveGoal` |
| 20 | GoalTaskV2 | goal not found 错误附本会话候选列表（可恢复） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownGoalIdListsCandidates` |

> 说明：全部 **20 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 18 / 18
- P2: 已覆盖 0 / 0
- **合计: 20 / 20**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（18 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 20 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginGoalTask
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
