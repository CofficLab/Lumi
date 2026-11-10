# TestPlan — PluginMessageRenderer

## 包概述

PluginMessageRenderer 的实现包，包含 15 个主要类型；当前测试覆盖 74 条用例。

平台: macOS 14+, iOS 17+
测试文件: 10 个，用例总数: 74

核心组件（源码目录）:
- `Capabilities/`
- `Components/`
- `Helpers/`
- `Models/`
- `Observers/`
- `Renderers/`
- `Services/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MessageRendererPlugin`
- `RiskApprovalPendingInteraction`
- `ToolPermissionRequest`
- `MessageRendererCapability`
- `BorderedUtilityContent`
- `CollapsedContentChips`
- `CollapsiblePlainText`
- `CompactMessageHeaderView`
- `ErrorTransportDetailsButton`
- `MessageDiagnosticStrip`
- `MessageFileAttachmentChips`
- `MessageInfoButton`
- `ResendMessageButton`
- `RetryTurnButton`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MessageRendererPlugin**（15 条）：由 `assistantContentVerbosity`、`v1DoesNotUseCustomToolRenderers`、`formatsToolCallArguments` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RetryTurnButton**（6 条）：由 `retryableWhenTurnMatches`、`notRetryableAfterTurnSuperseded`、`notRetryableWithoutTurnID` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalAfterConversationSwitch**（5 条）：由 `approvalCardDoesNotReappearAfterSwitchingBack`、`approvalCardDoesNotReappearAfterRejecting`、`cacheDoesNotResurrectAwaitingUserResponseResult` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalVisibilityAfterResolution**（4 条）：由 `showsApprovalWhilePending`、`hidesApprovalAfterUserApproved`、`hidesApprovalAfterUserRejected` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalMisclaim**（4 条）：由 `askUserSuspensionIsNotClaimedByApprovalRenderer`、`misclaimedToolCallCannotBuildRequest`、`realPermissionRequestIsStillClaimed` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallGroupCollapsePolicy**（14 条）：由 `singleCallIsNotCollapsed`、`emptyGroupIsNotCollapsed`、`multipleCompletedCallsAreCollapsed` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJobSummary**（5 条）：由 `mapsAllStatuses`、`projectsLiveJob`、`terminalJobIsNotStale` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolApprovalCancellation**（9 条）：由 `cancelledTurnClearsPendingApproval`、`cancelledTurnRefusesAllow`、`mismatchedSuspensionRefusesExecution` 等用例锁定；改动授权缓存或提交边界时优先跑对应测试文件。
- **ModelSwitchSummary**（9 条）：由 `sameModelAcrossProvidersKeepsProviders`、`differentModelsStayCompact`、`firstSelectionHasNoSource` 等用例锁定；模型切换主行在「模型名相同、供应商不同」时必须同时展示两端供应商，否则会渲染成 `gpt-5 → gpt-5`（#907）；主行、详情弹层与辅助功能文案必须经本地化解析，词条需覆盖 5 种语言（#905）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MessageRendererPlugin | V1 assistant 内容使用 V2 布局，仅隐藏 Header | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantContentVerbosity` |
| 2 | MessageRendererPlugin | V1 模式下 ask_user 等挂起交互不走自定义工具渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v1DoesNotUseCustomToolRenderers` |
| 3 | MessageRendererPlugin | 工具调用参数保留真实 JSON 与历史异常内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsToolCallArguments` |
| 4 | MessageRendererPlugin | 已有最终结果的旧 pending 工具调用不重复显示授权 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `completedPendingToolCallDoesNotRenderApproval` |
| 5 | MessageRendererPlugin | 用户授权后不显示授权界面 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userApprovedToolCallDoesNotRenderApproval` |
| 6 | MessageRendererPlugin | 用户拒绝后不显示授权界面 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `userRejectedToolCallDoesNotRenderApproval` |
| 7 | MessageRendererPlugin | V1 风险审批只显示在当前 brief 会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskApprovalVisibility` |
| 8 | MessageRendererPlugin | 审批事件创建 pending 状态，授权完成后清除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskApprovalEventLifecycle` |
| 9 | MessageRendererPlugin | 13 个内置渲染器全部注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAllBuiltinRenderers` |
| 10 | MessageRendererPlugin | 按 role 分发到对应渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dispatchesByRole` |
| 11 | MessageRendererPlugin | turn-completed 与 tool-step-group 特殊渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dispatchesSpecialKinds` |
| 12 | MessageRendererPlugin | preferredRendererID 显式路由优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prefersExplicitRenderer` |
| 13 | MessageRendererPlugin | 兜底渲染器接管未匹配消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackRenderer` |
| 14 | MessageRendererPlugin | 渲染闭包返回可渲染视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderClosureProducesView` |
| 15 | MessageRendererPlugin | 插件注册并移除 V1 风险审批固定区 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersRiskApprovalChatItem` |
| 16 | RetryTurnButton | 失败回合仍在当前回合上时可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryableWhenTurnMatches` |
| 17 | RetryTurnButton | 回合已被新回合取代后不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `notRetryableAfterTurnSuperseded` |
| 18 | RetryTurnButton | 消息缺少 turnID 时不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `notRetryableWithoutTurnID` |
| 19 | RetryTurnButton | 没有 capability 时不可重试（插件未装配 AgentLoop） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `notRetryableWithoutCapability` |
| 20 | RetryTurnButton | 重试请求携带触发消息的回合 ID 与会话 ID | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryRequestCarriesTurnAndConversation` |
| 21 | RetryTurnButton | 不可重试的消息不应发出任何重试请求 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `noRetryRequestWhenNotRetryable` |
| 22 | ToolApprovalAfterConversationSwitch | 用户已允许后切换对话再切回，授权卡片不再出现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvalCardDoesNotReappearAfterSwitchingBack` |
| 23 | ToolApprovalAfterConversationSwitch | 用户已拒绝后切换对话再切回，授权卡片不再出现 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `approvalCardDoesNotReappearAfterRejecting` |
| 24 | ToolApprovalAfterConversationSwitch | 缓存命中不得复活等待授权的占位结果 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cacheDoesNotResurrectAwaitingUserResponseResult` |
| 25 | ToolApprovalAfterConversationSwitch | 缓存仍可补齐消息里缺失的工具结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheStillFillsMissingResults` |
| 26 | ToolApprovalAfterConversationSwitch | 未处理的授权仍然显示授权卡片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingApprovalStillRendersCard` |
| 27 | ToolApprovalVisibilityAfterResolution | 等待授权时显示授权卡片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `showsApprovalWhilePending` |
| 28 | ToolApprovalVisibilityAfterResolution | 用户已允许后重新打开不再显示授权卡片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hidesApprovalAfterUserApproved` |
| 29 | ToolApprovalVisibilityAfterResolution | 用户已拒绝后重新打开不再显示授权卡片 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `hidesApprovalAfterUserRejected` |
| 30 | ToolApprovalVisibilityAfterResolution | 授权状态丢失的形态会重新显示授权卡片（症状定义） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stalePendingFormRedisplayApproval` |
| 31 | ToolApprovalMisclaim | 挂起的 ask_user 不被通用授权卡片接管 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserSuspensionIsNotClaimedByApprovalRenderer` |
| 32 | ToolApprovalMisclaim | 被误接管时授权请求必然构造不出来 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `misclaimedToolCallCannotBuildRequest` |
| 33 | ToolApprovalMisclaim | 真正的工具授权请求仍然被接管 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `realPermissionRequestIsStillClaimed` |
| 34 | ToolApprovalMisclaim | 挂起加 pendingAuthorization 不足以判定为授权请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionAloneDoesNotImplyAuthorization` |
| 35 | ToolCallGroupCollapsePolicy | 单个工具调用不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleCallIsNotCollapsed` |
| 36 | ToolCallGroupCollapsePolicy | 空组不折叠 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyGroupIsNotCollapsed` |
| 37 | ToolCallGroupCollapsePolicy | 多个已完成的工具调用折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleCompletedCallsAreCollapsed` |
| 38 | ToolCallGroupCollapsePolicy | 多个进行中的工具调用折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleRunningCallsAreCollapsed` |
| 39 | ToolCallGroupCollapsePolicy | V3（detailed）保持逐条铺开，不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detailedIsNotCollapsed` |
| 40 | ToolCallGroupCollapsePolicy | V1（brief）保持逐条铺开，不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `briefIsNotCollapsed` |
| 41 | ToolCallGroupCollapsePolicy | brief 会被升格为 standard，折叠判定必须用原始级别 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `briefIsUpgradedToStandard` |
| 42 | ToolCallGroupCollapsePolicy | 等待授权的调用不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingAuthorizationIsNotCollapsed` |
| 43 | ToolCallGroupCollapsePolicy | 等待用户作答的调用不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `awaitingUserResponseIsNotCollapsed` |
| 44 | ToolCallGroupCollapsePolicy | 授权状态缺失且结果未出时按等待授权处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAuthorizationStateWithoutResultIsTreatedAsPending` |
| 45 | ToolCallGroupCollapsePolicy | 授权状态缺失但已有结果时不算挂起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAuthorizationStateWithResultIsNotPending` |
| 46 | ToolCallGroupCollapsePolicy | 用户已授权的调用不阻止折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvedCallDoesNotBlockCollapsing` |
| 47 | ToolCallGroupCollapsePolicy | 用户已拒绝的调用不阻止折叠 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectedCallDoesNotBlockCollapsing` |
| 48 | ToolCallGroupCollapsePolicy | 挂起检测只看组内是否有交互调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsAwaitingInteraction` |
| 49 | ToolJobSummary | 所有 Job 状态都有稳定的用户文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `mapsAllStatuses` |
| 50 | ToolJobSummary | 运行中的 Job 计算经过时间和进度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectsLiveJob` |
| 51 | ToolJobSummary | 终态 Job 不再标记为进行中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalJobIsNotStale` |
| 52 | ToolJobSummary | 停止中的 Job 仍算进行中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingJobIsStillInFlight` |
| 53 | ToolJobSummary | 步骤组摘要覆盖进行中、失败和完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summarizesJobGroup` |
| 54 | ToolApprovalCancellation | Stop 后底部授权缓存立即失效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledTurnClearsPendingApproval` |
| 55 | ToolApprovalCancellation | 完成与失败同样清理待授权缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalEventsClearPendingApproval` |
| 56 | ToolApprovalCancellation | 迟到的旧回合终态不会误删新回合授权 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleTerminalEventKeepsNewerTurnApproval` |
| 57 | ToolApprovalCancellation | 停止的回合点击允许不会执行工具 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledTurnRefusesAllow` |
| 58 | ToolApprovalCancellation | 已结束或失败的回合同样拒绝执行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `terminalTurnsRefuseExecution` |
| 59 | ToolApprovalCancellation | 挂起指向其他工具时旧卡片不得执行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `mismatchedSuspensionRefusesExecution` |
| 60 | ToolApprovalCancellation | 挂起匹配时正常执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingSuspensionExecutes` |
| 61 | ToolApprovalCancellation | 应用重启后的 idle 回合仍允许授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idleTurnStillAllowsRestartApproval` |
| 62 | ToolApprovalCancellation | 未提供 AgentLoop 时保持旧行为 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAgentLoopKeepsLegacyBehavior` |
| 63 | ModelSwitchSummary | 同模型跨供应商时主行保留供应商（回归 #907） | 切换前后模型名同为 gpt-5，供应商分为 openai / airouter | 调用 `ModelSwitchSummary.summaryText` | 文案为 `openai · gpt-5 → airouter · gpt-5` | P1 | ✅ 已覆盖 | `sameModelAcrossProvidersKeepsProviders` |
| 64 | ModelSwitchSummary | 同模型跨供应商时两端标签都带供应商 | 同上 | 调用 `ModelSwitchSummary.labels` | source / target 各自带供应商前缀 | P1 | ✅ 已覆盖 | `labelsPrefixProvidersOnlyWhenDisambiguating` |
| 65 | ModelSwitchSummary | 模型名不同时保持紧凑文案，不追加供应商 | 同一供应商下切换不同模型 | 调用 `summaryText` | 文案为 `gpt-5 → gpt-4o` | P1 | ✅ 已覆盖 | `differentModelsStayCompact` |
| 66 | ModelSwitchSummary | 同供应商同名模型仍按模型名展示 | 两端供应商与模型都相同 | 调用 `summaryText` | 文案为 `gpt-5 → gpt-5` | P1 | ✅ 已覆盖 | `sameProviderKeepsModelOnlyLabels` |
| 67 | ModelSwitchSummary | 缺少任一供应商时不拼接半边供应商 | 只有切换前供应商 | 调用 `summaryText` | 保持纯模型名文案 | P2 | ✅ 已覆盖 | `missingProviderDoesNotPrefix` |
| 68 | ModelSwitchSummary | 首次选择模型时只显示切换后的模型 | 切换前信息为 nil | 调用 `summaryText`（恒等解析） | 文案为 `Switched to gpt-5` | P1 | ✅ 已覆盖 | `firstSelectionHasNoSource` |
| 69 | ModelSwitchSummary | 只有供应商 ID 时退回显示供应商 | 两端都没有模型名 | 调用 `summaryText` | 文案为 `openai → airouter` | P2 | ✅ 已覆盖 | `providerOnlyFallsBackToIDs` |
| 70 | ModelSwitchSummary | 摘要片段经过注入的本地化解析（回归 #905） | — | 用 `[key]` 标记解析器调用 `summaryText` / `labels` | 返回带标记的本地化片段 | P1 | ✅ 已覆盖 | `summaryUsesInjectedLocalization` |
| 71 | ModelSwitchSummary | 模型切换词条在所有规范语言下都有译文（回归 #905） | — | 读取编译后 `.lproj/Localizable.strings` | 10 个词条在 5 种语言下均符合预期 | P1 | ✅ 已覆盖 | `switchLabelsHaveTranslationsInCompiledBundle` |
| 72 | AgentLoopRetrySummary | 重试状态文案经过注入的本地化解析（回归 #895） | — | 用 `[key]` 标记解析器调用 `statusText` | 有次数时返回 `[Retrying (1/3)]`，无次数时返回 `[Retrying]` | P1 | ✅ 已覆盖 | `statusUsesInjectedLocalization` |
| 73 | AgentLoopRetrySummary | 退避文案经过注入的本地化解析（回归 #895） | — | 用 `[key]` 标记解析器调用 `retryAfterText` | 有效秒数返回 `[30 seconds before retry]`，缺省或非数字返回 nil | P1 | ✅ 已覆盖 | `retryAfterUsesInjectedLocalization` |
| 74 | AgentLoopRetrySummary | 自动重试词条在所有规范语言下都有译文（回归 #895） | — | 读取编译后 `.lproj/Localizable.strings` | 9 个词条在 5 种语言下均符合预期 | P1 | ✅ 已覆盖 | `retryLabelsHaveTranslationsInCompiledBundle` |

> 说明：全部 **74 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 19 / 19
- P1: 已覆盖 51 / 51
- P2: 已覆盖 4 / 4
- **合计: 74 / 74**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（19 条）
- **P1**: 其余功能性用例（48 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 74 条用例位于 `Tests/`，需在目标平台执行 `swift test`
- 本地化用例依赖 SwiftBuild 编译出的 `.xcstrings`，需确认 `en` 与四种中文变体 `.lproj` 均已产出

## 测试执行

```bash
cd Packages/PluginMessageRenderer
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
