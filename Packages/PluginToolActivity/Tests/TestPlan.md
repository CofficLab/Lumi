# TestPlan — PluginToolActivity

## 包概述

PluginToolActivity 的实现包，包含 3 个主要类型；当前测试覆盖 7 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 7

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ToolActivityPlugin`
- `ToolActivityToolbarView`
- `ToolActivityViewModel`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ToolActivityPlugin**（2 条）：由 `metadata`、`disableRemovesToolbarItem` 锁定工具栏项生命周期；改动该模块时优先跑对应测试文件。
- **ToolActivityViewModel**（5 条）：由 `restoredEventRefreshesOpenPanel`、`completedErrorResultShowsFailedStatus`、`completedSuccessResultKeepsCompletedStatus` 锁定历史任务恢复与结构化错误结果的展示行为；由 `tickingFollowsActiveJobs`、`silentRunningJobDurationAdvancesThenFreezes` 锁定运行中任务耗时的持续刷新与终态固定（**回归 #960**）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ToolActivityPlugin | Registers as a chat plugin | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metadata` |
| 2 | ToolActivityViewModel | 恢复批量快照后，打开中的面板刷新出历史任务（**回归 #544**） | 已选中一个会话，面板处于打开状态 | 收到 `.restored([job])` 事件 | `jobs` 中出现该终态任务 | P1 | ✅ 已覆盖 | `restoredEventRefreshesOpenPanel` |
| 3 | ToolActivityPlugin | 运行时停用后移除工具栏按钮，重新启用时恢复（**回归 #879**） | 内核注册 ChatSection/Conversation/ToolManager Provider | `onBoot` → `onDisable` → 再次 `onBoot` | 首次与再次启用都有 bar item；停用后没有 | P0 | ✅ 已覆盖 | `disableRemovesToolbarItem` |
| 4 | ToolActivityViewModel | completed 但 `isError=true` 的结果显示为失败（**回归 #1005**） | 已选中会话，面板监听事件流 | 收到 `.completed(result.isError: true)` 事件 | `isErroredResult` 为 true，状态文案为 `Failed` 而非 `Completed` | P1 | ✅ 已覆盖 | `completedErrorResultShowsFailedStatus` |
| 5 | ToolActivityViewModel | completed 且 `isError=false` 的结果保持 Completed | 已选中会话，面板监听事件流 | 收到 `.completed(result.isError: false)` 事件 | `isErroredResult` 为 false，状态文案为 `Completed` | P1 | ✅ 已覆盖 | `completedSuccessResultKeepsCompletedStatus` |
| 6 | ToolActivityViewModel | 运行中的任务启动计时刷新，进入终态后停止（**回归 #960**） | 已选中会话，无任务 | 收到 `.started` 事件，再收到 `.completed` 事件 | `.started` 后 `isTicking == true`；全部终态后 `isTicking == false` | P0 | ✅ 已覆盖 | `tickingFollowsActiveJobs` |
| 7 | ToolActivityViewModel | 静默运行中的任务耗时随当前时间增长，终态后固定（**回归 #960**） | 已选中会话，注入可控时钟 | `.started` 后无任何事件，仅推进时钟；随后 `.completed` 并继续推进时钟 | 耗时从 0 增长到 5s；终态后固定为 12s，不再随世界时间变化 | P1 | ✅ 已覆盖 | `silentRunningJobDurationAdvancesThenFreezes` |

> 说明：全部 **7 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 5 / 5
- P2: 已覆盖 0 / 0
- **合计: 7 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（5 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 7 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginToolActivity
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
