# TestPlan — ProviderAgentLoop

## 包概述

ProviderAgentLoop 的实现包，包含 11 个主要类型；当前测试覆盖 46 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 46

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentLoopFailure`
- `AgentLoopEvent`
- `AgentLoopOutcome`
- `AgentLoopProviding`
- `AgentLoopRetryLifecycleEvent`
- `AgentLoopState`
- `AgentLoopSuspension`
- `AgentTurnResumeRequest`
- `DefaultAgentLoopObserverHandle`
- `DefaultAgentLoopProvider`
- `SubagentToolPolicy`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentLoopFullLoop**（6 条）：由 `usesStreamingPath`、`emptyResponseKeepsReasoningOnErrorMessage`、`persistsCacheTokenUsage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DefaultAgentLoopToolCapability**（2 条）：由 `requestOmitsToolsWhenModelDoesNotSupportThem`、`requestKeepsToolsWhenModelSupportsThem` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderAgentLoopHistoryImageDecoding**（4 条）：由 `nonVisionModeDoesNotDecodeUserImages`、`visionModeStillDecodesImages`、`historyConversionRunsOffMainThread` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（13 条）：由 `networkFailureIsRetryable`、`systemTLSFailureIsRetryable`、`classifiesHTTPFailures` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SubagentToolPolicy**（3 条）：由 `childToolsExcludeDelegationToolItself`、`childToolsKeepOnlyParallelReadOnlyInOrder`、`childToolsOfEmptyRegistryIsEmpty` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ThinkingDeltaStage**（1 条）：由 `thinkingDeltaDoesNotFlipStreamingStageEndToEnd` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DefaultAgentLoop 终态钩子与失败详情**（17 条）：由 `completedTurnFiresFinishedHook`、`rateLimitedFailureExposesStructuredDetails`、`failedTurnRetainsCurrentTurnID`、`lateResponseAfterCancelIsNotPersisted`、`lateOldTurnReturnDoesNotOverwriteNewTurn` 等用例锁定——终态钩子恰好一次投递（#219）、失败详情结构化可重试（#230）、失败保留 turnID 供重试（#231）、取消与迟到响应隔离（#233 / #438）、恢复沿用同一 turnID 重新声明运行中（#805）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentLoopFullLoop | 流式 Provider 优先走 streamComplete 并写入流式 store | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesStreamingPath` |
| 2 | AgentLoopFullLoop | 空响应失败时思考内容随错误消息落库 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyResponseKeepsReasoningOnErrorMessage` |
| 3 | AgentLoopFullLoop | 缓存 token 用量随 assistant 消息落库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistsCacheTokenUsage` |
| 4 | AgentLoopFullLoop | 工具调用循环：assistant 带工具 → 执行 → 结果回传 → 最终回复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallLoop` |
| 5 | AgentLoopFullLoop | build 模式高风险工具挂起等待用户响应，响应后执行并完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `highRiskSuspensionAndResume` |
| 6 | AgentLoopFullLoop | chat 模式拒绝执行工具 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `chatModeBlocksTools` |
| 7 | DefaultAgentLoopToolCapability | 模型声明不支持工具时请求不带工具 Schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestOmitsToolsWhenModelDoesNotSupportThem` |
| 8 | DefaultAgentLoopToolCapability | 模型声明支持工具时请求仍带工具 Schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestKeepsToolsWhenModelSupportsThem` |
| 9 | ProviderAgentLoopHistoryImageDecoding | 非视觉模式不解码用户图片附件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonVisionModeDoesNotDecodeUserImages` |
| 10 | ProviderAgentLoopHistoryImageDecoding | 视觉模式照常解码图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visionModeStillDecodesImages` |
| 11 | ProviderAgentLoopHistoryImageDecoding | 历史转换不在主线程上执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyConversionRunsOffMainThread` |
| 12 | ProviderAgentLoopHistoryImageDecoding | 离主线程转换的结果与同步转换完全一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offMainActorConversionMatchesSyncConversion` |
| 13 | 综合 | 结构化失败将网络错误标记为可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `networkFailureIsRetryable` |
| 14 | 综合 | 系统 TLS 错误会归类为可重试网络失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `systemTLSFailureIsRetryable` |
| 15 | 综合 | 结构化失败区分限流、服务端和鉴权错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesHTTPFailures` |
| 16 | 综合 | 529 过载失败保留服务端给出的退避建议 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `overloadedFailureCarriesRetryAfter` |
| 17 | 综合 | 没有服务端建议时退避时长为空 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `failureWithoutRetryAfterHasNoDelay` |
| 18 | 综合 | 鉴权、配置和上下文错误默认不可自动重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nonRetryableFailuresRemainNonRetryable` |
| 19 | 综合 | 空响应归类为可重试失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyResponseIsRetryable` |
| 20 | 综合 | 用户文本文件附件会转换为 LLM 用户正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageToLLMMessagePreservesUserFile` |
| 21 | 综合 | 工具结果图片关联到 tool 消息而不是 assistant | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolResultImageIsAttachedToToolMessage` |
| 22 | 综合 | Loop 通过 LLM Provider 生成 assistant 消息并更新状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runsTurn` |
| 23 | 综合 | Loop 通过 LLM Provider 生成 assistant 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runsWithLLMProvider` |
| 24 | 综合 | 创建 Loop 时依赖全部注入，直接可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `constructorInjection` |
| 25 | 综合 | resumeTurn 无挂起点时抛出 invalidResumeRequest | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeTurnWithoutSuspensionThrows` |
| 26 | SubagentToolPolicy | 子会话工具表不得包含委托工具自身 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `childToolsExcludeDelegationToolItself` |
| 27 | SubagentToolPolicy | 子会话工具表只保留只读并发工具且保持注册顺序 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `childToolsKeepOnlyParallelReadOnlyInOrder` |
| 28 | SubagentToolPolicy | 空工具表过滤后仍为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `childToolsOfEmptyRegistryIsEmpty` |
| 29 | ThinkingDeltaStage | 端到端：思考增量不会让流式阶段翻成 generating | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `thinkingDeltaDoesNotFlipStreamingStageEndToEnd` |
| 30 | DefaultAgentLoop 终态钩子与失败详情 | 完成回合触发 turnFinished，turnID 与 turnStarted 对称（**回归 #219**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `completedTurnFiresFinishedHook` |
| 31 | DefaultAgentLoop 终态钩子与失败详情 | 失败回合触发 turnFinished(.failed)（**回归 #219**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `failedTurnFiresFinishedHook` |
| 32 | DefaultAgentLoop 终态钩子与失败详情 | 取消回合恰好触发一次 turnFinished(.cancelled)，迟到的完成不再重复投递（**回归 #219**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledTurnFiresFinishedHookExactlyOnce` |
| 33 | DefaultAgentLoop 终态钩子与失败详情 | 挂起触发 turnFinished(.suspended)，恢复完成后同 turnID 再投递 .completed（**回归 #219 / #805**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `suspensionThenResumeFiresBothHooks` |
| 34 | DefaultAgentLoop 终态钩子与失败详情 | 没有活跃回合时取消不触发 turnFinished | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelWithoutActiveTurnDoesNotFire` |
| 35 | DefaultAgentLoop 终态钩子与失败详情 | 限流失败暴露结构化 lastFailure，含 Retry-After 供自动重试消费（**回归 #230**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rateLimitedFailureExposesStructuredDetails` |
| 36 | DefaultAgentLoop 终态钩子与失败详情 | 鉴权失败同样落 lastFailure，但标记为不可自动重试（**回归 #230**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `authenticationFailureIsStoredButNotRetryable` |
| 37 | DefaultAgentLoop 终态钩子与失败详情 | 空终态响应归类为可重试的 emptyResponse 失败（**回归 #230**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyResponseIsRetryableFailure` |
| 38 | DefaultAgentLoop 终态钩子与失败详情 | 新回合开始时清除上一回合的失败详情 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `newTurnClearsPreviousFailure` |
| 39 | DefaultAgentLoop 终态钩子与失败详情 | 失败终态保留 currentTurnID，重试按钮可定位失败回合（**回归 #231**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `failedTurnRetainsCurrentTurnID` |
| 40 | DefaultAgentLoop 终态钩子与失败详情 | retryTurn 校验失败回合身份后重启并完成（**回归 #231**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryTurnRestartsMatchingFailedTurn` |
| 41 | DefaultAgentLoop 终态钩子与失败详情 | retryTurn 拒绝过期的失败回合身份（**回归 #231**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryTurnRejectsStaleTurnID` |
| 42 | DefaultAgentLoop 终态钩子与失败详情 | 非失败状态不允许 retryTurn（**回归 #231**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryTurnRequiresFailedState` |
| 43 | DefaultAgentLoop 终态钩子与失败详情 | 取消后迟到的普通响应不落库，状态保持 cancelled（**回归 #233**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lateResponseAfterCancelIsNotPersisted` |
| 44 | DefaultAgentLoop 终态钩子与失败详情 | 取消后迟到的工具调用不得执行（**回归 #233**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lateToolCallsAfterCancelDoNotExecute` |
| 45 | DefaultAgentLoop 终态钩子与失败详情 | 取消后同一会话的新回合不受旧请求迟到响应影响（**回归 #233**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `newTurnAfterCancelStillWorks` |
| 46 | DefaultAgentLoop 终态钩子与失败详情 | 旧回合在新回合运行中迟到返回，不得覆盖新回合状态（**回归 #438**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lateOldTurnReturnDoesNotOverwriteNewTurn` |

> 说明：全部 **46 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 27 / 27
- P1: 已覆盖 17 / 17
- P2: 已覆盖 2 / 2
- **合计: 46 / 46**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（27 条）
- **P1**: 其余功能性用例（17 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 46 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
