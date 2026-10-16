# TestPlan — PluginConversationInput

## 包概述

PluginConversationInput 是编辑器底部输入区的实现包，包含**发送 / 停止按钮**
（`SendActionBarButton`）与输入框本体（`ChatInputEditorView`）。它不实现
「发送」语义本身，只负责把用户的一次输入 / 点击，翻译成对 Provider 契约的调用，
并把回合状态渲染成按钮形态（发送 ⇄ 停止互斥切换）。

发送/停止的实际语义由 `PluginMessageSender` 的 `MessageSender` 承担；本包通过
`ConversationInputCapability` 收窄后依赖它。

核心组件:
- `ConversationInputPlugin` - 装配插件（`onBoot` 建 ChatSection 项与 Action Bar 按钮，
  `onReady` 建 Observer，`onShutdown` 拆除全部监听与条目）
- `ConversationInputCapabilityAdapter` - 把 6 个 Provider 收窄为单一能力协议
- `ConversationInputViewModel` - 输入框状态与用户意图（文本 / 附件 / 错误 / 折叠块）
- `SendActionBarViewModel` - 发送/停止按钮的状态与动作
- `SendActionBarState` - 按钮形态的唯一判定（`isSending` ⇄ `showsSendButton` / `showsStopButton`）
- `ChatInputEditorView` - AppKit `NSTextView` 编辑器与其 `Coordinator`
- `ConversationInputObserver` / `ActionBarInputObserver` / `ActionBarConversationObserver` /
  `SendActionBarConversationObserver` - 四类事件订阅

## 公开 API

### ConversationInputPlugin
- `id` = `com.coffic.lumi.plugin.conversation-input`、`order` = 83
- `metadata`（`policy: .alwaysOn`，`category: .chat`，`stage: .stable`）
- `onBoot(kernel:)` - 无 `ChatSectionProviding` 时记日志并 return；否则解析 6 个 Provider
  → 建 Adapter → 建 `ConversationInputViewModel` + `SendActionBarViewModel` → 注册 2 个
  `ChatSectionItem`（附件预览 `order: 899`、输入框 `order: 900`，均 `.bottomFixed`）
  与 1 个 `ChatSectionBarItem`（`.actionTrailing`）
- `onReady(kernel:)` - 建三个 Observer；依赖缺失时记日志并 return
- `onShutdown(kernel:)` - 取消全部 Observer，置空 ViewModel/Adapter，并移除
  三个 ChatSection 条目

### ConversationInputCapability（内部协议，唯一对外依赖面）
- 输入：`text` / `inputHeight` / `isInputFocused` / `inputCursorPosition` / `errorMessage` / `clearInput()`
- 附件：`pendingImageAttachments` / `pendingFileAttachments` / 增删 / `clearAttachments()`
- 发送：`commitUserMessage(_:imageAttachments:fileAttachments:conversationID:)`、
  `commitUserMessageInBackground(...)`、`startTurn(for:)`、`cancelCurrentRequest()`
- 会话：`selectedConversationID`、`isSending(for:)`
- 观察：`addTextObserver` / `addBlockObserver` / `addInputObserver` /
  `addMessageSenderObserver` / `addSelectedConversationObserver` / `addConversationStateObserver`
- Metrics：`beginMetrics` / `markMetrics` / `endMetrics`

### SendActionBarViewModel
- `state: SendActionBarState`（`private(set)`）
- `init(capability:)` - 以能力层快照初始化 `isSending` 与 `canSend`
- `updateInputText(_:)` / `updateAttachments()` / `refreshConversationState()`
- `send()` - 空白短路 → 清文本与错误 → 纯文本走**同步提交**、带附件走**后台编码提交**
  → `wasQueued` 为真则不启动回合
- `cancel()` - 委派 `capability.cancelCurrentRequest()`

### 关键行为契约（实现约定，非协议要求）
- **按钮互斥**：`isSending` 为真只渲染 `StopButton`，否则只渲染 `SendButton`
- **可发送判定唯一**：`hasAttachments || !trimmed.isEmpty`，纯空白永不亮
- **附件路径强制后台**：有附件时必须走 `commitUserMessageInBackground`，
  同步路径必须零调用
