# TestPlan — ProviderAgentLoop

## 包概述

ProviderAgentLoop 的实现包，包含 9 个主要类型；当前测试覆盖 16 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 16

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentLoopFailure`
- `AgentLoopEvent`
- `AgentLoopOutcome`
- `AgentLoopProviding`
- `AgentLoopState`
- `AgentLoopSuspension`
- `AgentTurnResumeRequest`
- `DefaultAgentLoopObserverHandle`
- `DefaultAgentLoopProvider`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentLoopFullLoop**（5 条）：由 `usesStreamingPath`、`emptyResponseKeepsReasoningOnErrorMessage`、`toolCallLoop` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（11 条）：由 `networkFailureIsRetryable`、`systemTLSFailureIsRetryable`、`classifiesHTTPFailures` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentLoopFullLoop | 流式 Provider 优先走 streamComplete 并写入流式 store | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesStreamingPath` |
| 2 | AgentLoopFullLoop | 空响应失败时思考内容随错误消息落库 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyResponseKeepsReasoningOnErrorMessage` |
| 3 | AgentLoopFullLoop | 工具调用循环：assistant 带工具 → 执行 → 结果回传 → 最终回复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallLoop` |
| 4 | AgentLoopFullLoop | build 模式高风险工具挂起等待用户响应，响应后执行并完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `highRiskSuspensionAndResume` |
| 5 | AgentLoopFullLoop | chat 模式拒绝执行工具 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `chatModeBlocksTools` |
| 6 | 综合 | 结构化失败将网络错误标记为可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `networkFailureIsRetryable` |
| 7 | 综合 | 系统 TLS 错误会归类为可重试网络失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `systemTLSFailureIsRetryable` |
| 8 | 综合 | 结构化失败区分限流、服务端和鉴权错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesHTTPFailures` |
| 9 | 综合 | 鉴权、配置和上下文错误默认不可自动重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nonRetryableFailuresRemainNonRetryable` |
| 10 | 综合 | 空响应归类为可重试失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyResponseIsRetryable` |
| 11 | 综合 | 用户文本文件附件会转换为 LLM 用户正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageToLLMMessagePreservesUserFile` |
| 12 | 综合 | 工具结果图片关联到 tool 消息而不是 assistant | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolResultImageIsAttachedToToolMessage` |
| 13 | 综合 | Loop 通过 LLM Provider 生成 assistant 消息并更新状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runsTurn` |
| 14 | 综合 | Loop 通过 LLM Provider 生成 assistant 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runsWithLLMProvider` |
| 15 | 综合 | 创建 Loop 时依赖全部注入，直接可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `constructorInjection` |
| 16 | 综合 | resumeTurn 无挂起点时抛出 invalidResumeRequest | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeTurnWithoutSuspensionThrows` |

> 说明：全部 **16 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 9 / 9
- P2: 已覆盖 1 / 1
- **合计: 16 / 16**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（9 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 16 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderAgentLoop
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
