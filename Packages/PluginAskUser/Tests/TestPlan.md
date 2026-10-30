# TestPlan — PluginAskUser

## 包概述

PluginAskUser 的实现包，包含 5 个主要类型；当前测试覆盖 47 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 47

核心组件（源码目录）:
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AskUserBridge`
- `AskUserPendingInteraction`
- `AskUserAccessibility`
- `AskUserPlugin`
- `AskUserTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AskUserInteraction**（11 条）：由 `decodesValidSuspension`、`rejectsOtherKinds`、`rejectsMissingToolCallID` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AskUserLifecycle**（6 条）：由 `yesNoSuspendThenResume`、`choiceSuspendThenResume`、`freeTextSuspendThenResume` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AskUserToolArgument**（19 条）：由 `validModes`、`invalidModes`、`yesNoIgnoresOptions` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（11 条）：由 `pendingInteractionVisibility`、`suspensionPayloadDecoding`、`yesNoMode` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AskUserInteraction | 合法 userInput suspension 派生出交互，并保留真实 tool call ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesValidSuspension` |
| 2 | AskUserInteraction | 非 userInput kind 不派生交互（授权类挂起由各自的 UI 负责） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsOtherKinds` |
| 3 | AskUserInteraction | toolCallID 缺失或为空时不派生交互 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsMissingToolCallID` |
| 4 | AskUserInteraction | payload 非法 JSON 或字段缺失时不派生交互 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsMalformedPayload` |
| 5 | AskUserInteraction | 仅在选中会话与挂起会话一致时显示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `showGating` |
| 6 | AskUserInteraction | 不同会话的挂起点互不串台 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotLeakAcrossConversations` |
| 7 | AskUserInteraction | 带 description/badge 的选项完整往返 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `optionCodingRoundTrip` |
| 8 | AskUserInteraction | 裸字符串选项编码为字符串而非对象（兼容旧格式） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bareOptionEncodesAsString` |
| 9 | AskUserInteraction | payload 往返保留 mode/question/options | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `payloadRoundTrip` |
| 10 | AskUserInteraction | 旧 payload 缺少 mode 时仍可解码（mode 保持 nil） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesLegacyPayloadWithoutMode` |
| 11 | AskUserInteraction | 选项 id 即 label，重复标签会让 ForEach 复用同一行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `optionIdentity` |
| 12 | AskUserLifecycle | yes_no 提问挂起后，回答「是」可恢复并把答案回传给 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `yesNoSuspendThenResume` |
| 13 | AskUserLifecycle | choice 提问：选项被点选后以选项 label 作为答案恢复 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `choiceSuspendThenResume` |
| 14 | AskUserLifecycle | free_text 提问：自由文本答案原样回传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `freeTextSuspendThenResume` |
| 15 | AskUserLifecycle | 参数非法时工具报错，回合不挂起而是正常结束 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidArgumentsDoNotSuspend` |
| 16 | AskUserLifecycle | 错误答案不影响恢复：resumeTurn 对任意 suspensionID 校验严格 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeRejectsMismatchedSuspension` |
| 17 | AskUserLifecycle | ToolManager 透传 ask_user 的挂起语义 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolManagerPropagatesSuspension` |
| 18 | AskUserToolArgument | 合法 mode 原样返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validModes` |
| 19 | AskUserToolArgument | 缺失或非法 mode 返回 nil（触发必填错误） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidModes` |
| 20 | AskUserToolArgument | yes_no 忽略传入的 options，固定返回是/否 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `yesNoIgnoresOptions` |
| 21 | AskUserToolArgument | free_text 返回空选项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `freeTextHasNoOptions` |
| 22 | AskUserToolArgument | choice 解析对象与裸字符串混合数组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `choiceParsesMixedOptions` |
| 23 | AskUserToolArgument | choice 兼容 label 缺失时的回退字段 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `choiceOptionLabelFallbacks` |
| 24 | AskUserToolArgument | 无法取出标签的项被丢弃；空字符串标签同样丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `choiceDropsUnusableOptions` |
| 25 | AskUserToolArgument | 纯空白标签不被丢弃（原样保留） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `choiceKeepsWhitespaceLabel` |
| 26 | AskUserToolArgument | 非数组的 options 返回空（由上层报 choice 缺选项错误） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `choiceRejectsNonArray` |
| 27 | AskUserToolArgument | choice 传入空数组时返回空，由上层拦截 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `choiceEmptyArray` |
| 28 | AskUserToolArgument | badge 归一化：压缩空白、丢弃空值、截断到 16 字符 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `badgeNormalization` |
| 29 | AskUserToolArgument | 空问题、纯空白问题、缺失问题均返回错误且不挂起 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyQuestion` |
| 30 | AskUserToolArgument | 错误结果带 ❌ 前缀以便 AgentLoop 与日志区分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorPrefix` |
| 31 | AskUserToolArgument | 合法调用返回 awaitingUserResponse 且 interactionState 为 waiting | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `successfulResultSuspends` |
| 32 | AskUserToolArgument | 三种模式的 payload 都能被解码回完整响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `payloadRoundTrips` |
| 33 | AskUserToolArgument | schema 声明 question/mode 必填，options 仅在 choice 下有意义 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `schemaContract` |
| 34 | AskUserToolArgument | 工具身份与调度语义稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolIdentity` |
| 35 | AskUserToolArgument | displayDescription 回显问题文案，缺问题时给出通用文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayDescription` |
| 36 | AskUserToolArgument | description 明确要求先选 mode 并警告不要滥用 yes_no | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `descriptionContract` |
| 37 | 综合 | 问题视图始终显示在当前会话的 userInput 挂起问题 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pendingInteractionVisibility` |
| 38 | 综合 | 从 userInput suspension 解码问题并保留真实 tool call ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionPayloadDecoding` |
| 39 | 综合 | yes_no 模式：返回是/否选项且挂起等待回答 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `yesNoMode` |
| 40 | 综合 | choice 模式：返回传入的选项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `choiceMode` |
| 41 | 综合 | 选项 badge 可编码解码且兼容旧字符串格式 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `optionBadgeCoding` |
| 42 | 综合 | AskUser Schema 声明可选 badge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `badgeSchema` |
| 43 | 综合 | free_text 模式：无选项，挂起等待回答 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `freeTextMode` |
| 44 | 综合 | 缺 mode 返回错误且不挂起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingMode` |
| 45 | 综合 | choice 模式缺 options 返回错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `choiceMissingOptions` |
| 46 | 综合 | 插件注册 ask_user 工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersTool` |
| 47 | 综合 | ask_user 工具经 AgentLoop 挂起后可恢复（端到端） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `endToEndSuspension` |

> 说明：全部 **47 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 30 / 30
- P2: 已覆盖 6 / 6
- **合计: 47 / 47**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（11 条）
- **P1**: 其余功能性用例（30 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 47 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAskUser
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