- **排队不抢跑**：`wasQueued == true` 或 `commit == nil` 时一律不调 `startTurn`
- **文本必须回写**：`updateInputText` / `setText` 都要写回 `capability.text`，
  否则粘贴、`typeText` 等直写路径点发送会静默失效
- **装配降级**：四个 Provider（Input / Sender / Conversations / ConversationState）
  缺任一即不建发送栏 ViewModel，按钮降级为可点击的错误弹窗

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 装配 | 四 Provider 齐备时创建发送栏 ViewModel | 注册 4 个 Provider 替身 | 复刻 `onBoot` 装配判定 | `missing` 为空，ViewModel 可构造 | P0 | ✅ 已覆盖 | `allProvidersPresentCreatesViewModel` |
| 2 | 装配 | 分别缺 Sender / ConversationState / Input / Conversations 时不创建 ViewModel | 逐一抽掉其中一个 Provider | 走同一判定镜像 | 四种缺一场景均判为不创建，并记录缺失名单 | P0 | ✅ 已覆盖 | `missingSenderDisablesViewModel`、`missingConversationStateDisablesViewModel`、`missingInputDisablesViewModel`、`missingConversationManagingDisablesViewModel` |
| 3 | 初始态 | 初始状态镜像能力层的输入文本与当前回合 | text 非空 + 选中会话正在发送 | 构造 ViewModel | `isSending == true`、`canSend == true`、显示停止按钮 | P1 | ✅ 已覆盖 | `initialStateMirrorsCapability` |
| 4 | 初始态 | 无选中会话时不显示发送中 | 空能力层 | 构造 ViewModel | `isSending == false`、`canSend == false`、显示发送按钮 | P1 | ✅ 已覆盖 | `initialStateWithoutSelectionIsNotSending` |
| 5 | 判定 | 纯空白输入不可发送 | 空能力层 | `updateInputText("   \n\t ")` | `canSend == false` | P0 | ✅ 已覆盖 | `whitespaceOnlyInputCannotSend` |
| 6 | 判定 | 仅有附件时同样可以发送 | 无文本 + 一张图片 | 先 `updateAttachments()` 再挂附件 | 无附件不可发；有附件后可发 | P0 | ✅ 已覆盖 | `attachmentsAloneEnableSend` |
| 7 | 判定 | 附件被移除后恢复为不可发送 | 一个文件附件 | 移除附件后 `updateAttachments()` | `canSend` 由 true 回到 false | P1 | ✅ 已覆盖 | `removingAttachmentsDisablesSend` |
| 8 | 发送 | 空白输入且无附件时不提交任何消息 | text 为 `"   "` | `send()` | 同步/后台提交均零调用、**输入框内容不清空**、不启动回合 | P0 | ✅ 已覆盖 | `sendIgnoresBlankInput` |
| 9 | 发送 | 纯文本走同步提交并随后启动回合 | text 带前后空格 | `send()` | 内容被 trim；`conversationID` 显式传 `nil`；输入框立即清空、错误复位；同步路径命中、后台路径零调用；回合随后启动且会话 ID 正确 | P0 | ✅ 已覆盖 | `sendCommitsTrimmedTextSynchronously` |
| 10 | 发送 | 带附件的消息强制走后台编码提交 | text + 一张图片 | `send()` | 同步提交零调用；后台提交被调用且附件完整；回合随后启动 | P0 | ✅ 已覆盖 | `sendUsesBackgroundPathForAttachments` |
| 11 | 发送 | 排队的消息不会启动回合 | `userMessageID == nil`（已排队） | `send()` 后等待调度结束 | 提交一次，`startTurn` 零调用 | P0 | ✅ 已覆盖 | `queuedCommitDoesNotStartTurn` |
| 12 | 发送 | 提交返回 nil 时不启动回合 | 能力层返回 `nil` | `send()` 后等待调度结束 | 提交一次，`startTurn` 零调用 | P1 | ✅ 已覆盖 | `nilCommitDoesNotStartTurn` |
| 13 | 错误 | 提交失败时把错误写入错误状态 | `commitUserMessage` 抛错 | `send()` | `errorMessage` 为错误描述；不启动回合 | P0 | ✅ 已覆盖 | `sendPropagatesCommitFailure` |
| 14 | 错误 | 发送前清除旧的错误提示 | 预置 `errorMessage = "stale error"` | `send()` | 发送后 `errorMessage == nil` | P1 | ✅ 已覆盖 | `sendClearsPreviousError` |
| 15 | 停止 | 停止按钮取消当前请求 | 空能力层 | `cancel()` | `cancelCurrentRequest` 被调用 1 次 | P0 | ✅ 已覆盖 | `cancelDelegatesToCapability` |
| 16 | 会话 | 刷新会话状态读取当前会话的发送中标记 | 选中会话 A，A 空闲 / B 发送中 | 先构造（应为非发送中），再切到 B 并刷新 | 切到发送中的 B 后 `isSending == true` | P1 | ✅ 已覆盖 | `refreshConversationStateReadsSelectedConversation` |
| 17 | 会话 | 没有选中会话时刷新会复位发送中标记 | 选中会话在发送中 | 把 `selectedConversationID` 置 nil 后刷新 | `isSending == false` | P1 | ✅ 已覆盖 | `refreshConversationStateClearsWithoutSelection` |
| 18 | 观察 | 输入文本变化后同步可发送状态 | 装配 `ActionBarInputObserver` | 推入 `"hello"` → 推入 `"   "` | `canSend` 随之 true → false | P1 | ✅ 已覆盖 | `inputObserverTracksTextChanges` |
| 19 | 观察 | 附件变化事件同步可发送状态 | 装配 `ActionBarInputObserver` | 挂/删文件附件并各推一次 `.attachmentsChanged` | 每次 `canSend` 同步翻转 | P1 | ✅ 已覆盖 | `inputObserverTracksAttachmentChanges` |
| 20 | 观察 | Observer 初始化时立即同步一次当前快照 | `capability.text = "draft"` | 构造 Observer，再推入空文本 | 构造即 `canSend == true`（不需等事件）；推空后转 false | P1 | ✅ 已覆盖 | `inputObserverSeedsInitialSnapshot` |
| 21 | 观察 | 取消后不再接收文本变化 | 装配 Observer | `cancel()` 后推文本 | `canSend` 保持 false | P2 | ✅ 已覆盖 | `inputObserverStopsAfterCancel` |
| 22 | 按钮切换 | 回合开始事件切换到停止按钮 | 选中会话空闲 | 标记会话发送中 + 推 `.updated` | 显示停止按钮、发送按钮消失 | P0 | ✅ 已覆盖 | `conversationObserverSwitchesToStopButton` |
| 23 | 按钮切换 | 回合结束事件切回发送按钮 | 选中会话发送中 | 清标记 + 推 `.updated` | 显示发送按钮 | P0 | ✅ 已覆盖 | `conversationObserverSwitchesBackToSendButton` |
| 24 | 按钮切换 | 切换会话时按新会话重新判断发送状态 | 选中空闲会话 A | 切到发送中的 B，再切回 A | 依次为停止按钮 → 发送按钮 | P0 | ✅ 已覆盖 | `conversationObserverFollowsSelectedConversation` |
| 25 | 按钮切换 | 会话被移除时复位发送状态 | 会话发送中 | 推 `.removed` | 回到发送按钮 | P1 | ✅ 已覆盖 | `conversationObserverHandlesRemovedConversation` |
| 26 | 观察 | 取消后不再接收会话事件 | 装配会话 Observer | `cancel()` 后推状态 | 按钮形态不再变化 | P2 | ✅ 已覆盖 | `conversationObserverStopsAfterCancel` |
| 27 | 回归 | `setText` 非空白文本后立即可发送，不等 Observer 回读 | 初始不可发送 | `setText("hello")` | `canSend` 立刻为 true；本地 `text` 与 `capability.text` 同步 | P0 | ✅ 已覆盖 | `setTextEnablesSendImmediately` |
| 28 | 回归 | `setText` 纯空白 / 清空文本回到不可发送 | — | 依次 `setText("   \n\t ")`、`setText("")` | 每次都不可发送 | P0 | ✅ 已覆盖 | `setTextWhitespaceRemainsNotSendable`、`setTextClearingResetsSendable` |
| 29 | 回归 | `setText` 与 `refresh` 的 canSend 判定一致 | 6 组代表性文本（含空串、空白、换行、多字节） | 每组先 `setText` 记录结论，再 `refresh()` | 两次判定完全相同，无按钮抖动 | P0 | ✅ 已覆盖 | `setTextAgreesWithRefresh` |
| 30 | 回归 | `setText` 后 `send` 立即可用 | 能力层可返回 commit | `setText("hi")` 后立即 `send()` | 提交 1 次且内容为 `"hi"` | P0 | ✅ 已覆盖 | `sendWorksRightAfterSetText` |
| 31 | 回归 | 纯空白输入时 `send` 不提交 | 能力层可返回 commit | `setText("   \n  ")` 后 `send()` | 零提交 | P0 | ✅ 已覆盖 | `sendIgnoresWhitespaceOnlyText` |
| 32 | 回归 | `setText` 把文本旁路通知到派生的发送按钮 | 两个 ViewModel + 手工接 `onTextWritten` | `setText("hello")`，再 `updateInputText("")` | 回调恰好一次；按钮立即可用；清空后回到不可用 | P0 | ✅ 已覆盖 | `setTextNotifiesActionBar` |
| 33 | 回归 | 发送清空草稿后编辑器内容不被回灌 | 回车触发 `send()` | 输入「继续」→ 回车 → 校验差异方向 | 草稿已清空且消息已提交；`shouldPublishEditorTextUp` 对旧文本返回 false（下发而非上报） | P0 | ✅ 已覆盖 | `editorTextIsNotRepublishedAfterSendClearsDraft` |
| 34 | 回归 | 真正由编辑器产生的、binding 未知的写入仍然上报 | 逐键上报 `"a"` 后 | 校验 `shouldPublishEditorTextUp("a pasted block")` | 返回 true（粘贴 / 语音 / `typeText` 路径不丢内容） | P0 | ✅ 已覆盖 | `editorOnlyContentStillPublishesUp` |
| 35 | 回归 | binding 下发后编辑器的同值差异仍按下发方向处理 | 上报 `"old"` 后下发 `"new"` | 校验 `"new"` 与 `"edited by user"` | 前者 false（同值不上报）、后者 true（后续编辑仍上报） | P1 | ✅ 已覆盖 | `bindingPushedDownStillWinsForMatchingText` |
| 36 | 编辑器 | marked text 在 IME 提交前不外泄 | 带 marked 的 `NSTextView` | 置 `isMarked = true` 后推 `textDidChange`，再提交「你」 | 组合中 draft/cursor 不变、placeholder 隐藏；提交后 draft 为「你」、cursor 为 1 | P1 | ✅ 已覆盖 | `markedTextIsNotPublishedUntilCommit` |
| 37 | 编辑器 | 原生编辑器在候选词提交时清除组合守卫 | 原生 `EditorTextView` | `setMarkedText` → `insertText` | 提交后 `isIMEComposing == false` | P1 | ✅ 已覆盖 | `editorClearsCompositionOnInsert` |
| 38 | 编辑器 | 光标 binding 在提交字符后保持最新 | 仅 Input Provider | `setCursorPosition(1)` | ViewModel 与能力层 `inputCursorPosition` 均为 1 | P1 | ✅ 已覆盖 | `viewModelKeepsCursorBindingInSync` |
| 39 | 编辑器 | 宽度为 0 的临时布局不上报高度 | — | 分别以宽度 0 / 640 调 `measuredHeight` | 宽度 0 返回 nil；宽度 640 返回 160 | P2 | ✅ 已覆盖 | `zeroWidthLayoutDoesNotProduceHeight` |
| 40 | 编辑器 | 拆解编辑器时取消延迟的高度绑定 | 装配 Coordinator | 排一次高度更新后立即 dismantle | `isActive == false`、不再接收该 textView、height 未被改写 | P2 | ✅ 已覆盖 | `dismantlingEditorCancelsDeferredBinding` |
| 41 | 编辑器 | 活跃编辑器正常应用延迟的高度绑定 | 装配 Coordinator | 排一次高度更新后等待 50ms | height 被更新为 maxHeight | P2 | ✅ 已覆盖 | `activeEditorAppliesDeferredHeightBinding` |
| 42 | 编辑器 | 回车在发送前先上报当前已提交文本 | 装配 Coordinator | 置文本「你」→ 触发 `insertNewline` | draft 为「你」且 `onSubmit` 被调用 1 次 | P0 | ✅ 已覆盖 | `returnPublishesDraftBeforeSubmit` |
| 43 | 拖放 | 常见图片文件被识别为聊天图片 | — | 校验 PNG / HEIC / PDF | 前两者为 true、PDF 为 false | P1 | ✅ 已覆盖 | `imageDropRuleRecognizesCommonImages` |
| 44 | 拖放 | 目录与文件分开识别 | 临时目录 + 目录内文件 | 校验 `isDirectoryURL` | 目录为 true、其内文件为 false | P1 | ✅ 已覆盖 | `directoryDropRuleRecognizesDirectories` |
| 45 | 会话 | 切换会话清空未提交的文本与附件 | 真实 Conversation / Message / Sender | 写入草稿 + 图片 + 文件附件后切换会话 | 文本与两个附件池全部清空 | P0 | ✅ 已覆盖 | `switchingConversationsClearsAttachments` |
| 46 | 观察 | 输入错误状态通过 typed observer 同步并支持取消 | 仅 Input Provider | 写 `errorMessage` → `cancel()` → 再写 nil | 同步到 ViewModel；cancel 后不再同步 | P1 | ✅ 已覆盖 | `inputObserverTracksErrorState` |
| 47 | 折叠块 | 折叠块按阈值决定 chip 还是纯文本插入 | 短 / 长 / 纯空白三种内容 | 校验 `shouldCollapse` | 短与纯空白为 false、长内容为 true | P1 | ✅ 已覆盖 | `pendingBlockCollapsesOnlyAboveThreshold` |
| 48 | 折叠块 | 递交折叠块后待插入、消费后清空 | 仅 Input Provider | `enqueue` → 消费无关 ID → 消费正确 ID | 待插入项与 ID / 标题就位并自动聚焦；无关 ID 不误清；正确 ID 消费后清空 | P1 | ✅ 已覆盖 | `enqueueThenConsumePendingBlock` |
| 49 | 视图 | placeholder 不拦截编辑器点击 | placeholder 标签 | 校验 `hitTest(.zero)` | 返回 nil（点击穿透到编辑器） | P2 | ✅ 已覆盖 | `placeholderAllowsClickThrough` |

