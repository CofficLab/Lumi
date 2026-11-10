# TestPlan — PluginAgentLoopRetry

## 包概述

PluginAgentLoopRetry 的实现包，包含 3 个主要类型；当前测试覆盖 12 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 12

核心组件（源码目录）:
- `Managers/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentLoopRetryPlugin`
- `AgentLoopRetryCoordinator`
- `AgentLoopRetryTimeline`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentLoopRetryCoordinator**（3 条）：由 `deletionDuringBackoffCancelsRetry`、`doesNotRetryConversationDeletedDuringBackoff`、`publishesRetryLifecycleEvents` 锁定；退避等待期间删除会话必须取消睡眠任务，启动重试前必须确认会话仍存在，并且每次调度 / 放弃重试都要发布生命周期事件（**#935**）。
- **AgentLoopRetryPlugin**（5 条）：由 `retriesTransientFailureThreeTimes`、`doesNotRetryNonRetryableFailure`、`resetsAfterSuccessfulRetry` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentLoopRetryPlugin | 可重试失败最多自动重试三次并记录完整时间线 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retriesTransientFailureThreeTimes` |
| 2 | AgentLoopRetryPlugin | 不可重试失败不会启动重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRetryNonRetryableFailure` |
| 3 | AgentLoopRetryPlugin | 完成后新失败链从第一次重试重新计数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resetsAfterSuccessfulRetry` |
| 4 | AgentLoopRetryPlugin | 成功返回工具调用后重试预算回到满额 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resetsBudgetAfterSuccessfulLLMResponse` |
| 5 | AgentLoopRetryPlugin | 连续失败耗尽预算后不再重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopsAfterConsecutiveFailuresExhaustBudget` |
| 6 | AgentLoopRetryPlugin | 服务端给出 Retry-After 时，重启回合前先等待 | 失败结果带 Retry-After 建议 | 触发一次可重试失败 | 重试前等待服务端建议的时长 | P1 | ✅ 已覆盖 | `waitsBeforeRetryWhenServerAdvises` |
| 7 | AgentLoopRetryPlugin | 没有服务端建议时不额外等待 | 失败结果不含 Retry-After | 触发一次可重试失败 | 立即重试，不插入额外等待 | P1 | ✅ 已覆盖 | `doesNotWaitWithoutServerAdvice` |
| 8 | AgentLoopRetryCoordinator | 退避等待期间删除会话会取消延迟重试（**#934**） | 失败结果带 Retry-After 60s，退避已开始 | 退避期间删除该会话 | 睡眠任务被取消，不启动新回合 | P1 | ✅ 已覆盖 | `deletionDuringBackoffCancelsRetry` |
| 9 | AgentLoopRetryCoordinator | 退避结束时会话已被删除则不重启回合（**#934**） | 删除事件未送达协调器 | 退避结束时清除会话存在性 | 不调用 retryTurn 启动新回合 | P1 | ✅ 已覆盖 | `doesNotRetryConversationDeletedDuringBackoff` |
| 10 | AgentLoopRetryCoordinator | 调度与放弃重试时发布生命周期事件（**#935**） | 可重试失败且预算已耗尽 | 触发失败并让重试再次失败 | 先发布 scheduled，耗尽后发布 gaveUp，`isRetrying` 复位 | P1 | ✅ 已覆盖 | `publishesRetryLifecycleEvents` |
| 11 | AgentLoopRetryTimeline | 时间线正文经过注入的本地化解析（**回归 #895**） | 可重试失败带 provider/model/HTTP 状态码 | 以标记解析器构造时间线消息 | 正文为 `[Retrying (2/3): 连接被重置]`，元数据保持不变 | P1 | ✅ 已覆盖 | `messageContentUsesInjectedLocalization` |
| 12 | AgentLoopRetryTimeline | 时间线正文词条在所有规范语言下都有译文（**回归 #895**） | — | 读取编译后 `.lproj/Localizable.strings` | 正文词条在 5 种语言下均符合预期 | P1 | ✅ 已覆盖 | `messageContentHasTranslationsInCompiledBundle` |

> 说明：全部 **12 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 7 / 7
- P2: 已覆盖 0 / 0
- **合计: 12 / 12**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（2 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 12 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAgentLoopRetry
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
