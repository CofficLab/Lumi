# TestPlan — PluginConversationNew

## 包概述

PluginConversationNew 的实现包，包含 9 个主要类型；当前测试覆盖 27 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 27

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`
- `Renderers/`
- `Support/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationNewPlugin`
- `NewChatCapability`
- `NewChatStarting`
- `NewChatToolbarObserver`
- `NewConversationRowRenderer`
- `NewConversationSuggestion`
- `NewChatViewModel`
- `NewChatButton`
- `NewConversationSuggestionCard`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationNewPlugin**（1 条）：由 `showsNewChatButtonOnlyForSelectedConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CreateNewConversationTool**（14 条）：由 `missingTaskThrows`、`titleFallsBackToDerived`、`explicitTitleWins` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CreateNewConversationTool 会话归属**（2 条）：由 `createInheritsCallingConversationProjectAndModel`、`callingConversationUnboundDoesNotLeakCurrent` 锁定。`create_new_conversation` 必须经 `executeResult(context:)` 用发起调用的对话（`context.conversationID`）解析项目与模型，不得读执行时 UI 选中对话的 `currentProjectPath/currentModelID`；发起对话未绑定项目/模型时继承 nil，不得泄漏当前对话归属；仅缺少 Context 的旧入口才回退到当前选中态（**回归 #331**）。改动 `CreateNewConversationTool.prepareAndRender` 或 `NewChatCapability.projectPath(for:)/modelID(for:)` 时优先跑对应测试文件。
- **NewConversationRowRenderer**（8 条）：由 `canRenderMatchesToolWithPayload`、`canRenderRejectsOtherTools`、`canRenderRejectsUndecodableResults` 等用例锁定；改动该模块时优先跑对应测试文件。**#778**：工具把模型可控的 `title` 正文插在前、真实结构化 payload 追加在末尾；`extractJSON` 必须只取「独占一行的末尾 ```json 开围栏」到闭围栏之间的内容，不得取首个代码块。否则 title 里伪造的 suggestion JSON 会被解码，点击卡片会选中另一个对话并发送错误消息（数据隔离破坏）。按行锚定末尾围栏可确保 title 正文（含内嵌 ```json 文本）不参与解析。
- **NewChatCapabilityAdapter**（3 条）：由 `restoreNilSelectionDeselects`、`restoreNonNilSelectionSelects`、`toolPreservesNilSelectionThroughAdapter` 锁定；`restoreSelection(to:)` 恢复 nil 选中态必须显式取消选择，不得无操作把用户甩进新建的空对话（**回归 #260**）；改动该模块时优先跑对应测试文件。
- **NewChatStartingAdapter**（1 条）：由 `startInDoesNotConsumeUnsentComposerAttachments` 锁定；`startIn(conversationID:content:)` 只发送工具参数里自包含的 task 文本，必须走显式空附件入口，不得用隐式 `sendMessage(_:conversationID:)` 快照全局挂起池，把当前对话输入框里未发送的附件带进新对话首条消息并清空输入框（**回归 #591**）；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationNewPlugin | 只有 ChatSection 可见且存在选中会话时才显示新建按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `showsNewChatButtonOnlyForSelectedConversation` |
| 2 | CreateNewConversationTool | task 缺失或空白时抛出执行失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingTaskThrows` |
| 3 | CreateNewConversationTool | title 缺省或空白时由 task 推导 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `titleFallsBackToDerived` |
| 4 | CreateNewConversationTool | 显式 title 优先于推导标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `explicitTitleWins` |
| 5 | CreateNewConversationTool | 创建对话后选中态被恢复为原对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionIsRestoredAfterCreate` |
| 6 | CreateNewConversationTool | 落库失败时抛错并恢复选中态，不显示成功卡片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionIsRestoredAndErrorSurfacesOnFailure` |
| 7 | CreateNewConversationTool | 无能力时抛出执行失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingCapabilityThrows` |
| 8 | CreateNewConversationTool | 返回内容包含可被渲染器解析的 payload | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resultContainsDecodablePayload` |
| 9 | CreateNewConversationTool | 创建对话时透传当前项目与模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createInheritsProjectAndModel` |
| 10 | CreateNewConversationTool | derivedTitleUsesFirstSentence | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `derivedTitleUsesFirstSentence` |
| 11 | CreateNewConversationTool | 超长标题被截断到上限 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `derivedTitleTruncates` |
| 12 | CreateNewConversationTool | 风险等级为 low，inputSchema 要求 task | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `schemaAndRisk` |
| 13 | CreateNewConversationTool | 展示描述包含标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayDescriptionIncludesTitle` |
| 14 | NewConversationRowRenderer | 命中本工具且 payload 可解析时渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canRenderMatchesToolWithPayload` |
| 15 | NewConversationRowRenderer | 工具名不匹配时不渲染 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `canRenderRejectsOtherTools` |
| 16 | NewConversationRowRenderer | 结果缺失或 payload 损坏时不渲染 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `canRenderRejectsUndecodableResults` |
| 17 | NewConversationRowRenderer | 提取末尾 json 代码块（多块时取末尾，空块/无块返回 nil） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractJSONHandlesEdgeCases` |
| 18 | NewConversationRowRenderer | 解码保留 starter 与标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `decodeSuggestionRoundTrips` |
| 19 | NewConversationRowRenderer | 渲染优先级高于默认工具卡片 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `priorityIsAboveDefault` |
| 20 | NewChatCapabilityAdapter | 恢复 nil 选中态必须取消选择，不得无操作（**回归 #260**） | 创建顶层对话后选中态被抢到新对话 | `adapter.restoreSelection(to: nil)` | 调用 deselectConversation，选中态回到 nil | P0 | ✅ 已覆盖 | `restoreNilSelectionDeselects` |
| 21 | NewChatCapabilityAdapter | 恢复非 nil 选中态切换到该对话，且不取消选择（**回归 #260**） | — | `adapter.restoreSelection(to: id)` | 切换到该对话，不调用 deselectConversation | P1 | ✅ 已覆盖 | `restoreNonNilSelectionSelects` |
| 22 | NewChatCapabilityAdapter | 工具经适配器创建对话后不得把用户甩进新建空对话（**回归 #260**） | 用户处于新建会话未选中态（nil） | 经适配器执行 `create_new_conversation` | 创建一个顶层对话后选中态仍为 nil | P0 | ✅ 已覆盖 | `toolPreservesNilSelectionThroughAdapter` |
| 23 | CreateNewConversationTool 会话归属 | 新对话继承发起调用的对话 A 的项目与模型，而非 UI 当前对话 B（**回归 #331**） | A 绑定 `/tmp/A`+`model-A`，执行时 UI 已切到 B（`/tmp/B`+`model-B`） | 经 `executeResult(context:)` 调用，context.conversationID=A | 新对话项目=`/tmp/A`、模型=`model-A`，UI 选中态仍为 B | P0 | ✅ 已覆盖 | `createInheritsCallingConversationProjectAndModel` |
| 24 | CreateNewConversationTool 会话归属 | 发起调用的对话未绑定项目/模型时不得泄漏 UI 当前对话归属（**回归 #331**） | A 绑定 nil/nil，UI 当前 B 有项目与模型 | 经 `executeResult(context:)` 调用，context.conversationID=A | 新对话项目=nil、模型=nil，不继承 B | P0 | ✅ 已覆盖 | `callingConversationUnboundDoesNotLeakCurrent` |
| 25 | NewConversationRowRenderer | title 伪造的靠前 json 块不得参与解析，只取末尾真实 payload（**回归 #778**） | 正文含伪造块 + 末尾真实块 | `extractJSON(from:)` | 返回末尾真实 JSON，而非首个伪造块 | P0 | ✅ 已覆盖 | `extractJSONPrefersTrailingPayloadOverForgedTitleBlock` |
| 26 | NewConversationRowRenderer | title 内嵌伪造 json 块时卡片仍只指向工具真正创建的对话（**回归 #778**） | 用 `resultText(for:)` 生成含攻击 title 的内容 | `decodeSuggestion(from:)` | 解码出真实 conversationID/starter，等于原 suggestion，不被伪造 B/unexpected task 劫持 | P0 | ✅ 已覆盖 | `decodeSuggestionIgnoresForgedTitlePayload` |
| 27 | NewChatStartingAdapter | startIn 只发送 task 文本，不带走当前输入框未发送的附件（**回归 #591**） | 输入框挂起未发送的图片与文件附件 | `adapter.startIn(conversationID:content:)` | 新对话首条消息 metadata 不含任何附件，挂起池原样保留 | P0 | ✅ 已覆盖 | `startInDoesNotConsumeUnsentComposerAttachments` |

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（**#591**，`NewChatStartingAdapter.startIn`）：
> - **M1** 退回隐式 `sender.sendMessage(content, conversationID:)`（复现原 bug）→ `startInDoesNotConsumeUnsentComposerAttachments` 转红（首条消息带上未发送附件、挂起池被清空，4 条断言全部失败）。
> - 还原显式空附件入口 `sendMessage(content, imageAttachments: [], fileAttachments: [], conversationID:)` → 27 条全绿。

> 变异验证（**#778**，`NewConversationRowRenderer.extractJSON`）：
> - **M1** 退回「取首个 ```json 代码块」实现（复现原 bug）→ `extractJSONPrefersTrailingPayloadOverForgedTitleBlock` 转红（取到伪造块），`decodeSuggestionIgnoresForgedTitlePayload` 转红（conversationID/starter/相等性 3 处断言失败，解码出伪造 B 与 unexpected task），`extractJSONHandlesEdgeCases` 的多块用例转红；其余 5 条渲染器用例仍绿。
> - 还原「按行锚定末尾围栏」修复 → 26 条全绿。

> 变异验证（**#260**，`NewChatCapabilityAdapter.restoreSelection`）：
> - **M1** nil 分支退回无操作（`guard let conversationID else { return }`）→ `restoreNilSelectionDeselects`、`toolPreservesNilSelectionThroughAdapter` 转红（未取消选择，用户被甩进新建空对话），`restoreNonNilSelectionSelects` 仍绿。
> - **M2** 非 nil 分支也改为取消选择（忽略入参 id）→ `restoreNonNilSelectionSelects` 转红（未切回原对话），两条 nil 用例仍绿。
> - 还原完整修复（nil → `deselectConversation()`，非 nil → `selectConversation(id:)`）→ 22 条全绿。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 11 / 11
- P2: 已覆盖 6 / 6
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（11 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationNew
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