### 补充轮次（ID 50–88）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 50 | 索引 | ASCII 文本两种索引等价且越界被夹取 | `"abc"` | 双向换算 + 越界 / 负值输入 | 合法值逐一对应；99 夹到 3、-5 夹到 0 | P1 | ✅ 已覆盖 | `asciiIndicesRoundTripAndClamp` |
| 51 | 索引 | emoji 的 Swift 索引落在 UTF-16 代理对另一侧 | `"😀"` | 换算 index 1 / 0 | 1 → 2、0 → 0（单 grapheme 占 2 个 UTF-16 单元） | P0 | ✅ 已覆盖 | `emojiSwiftIndexMapsToSurrogateMidpoint` |
| 52 | 索引 | UTF-16 偏移落在代理对中间时回退到最近合法边界 | `"a😀b"` | 换算 1 / 2 / 3 / 99 | 1 → 1、2 → 1（无 grapheme 对应，回退不越界）、3 → 2、99 夹到 UTF-16 末尾 3 | P0 | ✅ 已覆盖 | `utf16IndexInsideSurrogatePairFallsBack` |
| 53 | 索引 | 两套索引在所有 grapheme 边界上互为逆运算 | 含 emoji 与多字节文本 | 对每个 Swift 索引做往返换算 | 全部往返一致，无光标错位 | P0 | ✅ 已覆盖 | `indicesAreInversesAtGraphemeBoundaries` |
| 54 | 回车 | 小键盘与主键区回车都识别，带修饰键不发送 | keyCode 36 / 76 / 53 | 逐个 keyCode 与 modifier 组合判定 | 36 / 76 为真；Shift/Option/Command/Control + 回车全部为假 | P0 | ✅ 已覆盖 | `returnKeyRecognitionRespectsModifiers` |
| 55 | 回车 | 三个插入类命令都被识别为回车命令 | — | 判定 3 个 insert 选择器 + `insertText` | 前三为真、`insertText` 为假 | P1 | ✅ 已覆盖 | `insertCommandsAreRecognized` |
| 56 | 拖放 | 绝对路径被解析为文件 URL | `/tmp/a.txt` | 走 `fileURLs` | `isFileURL == true` 且 path 正确（`URL(string:)` 分支不命中，靠 `/` 前缀兜住） | P1 | ✅ 已覆盖 | `absolutePathIsParsedAsFileURL` |
| 57 | 拖放 | `file://` URL 解析并还原百分号编码 | `/tmp/a%20b.txt` | 走 `fileURLs` | path 为 `/tmp/a b.txt` | P1 | ✅ 已覆盖 | `fileSchemeURLIsParsed` |
| 58 | 拖放 | `file://localhost/` 前缀被归一化 | `file://localhost/tmp/c.txt` | 走 `fileURLs` | path 为 `/tmp/c.txt` | P2 | ✅ 已覆盖 | `localhostFileSchemeIsNormalized` |
| 59 | 拖放 | `~` 开头路径展开为用户主目录 | `~/Documents` | 走 `fileURLs` | 不再以 `~` 开头，且等于主目录 + `/Documents` | P1 | ✅ 已覆盖 | `tildePathIsExpanded` |
| 60 | 拖放 | 多行路径按行拆成多个 URL | 3 行绝对路径 | 走 `fileURLs` | 得到 3 个 URL，顺序保持 | P1 | ✅ 已覆盖 | `multilinePathsSplitPerLine` |
| 61 | 拖放 | 前后空白与空行被正确跳过 | 含空行 / 纯空白行的多行串 | 走 `fileURLs` | 只产出 2 个有效 URL | P1 | ✅ 已覆盖 | `multilinePathsTrimAndSkipBlanks` |
| 62 | 拖放 | 普通文本不被误当成路径 | `hello world` / 空串 / 纯空白 | 走 `fileURLs` | 全部产出空数组（`URL(string:)` 非 nil 但 `isFileURL` 为假，必须被否决） | P0 | ✅ 已覆盖 | `nonPathTextYieldsNoURL` |
| 63 | 拖放 | 单值入口与多值入口首项一致 | 路径 / 非路径各一 | 分别调两个入口 | 结果一致；非路径为 nil | P2 | ✅ 已覆盖 | `singleValueEntryMatchesFirstOfMultiple` |
| 64 | 类型 | 图片扩展名大小写不敏感，非图片与无扩展名被否决 | 9 种图片扩展 + 5 种非图片 + 无扩展名 | 逐个判定 | 图片全为真；其余全为假 | P1 | ✅ 已覆盖 | `imageExtensionMatchingIsCaseInsensitive` |
| 65 | 附件 | 移除图片附件按 ID 精确命中 | 两个图片附件 | 移除其一 | 仅剩另一个，能力层与 ViewModel 一致 | P1 | ✅ 已覆盖 | `removeImageAttachmentTargetsSingleID` |
| 66 | 附件 | 移除文件附件按 ID 精确命中 | 两个文件附件 | 移除其一 | 仅剩另一个 | P1 | ✅ 已覆盖 | `removeFileAttachmentTargetsSingleID` |
| 67 | 附件 | 移除不存在的 ID 是安全空操作 | 一个文件附件 | 用随机 UUID 移除图片与文件 | 原附件不受影响，无崩溃 | P1 | ✅ 已覆盖 | `removingUnknownAttachmentIsNoOp` |
| 68 | 附件 | 附件池变化同步刷新列表与可发送状态 | 空池 → 图片池 → 空池 | 逐次挂载 / 清空并 refresh | `hasAttachments` 与 `canSend` 同步翻转 | P1 | ✅ 已覆盖 | `attachmentPoolChangeRefreshesState` |
| 69 | 拖放 | 目录路径按需换行插入并聚焦 | 空输入框 | 连续拖入两个目录 | 首次直接写入；第二次追加换行；`isInputFocused` 为真 | P1 | ✅ 已覆盖 | `droppingDirectoryInsertsPathIntoText` |
| 70 | 拖放 | 已有内容以换行结尾时不重复换行 | text 以 `\n` 结尾 | 拖入目录 | 结果只有一处换行 | P1 | ✅ 已覆盖 | `droppingDirectoryAfterTrailingNewlineDoesNotDouble` |
| 71 | 拖放 | 图片进入图片池并聚焦 | 真实临时 PNG 文件 | `attachImage` 后等待 | MIME 按扩展名为 `image/png`、base64 正确、文件名保留、聚焦 | P1 | ✅ 已覆盖 | `droppingImageAttachesToImagePool` |
| 72 | 拖放 | 空文件不进图片池 | 0 字节 PNG | `attachImage` 后等待一轮 | 池为空且不产生错误提示 | P2 | ✅ 已覆盖 | `droppingEmptyImageIsIgnored` |
| 73 | 拖放 | 普通文件进入文件池并聚焦 | 真实临时 txt 文件 | `attachFile` 后等待 | MIME `text/plain`、`textContent` 正确、聚焦 | P1 | ✅ 已覆盖 | `droppingFileAttachesToFilePool` |
| 74 | 拖放 | 不可读文件错误提示可见 | 不存在的路径 | `attachFile` 后等待 | 错误提示非空，附件池为空 | P1 | ✅ 已覆盖 | `droppingUnreadableFileSurfacesError` |
| 75 | 错误 | 错误提示可被显式清除 | 预置错误 | `dismissError()` | ViewModel 与能力层同时清空 | P2 | ✅ 已覆盖 | `dismissErrorClearsMessage` |
| 76 | 绑定 | 焦点与高度绑定双向同步 | — | 依次 setFocused / setInputHeight | ViewModel 与能力层两侧一致，翻转也生效 | P2 | ✅ 已覆盖 | `focusAndHeightBindingsWriteThrough` |
| 77 | 观察 | 文本变化触发整表刷新 | 装配 Observer | 推文本 | ViewModel 文本更新且 `revision` 递增（走整表 refresh） | P1 | ✅ 已覆盖 | `textChangeRefreshesViewModel` |
| 78 | 观察 | 附件变化刷新，但回合事件被忽略 | 装配 Observer | 依次推附件 / `.started` / `.turnCompleted` | 附件事件刷新列表；回合事件**不**改变 `revision`（误路由会导致每轮回复重建输入框） | P1 | ✅ 已覆盖 | `attachmentEventRefreshesButTurnEventsAreIgnored` |
| 79 | 观察 | 错误提示变化同步到 ViewModel | 装配 Observer | 推 `errorMessageChanged` | ViewModel 错误提示同步 | P1 | ✅ 已覆盖 | `errorMessageChangeIsSynchronized` |
| 80 | 观察 | 折叠块递交后进入待插入状态 | 装配 Observer | 推 `blockSubmitted` | `pendingBlock` 的 id / 标题就位 | P1 | ✅ 已覆盖 | `blockSubmissionEnqueuesPendingBlock` |
| 81 | 观察 | 取消后所有事件都不再影响 ViewModel（**回归**） | 装配 Observer | `cancel()` 后推文本 / 错误 / 折叠块 | 三者全部无效 | P0 | ✅ 已覆盖 | `cancelStopsAllEventRouting` |
| 82 | 降级 | 输入读操作回落到安全默认值 | 全 Provider 缺失 | 逐个读属性 | 空串 / nil / false / 0，高度回落到 `minHeight` 而非 0 | P0 | ✅ 已覆盖 | `inputReadsFallBackToDefaults` |
| 83 | 降级 | 写入与清理在缺失时不崩溃 | 全 Provider 缺失 | 写全部输入属性 + clear | 读回仍为默认值，写入被安全丢弃 | P0 | ✅ 已覆盖 | `writesAreSafeWithoutProviders` |
| 84 | 降级 | 发送类操作返回 nil 而非抛错 | 全 Provider 缺失 | 同步 / 后台提交 + 取消 + 启动回合 | 两个提交均 nil，取消与启动回合为无害 no-op | P0 | ✅ 已覆盖 | `sendOperationsDegradeToNil` |
| 85 | 降级 | 附件读回落到空集合 | 全 Provider 缺失 | 读池 + 增删 | 恒为空集合，增删静默丢弃 | P1 | ✅ 已覆盖 | `attachmentReadsFallBackToEmpty` |
| 86 | 降级 | 会话查询回落到 nil / false | 全 Provider 缺失 | 读选中会话与 isSending | nil / false（含 nil 入参） | P1 | ✅ 已覆盖 | `conversationQueriesFallBack` |
| 87 | 降级 | 指标缺失时 beginMetrics 返回 nil | 全 Provider 缺失 | 调 begin / mark / end | begin 返回 nil；用真实 trace 调 mark/end 不崩溃 | P2 | ✅ 已覆盖 | `metricsDegradeGracefully` |
| 88 | 降级 | 订阅返回可安全 cancel 的空句柄 | 全 Provider 缺失 | 注册 6 个订阅并（含重复）cancel | 全部不崩溃——调用方无差别持有并 cancel | P0 | ✅ 已覆盖 | `observersDegradeToNoopHandles` |

