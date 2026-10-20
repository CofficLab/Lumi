# TestPlan — PluginLLMProviderUITest

## 包概述

PluginLLMProviderUITest UI 测试专用的确定性 LLM 供应商（**仅 DEBUG**）。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 53

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PluginUITestProvider`
- `UITestProvider`
- `UITestScenario`
- `UITestStubNetwork`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **UITestProviderAskUser**（6 条）：由 `firstRoundProducesCompleteToolCall`、`secondRoundEmitsFollowUpAfterToolResult`、`toolResultSurvivesRealSerialization` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UITestProvider**（14 条）：由 `providerIdentityIsLocal`、`modelCatalogueCoversAllScenarios`、`hasNoRemoteModelList` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UITestStubApprovalPayload**（7 条）：由 `firstRoundEmitsHighRiskToolCall`、`firstRoundCarriesToolIdentity`、`firstRoundStopsOnToolCalls` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UITestStubAskUserPayload**（8 条）：由 `firstRoundEmitsAskUserToolCall`、`firstRoundCarriesToolIdentity`、`firstRoundStopsOnToolCalls` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UITestStubGoalPayload**（8 条）：由 `firstRoundEmitsGoalToolCall`、`firstRoundCarriesToolIdentity`、`firstRoundStopsOnToolCalls` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UITestStubPayload**（10 条）：由 `everyEventIsWellFormedSSE`、`everyEventPayloadIsValidJSON`、`successfulScenariosTerminateWithDone` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | UITestProviderAskUser | 首轮经真实 SSE 解析后产出完整的 ask_user 工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundProducesCompleteToolCall` |
| 2 | UITestProviderAskUser | 请求体含 role=tool 时产出收尾正文，且不再调用工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `secondRoundEmitsFollowUpAfterToolResult` |
| 3 | UITestProviderAskUser | 工具结果确实进入了出站请求体（桩的判据前提成立） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolResultSurvivesRealSerialization` |
| 4 | UITestProviderAskUser | 无 role=tool 时仍发问（不会误判为已回答） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `withoutToolResultStillAsks` |
| 5 | UITestProviderAskUser | 只有 role=tool 会触发次轮，assistant 的 tool_calls 不会 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallAloneDoesNotCountAsAnswered` |
| 6 | UITestProviderAskUser | 非流式路径与流式路径在两段上分别等价 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingMatchesStreamingOnBothRounds` |
| 7 | UITestProvider | 注册表 key 与本地类型标记稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerIdentityIsLocal` |
| 8 | UITestProvider | 默认模型是固定文本场景，且模型清单覆盖全部场景 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelCatalogueCoversAllScenarios` |
| 9 | UITestProvider | 供应商不声明远程模型源，刷新是无副作用的空操作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hasNoRemoteModelList` |
| 10 | UITestProvider | API Key 为固定假串，且解析不触碰 Keychain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesStubAPIKeyWithoutKeychain` |
| 11 | UITestProvider | 文本场景经真实 SSE 解析后产出完整正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textScenarioStreamsExpectedReply` |
| 12 | UITestProvider | 非流式调用与流式调用产出同一正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingMatchesStreaming` |
| 13 | UITestProvider | 工具场景产出单个工具调用且 arguments 完整 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolScenarioProducesCompleteToolCall` |
| 14 | UITestProvider | 错误场景在真实解析链路上抛出失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorScenarioThrowsThroughRealParser` |
| 15 | UITestProvider | 长文本场景正文完整累积 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `longScenarioStreamsEveryParagraph` |
| 16 | UITestProvider | 未知模型落到 unknown 场景而非崩溃或空响应 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `unknownModelFallsBackSafely` |
| 17 | UITestProvider | 桩确实收到被真实序列化过的请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stubSeesRealSerializedRequestBody` |
| 18 | UITestProvider | 插件身份与元数据稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginIdentityAndMetadata` |
| 19 | UITestProvider | 非 UI 测试启动时不注册供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotRegisterWithoutLaunchArgument` |
| 20 | UITestProvider | onBoot 在缺少 LLM 管理器时不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootWithoutManagerDoesNotThrow` |
| 21 | UITestStubApprovalPayload | 首轮发出 edit_file 工具调用，arguments 分两片下发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundEmitsHighRiskToolCall` |
| 22 | UITestStubApprovalPayload | 首轮首片带工具名与固定 call id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundCarriesToolIdentity` |
| 23 | UITestStubApprovalPayload | 首轮 finish_reason 为 tool_calls，不产出任何正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundStopsOnToolCalls` |
| 24 | UITestStubApprovalPayload | 用户已决定后产出固定收尾正文，并以 stop 正常结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `secondRoundEmitsFollowUpText` |
| 25 | UITestStubApprovalPayload | 两段响应互不相同（避免首轮被误判为收尾） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `twoRoundsDiffer` |
| 26 | UITestStubApprovalPayload | 授权场景的参数是合法 JSON 且带 edit_file 的必填字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvalArgumentsAreWellFormed` |
| 27 | UITestStubApprovalPayload | 授权场景声明支持工具，且可被供应商目录查到 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvalModelIsRegistered` |
| 28 | UITestStubAskUserPayload | 首轮发出 ask_user 工具调用，arguments 分两片下发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundEmitsAskUserToolCall` |
| 29 | UITestStubAskUserPayload | 首轮首片带工具名与固定 call id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundCarriesToolIdentity` |
| 30 | UITestStubAskUserPayload | 首轮 finish_reason 为 tool_calls，不产出任何正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundStopsOnToolCalls` |
| 31 | UITestStubAskUserPayload | 已回答后产出固定收尾正文，并以 stop 正常结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `secondRoundEmitsFollowUpText` |
| 32 | UITestStubAskUserPayload | 两段响应互不相同（避免首轮被误判为收尾） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `twoRoundsDiffer` |
| 33 | UITestStubAskUserPayload | 三个 ask_user 场景的参数都是合法 JSON 且带必填字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserArgumentsAreWellFormed` |
| 34 | UITestStubAskUserPayload | 非 ask_user 场景没有工具参数，且 ask_user 场景声明支持工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scenarioMetadataIsConsistent` |
| 35 | UITestStubAskUserPayload | ask_user 场景模型可被供应商目录查到 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserModelsAreRegistered` |
| 36 | UITestStubGoalPayload | 首轮发出 create_goal 工具调用，arguments 分两片下发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundEmitsGoalToolCall` |
| 37 | UITestStubGoalPayload | 首轮首片带工具名与固定 call id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundCarriesToolIdentity` |
| 38 | UITestStubGoalPayload | 首轮 finish_reason 为 tool_calls，不产出任何正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRoundStopsOnToolCalls` |
| 39 | UITestStubGoalPayload | 工具执行后产出固定收尾正文，并以 stop 正常结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `secondRoundEmitsFollowUpText` |
| 40 | UITestStubGoalPayload | 两段响应互不相同（避免首轮被误判为收尾） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `twoRoundsDiffer` |
| 41 | UITestStubGoalPayload | goal 参数是合法 JSON，且带 title 与 tasks 必填字段 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `goalArgumentsAreWellFormed` |
| 42 | UITestStubGoalPayload | goal 场景声明支持工具，且展示名可辨识 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scenarioMetadataIsConsistent` |
| 43 | UITestStubGoalPayload | goal 场景模型可被供应商目录查到 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `goalModelIsRegistered` |
| 44 | UITestStubPayload | 每个事件块都以 data: 前缀开头并以空行结尾 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyEventIsWellFormedSSE` |
| 45 | UITestStubPayload | 每个非终止事件块的 data 载荷都是合法 JSON | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyEventPayloadIsValidJSON` |
| 46 | UITestStubPayload | 成功场景以 [DONE] 收尾，错误场景以单个 error 事件终止 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `successfulScenariosTerminateWithDone` |
| 47 | UITestStubPayload | 文本场景的分段拼接后等于约定正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textChunksConcatenateToExpectedReply` |
| 48 | UITestStubPayload | 文本场景带 usage 统计与终止信号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textScenarioCarriesUsageAndStop` |
| 49 | UITestStubPayload | 工具场景把 arguments 分两片下发，覆盖累加路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolScenarioSplitsArgumentsAcrossDeltas` |
| 50 | UITestStubPayload | 工具场景首片带 id 与 name，finish_reason 为 tool_calls | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolScenarioProvidesIdentityAndStopReason` |
| 51 | UITestStubPayload | 错误场景产出带 error.message 的事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorScenarioCarriesMessage` |
| 52 | UITestStubPayload | 长文本场景产出约定段数的正文增量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `longScenarioEmitsFixedParagraphCount` |
| 53 | UITestStubPayload | 慢速场景复用文本场景的正文，差异只在投递间隔 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `slowScenarioReusesTextBody` |

> 说明：全部 **53 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 49 / 49
- P2: 已覆盖 3 / 3
- **合计: 53 / 53**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（49 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 53 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMProviderUITest
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
