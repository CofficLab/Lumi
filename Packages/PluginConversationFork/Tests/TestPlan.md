# TestPlan — PluginConversationFork

## 包概述

PluginConversationFork 的实现包，包含 7 个主要类型；当前测试覆盖 40 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 40

核心组件（源码目录）:
- `Observers/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationForkButton`
- `ConversationForkCoordinator`
- `ConversationForkPlugin`
- `ConversationForkPopoverContent`
- `ConversationForkPreviewModel`
- `ConversationSummarizer`
- `ConversationForkSelectionObserver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationForkSelectionObserver**（3 条）：由 `buttonHiddenWithoutSelectedConversation`、`buttonFollowsSelectionState`、`doesNotRegisterTwice` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationForkPreviewModel**（5 条）：由 `stalePreviewDuringNewLoadIsDiscarded`、`stalePreviewAfterNewLoadIsDiscarded`、`reopenSameConversationDiscardsEarlierRequest` 等用例锁定；预览异步写回必须按代次校验身份，旧请求不得发布预览或改动加载标记（#463）。
- **综合**（28 条）：由 `summarizerEmptyFallback`、`summarizerFallbackWithHistory`、`renderHistory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ForkCancellation**（2 条）：由 `forkCancelledDuringSummaryDoesNotCreateConversation`、`forkCompletesWhenNotCancelledDuringSummary` 锁定；摘要生成期间用户取消（Cancel / 关闭弹窗）后，分叉必须在建对话前终止，不得再改动对话列表 / 选中态 / 消息。`ConversationForkCoordinator.fork` 在 `summarize` 返回后、`createConversation` 前 `try Task.checkCancellation()`；弹窗持有 `forkTask` 句柄并在 Cancel / `onDisappear` 时取消（**回归 #579**）。改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationForkSelectionObserver | 未选中对话时不注册分叉按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buttonHiddenWithoutSelectedConversation` |
| 2 | ConversationForkSelectionObserver | 选中对话后注册分叉按钮，取消选择后移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buttonFollowsSelectionState` |
| 3 | ConversationForkSelectionObserver | 重复选中同一对话不会重复注册 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRegisterTwice` |
| 4 | 综合 | Summarizer 回退摘要：无历史时返回占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `summarizerEmptyFallback` |
| 5 | 综合 | Summarizer 回退摘要：有历史时拼装本地摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summarizerFallbackWithHistory` |
| 6 | 综合 | renderHistory 渲染 user/assistant/tool 前缀 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderHistory` |
| 7 | 综合 | filteredMessages 丢弃 system 与空白消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `filteredMessagesDropsIrrelevantRolesAndEmpty` |
| 8 | 综合 | filteredMessages 仅保留最近 maxMessages 条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filteredMessagesKeepsRecentOnly` |
| 9 | 综合 | filteredMessages 截断超长单条消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `filteredMessagesTruncatesLongContent` |
| 10 | 综合 | Fork 按钮通过 sender 发送摘要到新对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forkSendsSummary` |
| 11 | 综合 | preview 统计参与摘要的消息条数与提问轮数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `previewCountsMessagesAndRequests` |
| 12 | 综合 | preview 对空对话标记为无内容 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `previewEmptyConversation` |
| 13 | 综合 | preview 以传入的源对话为准，不跟随当前选中对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `previewTargetsGivenConversation` |
| 14 | 综合 | fork 建新对话、注入摘要并透传标题/项目/模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `forkCreatesConversationAndSendsSummary` |
| 15 | 综合 | fork 以传入的源对话为准，不跟随当前选中对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forkTargetsGivenConversation` |
| 16 | 综合 | fork 对空对话抛出 emptyConversation，且不新建对话 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `forkEmptyConversationThrows` |
| 17 | 综合 | displayTitle 回退到最后一条提问 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayTitleFallsBackToLastRequest` |
| 18 | 综合 | truncate 截断超长文本并补省略号 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `truncateLongText` |
| 19 | 综合 | 仅带附件的消息参与摘要，图片只列名称/类型，不注入 base64 | 用户消息正文为空、metadata 含文本与图片附件 | `filteredMessages` 处理该消息 | 消息被保留，包含文件名与文本内容，不包含 base64 | P0 | ✅ 已覆盖 | `filteredMessagesKeepsAttachmentOnlyMessages` |
| 20 | 综合 | 二进制附件以文件名与本地路径表示 | 文件附件无 textContent、有 localPath | `summaryText(for:)` | 输出包含文件名与本地路径 | P1 | ✅ 已覆盖 | `binaryAttachmentDescription` |
| 21 | 综合 | 纯附件对话在 preview 中仍有内容并可 fork | 对话只有一条带附件的空正文 user 消息 | 调用 `preview` 与 `fork` | `hasContent` 为真、标题回退到附件名，fork 摘要包含附件名 | P0 | ✅ 已覆盖 | `attachmentOnlyConversationCanFork` |
| 22 | 综合 | 工具调用与配对的工具结果进入摘要 | 历史含 user、带 toolCalls 的 assistant、`.tool` 结果消息 | `filteredMessages` 处理该历史 | 三条都保留；assistant 含工具名与参数，结果含工具名与输出 | P1 | ✅ 已覆盖 | `filteredMessagesKeepsToolCallsAndResults` |
| 23 | 综合 | 正文为空但带工具调用的 assistant 消息仍参与摘要 | assistant 消息 content 为空、toolCalls 非空 | `filteredMessages` 处理该消息 | 消息被保留并包含工具名 | P1 | ✅ 已覆盖 | `filteredMessagesKeepsToolCallOnlyAssistant` |
| 24 | 综合 | 工具结果超长时按上限截断 | `.tool` 消息正文超过 `maxToolResultChars` | `filteredMessages` 处理该消息 | 内容带 `…[truncated]` 且不超过上限 | P0 | ✅ 已覆盖 | `filteredMessagesTruncatesLongToolResult` |
| 25 | 综合 | 回退摘要包含工具动作与结果 | 历史含带 toolCalls 的 assistant 与 `.tool` 结果 | LLM 摘要不可用时调用 `summarize` | 回退摘要包含工具名与工具输出 | P1 | ✅ 已覆盖 | `summarizerFallbackIncludesToolActivity` |
| 26 | 综合 | fork 继承源对话的自动化级别、推理强度与详细程度 | 全局 New Chat 为 Build/low/standard，源对话为 Chat/max/detailed | 执行 `fork` | 新对话取 Chat/max/detailed，而非全局值 | P1 | ✅ 已覆盖 | `forkInheritsConversationPreferences` |
| 27 | 综合 | 源对话关闭推理时 fork 不继承全局推理强度 | 全局推理为 low，源对话显式关闭推理（nil） | 执行 `fork` | 新对话 `reasoningEffort` 仍为 nil | P1 | ✅ 已覆盖 | `forkKeepsReasoningDisabledWhenSourceDisablesIt` |
| 28 | 综合 | fork 继承源对话语言，不受摘要期间切换会话影响 | 源对话英文，另一个中文对话在摘要前被选中 | 执行 `fork` | 新对话语言为英文 | P1 | ✅ 已覆盖 | `forkUsesSourceConversationLanguage` |
| 29 | 项目绑定 | 无项目源对话 fork 后副本仍无项目（**回归**） | 生产等价实现：当前项目存在，源对话由 `.none` 创建 | 执行 `fork` | 副本 `projectPath` 为 nil，不被挂到当前项目 | P0 | ✅ 已覆盖 | `forkOfUnboundConversationStaysUnbound` |
| 30 | 项目绑定 | 有项目源对话 fork 后沿用同一项目 | 当前项目 `/tmp/current-project`，源对话绑定 `/tmp/source-project` | 执行 `fork` | 副本 `projectPath` 为 `/tmp/source-project`，不受当前项目影响 | P1 | ✅ 已覆盖 | `forkOfBoundConversationKeepsItsProject` |
| 31 | 综合 | 附件解码仅限保留窗口（**回归 #1324**） | `maxMessages + 40` 条带图片附件的 user 消息 | 重置 `attachmentDecodeCount` 后调用 `filteredMessages` | 仅保留最近 `maxMessages` 条，附件解码次数不超过 `maxMessages` | P1 | ✅ 已覆盖 | `filteredMessagesBoundsAttachmentDecodeToRetainedWindow` |
| 32 | 综合 | 反向扫描跳过空消息保留最近可用条（**回归 #1324**） | 可用消息与空白消息交替，共 `maxMessages + 10` 轮 | 调用 `filteredMessages` | 保留 `maxMessages` 条可用消息，首条 `u10`、末条 `u(maxMessages+9)`，无空白 | P1 | ✅ 已覆盖 | `filteredMessagesReverseScanKeepsRecentUsableWithEmpties` |
| 33 | 综合 | fork 只发送摘要，不带走源对话未发送的附件（**回归 #578**） | 源对话有历史，输入框挂起未发送的图片与文件附件 | 执行 `fork` | 摘要消息 metadata 不含任何附件，挂起池原样保留 | P0 | ✅ 已覆盖 | `forkDoesNotConsumeUnsentComposerAttachments` |
| 34 | ConversationForkPreviewModel | 旧预览在新加载进行中晚到：不发布也不关掉加载标记（**回归 #463**） | 门闩挂起 A、B 两次快照，先打开 A 再打开 B | 先放行 A 的快照，再放行 B | A 晚到时预览仍为 nil、isLoading 仍为真；B 发布后预览属于 B | P0 | ✅ 已覆盖 | `stalePreviewDuringNewLoadIsDiscarded` |
| 35 | ConversationForkPreviewModel | 旧预览在新加载完成后晚到：不覆盖已发布的新预览（**回归 #463**） | 门闩挂起 A、B 两次快照，先打开 A 再打开 B | 先放行 B 发布预览，再放行 A | 预览仍属于 B，target 仍为 B，isLoading 为假 | P0 | ✅ 已覆盖 | `stalePreviewAfterNewLoadIsDiscarded` |
| 36 | ConversationForkPreviewModel | 同一对话重复打开：只认最新一次请求（**回归 #463**） | 对同一对话先后打开两次，两次快照都被门闩挂起 | 先放行第一次（旧代次）快照，再放行第二次 | 旧结果被丢弃且加载标记不被关闭；第二次结果正常发布 | P0 | ✅ 已覆盖 | `reopenSameConversationDiscardsEarlierRequest` |
| 37 | ConversationForkPreviewModel | 无选中对话时清空状态，晚到的旧结果也不得发布（**回归 #463**） | A 的快照在途时以 nil 打开 | 放行 A 的快照 | preview 为 nil、isLoading 为假、target 为 nil，晚到结果不写回 | P0 | ✅ 已覆盖 | `openWithoutSelectionClearsStateAndIgnoresLateResult` |
| 38 | ConversationForkPreviewModel | 单次打开正常发布预览并锁定目标对话 | 对话 A 有一条提问，快照被门闩挂起 | 打开 A 后放行快照 | 预览标题/提问/条数正确，isLoading 转假，target 为 A | P1 | ✅ 已覆盖 | `singleOpenPublishesPreview` |
| 39 | ForkCancellation | 摘要生成期间 Cancel：分叉终止，不创建/选中/发送（**回归 #579**） | 门闩把摘要挂起在 LLM 请求上，源对话有历史 | 摘要进行中取消 forkTask 再放行摘要 | fork 抛 `CancellationError`，对话条数不变、选中态仍为源对话 | P0 | ✅ 已覆盖 | `forkCancelledDuringSummaryDoesNotCreateConversation` |
| 40 | ForkCancellation | 摘要生成期间未 Cancel：分叉正常完成（#579 守卫） | 门闩把摘要挂起在 LLM 请求上，源对话有历史 | 摘要进行中不取消，直接放行摘要 | fork 正常返回，新对话被创建/选中并写入摘要首条消息 | P1 | ✅ 已覆盖 | `forkCompletesWhenNotCancelledDuringSummary` |