> 说明：全部 **88 条场景 / 93 个测试方法**已在 macOS 上实跑通过
> （`swift test` → 93 tests in 11 suites passed）。
>
> 实现中几条易错约定已在用例里显式锁定：
> - **附件路径必须后台化**（ID 10）：同步 `commitUserMessage` 不做编码，附件消息走它会丢内容，
>   用例同时断言同步路径零调用，避免将来「顺手统一成一条路径」。
> - **`send()` 必须回写 `capability.text`**（ID 27/32）：按钮的 `canSend` 判定与
>   `send()` 读取的是**两个来源**（前者来自 `updateInputText` 的入参，后者读能力层）。
>   只判亮不写回，粘贴与 UI 测试 `typeText` 会看到「按钮亮着、点了没反应」。
> - **`shouldPublishEditorTextUp` 的差异方向判定**（ID 33–35）：发送清空草稿与用户编辑
>   在代码里长得一样，只有「此前是否上报过同样内容」能区分，判反即出现
>   「回车发送后输入框文字不消失」。
> - **装配降级判定被镜像复制**（ID 1–2）：`onBoot` 的四项 `if ... != nil` 与测试里的
>   `createsActionBarViewModel` 是两份实现，改动必须同步，否则测试通过而线上红点。
> - **句柄必须显式 `cancel()`**（ID 81）：丢弃本地引用不等于退订，Provider 侧的
>   观察者表仍留着回调。`ConversationInputObserver.cancel()` 曾漏掉两个句柄，
>   插件重复装配后回调持续累积——本轮测试即由此发现并修复。
> - **UTF-16 与 Swift 索引是两套坐标系**（ID 51–53）：`NSTextView` 的选区是 UTF-16
>   偏移，`String.Index` 按 grapheme 计数，emoji 让两者不再相等。

## 覆盖率统计

- P0: 已覆盖 33 / 33
- P1: 已覆盖 43 / 43
- P2: 已覆盖 12 / 12
- **合计: 88 / 88**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 装配降级、可发送判定、发送/停止按钮形态切换、提交失败上报、
  直写路径（`setText` / 回车 / 拖放清空）的回归、Observer 退订、UTF-16 索引换算
- **P1**: 会话切换与状态刷新、附件生命周期与拖放、Observer 事件路由与初始快照、
  折叠块、拖放路径解析、错误提示
- **P2**: Observer cancel 释放、编辑器延迟绑定与布局测量、placeholder 命中测试、
  localhost 归一化、空文件容错

## 跨平台说明

- Package 声明 macOS 14+ / iOS 17+，但编辑器基于 AppKit `NSTextView`，
  **ID 33–42 的编辑器用例为 macOS 专属**，iOS 上不适用
- `SendActionBarViewModel` / `ConversationInputViewModel` / Observer 为纯 Foundation 逻辑，
  macOS 与 iOS 行为一致
- 所有被测类型标注 `@MainActor`，测试套件同样标注 `@MainActor` 并在主线程执行；
  发送路径含 `Task { @MainActor }` 调度，用例用 `waitUntil` / `awaitSettle` 等待而非 `sleep`

## 测试执行

```bash
cd Packages/PluginConversationInput
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件（ID 33 即「回车发送后草稿不清空」的回归）
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **装配镜像同步** → 改动 `onBoot` 的 Provider 判定时，必须同步
   `SendActionBarWiringTests.createsActionBarViewModel`