> 说明：全部 **40 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（#578）：把 `ConversationForkCoordinator.fork` 的发送改回隐式
> `sender.sendMessage(summary, conversationID:)`，用例 33 立即转红（摘要消息
> 带上未发送附件、挂起池被清空，4 条断言全部失败）；恢复显式空附件入口后转绿。

> 变异验证（#463）：去掉 `ConversationForkPreviewModel.open` 写回前的
> `revision == currentRevision` 守卫，用例 34-37 全部转红（旧预览覆盖新目标、
> 加载标记被旧请求关掉、nil 打开后晚到结果仍发布，共 9 条断言失败），
> 用例 38 正常路径保持绿；恢复守卫后 38 条全绿。

> 变异验证（#579）：去掉 `ConversationForkCoordinator.fork` 在 `summarize` 返回后、
> `createConversation` 前的 `try Task.checkCancellation()`，用例 39 立即转红
> （fork 不再抛 `CancellationError`，取消后仍新建对话并改选中态，3 条断言失败），
> 用例 40 正常路径保持绿；恢复取消复核后 40 条全绿。

## 覆盖率统计

- P0: 已覆盖 13 / 13
- P1: 已覆盖 21 / 21
- P2: 已覆盖 6 / 6
- **合计: 40 / 40**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（13 条）
- **P1**: 其余功能性用例（21 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 40 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationFork
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
