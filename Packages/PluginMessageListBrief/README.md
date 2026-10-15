# PluginMessageListBrief — Message List V1 (Brief)

Manual + automated test reference for the V1 message list.

V1 groups a conversation by **Agent Turn** and keeps everything else out of the way. Each turn shows
the user message that triggered it, a collapsible process section, and the final reply. Live progress
is reported by a single status card pinned to the bottom of the list, not inside the turns.

## Package

- Product: `PluginMessageListBrief`
- Platform: macOS 14+
- Swift tools: 6.0

## Before you start

Set the toolbar **Response Detail** chip to **L (Brief)**. That is the only setting V1 reacts to;
at any other level a different message list is shown instead.

> This package must not depend on other plugin packages, and other plugin packages must not depend on
> it. Plugins communicate only through `Provider*` / `Kit*` contracts, assembled by the host
> (`Factory*`). Cross-plugin references break independent loading and unloading.

## Test cases

测试矩阵按「自动化覆盖」与「仅人工验收」两栏区分。单元测试位于
`Tests/PluginMessageListBriefTests/`，UI 测试位于
`LumiUITests/LumiMessageListBriefUITests.swift`。夹具在
`Sources/PluginMessageListBrief/MessageListBriefUITestingSupport.swift`
（仅 DEBUG 编译）。

| 缩写 | 含义 |
| --- | --- |
| ✅ | 已有自动化断言（单元或 UI） |
| 🖱 | 依赖真实 NSScrollView 行为 / 鼠标 / 视觉，目前仅人工验收 |
| 🔧 | 由单元测试间接覆盖（不变式 / 常量） |

### 1. First open of a conversation

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 1.1 | Open a conversation that already has history | A centered loading view appears: the Brief icon, `Loading messages…`, and `Brief mode`. The list behind it is dimmed and does not accept clicks. | ✅ `ListPresentationTests.loadingStateDuringActivate` |
| 1.2 | Wait for loading to finish | The loading view disappears in one step. The list is already positioned at the bottom — you never see the top of the conversation first, and no jump-to-bottom animation is shown. | 🖱 |
| 1.3 | Check the first visible turn | The viewport top shows the start of a turn, not a turn cut in half. | 🖱 |
| 1.4 | Check the top of the list | `Load earlier messages` is present when older turns exist, and absent when the whole conversation fits on the first page. | ✅ `ListPresentationTests.loadEarlierHiddenWhenPageFits` / `loadEarlierVisibleWhenHistoryExceedsPage` |
| 1.5 | Switch to another conversation and back | Each switch clears in-flight scroll work and returns the list to the bottom. No content from the previously selected conversation is shown. | ✅ `ListPresentationTests.switchConversationClearsState` / `rapidConversationSwitchingIsSafe` |

### 2. Turn layout

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 2.1 | Read any finished turn | Top to bottom: the user message, the process disclosure row, then the final reply below the disclosure. | ✅ `AgentTurnProjectionTests.finishedTurnLayout` |
| 2.2 | Count user messages inside one turn group | Exactly one. | ✅ `AgentTurnProjectionTests.finishedTurnLayout` |
| 2.3 | Send a second message before the first turn finishes | The new user message appears as its own turn group; turns are not merged. | ✅ `AgentTurnProjectionTests.twoUserMessagesRemainSeparateTurns` |
| 2.4 | Look for standalone tool result rows | None. Tool calls stay visible inside the assistant message. | ✅ `AgentTurnProjectionTests.toolAndSystemRowsAreHidden` |
| 2.5 | Look for standalone system or error rows | Standalone system rows are not rendered. Error messages stay visible as the turn's terminal reply. | ✅ `AgentTurnProjectionTests.toolAndSystemRowsAreHidden` + `failedTurnSurfacesErrorAsLastMessage` |
| 2.6 | Find a conversation where a real context compaction happened | The compaction event renders as its own independent row between turns. Pre-warm / legacy compaction events stay hidden. | ✅ `ListPresentationTests.contextCompactionTimelineEvents` |
| 2.7 | Watch a turn while the reply is still streaming | The turn does not grow a streaming reply block. Live progress is reported only by the bottom status card (section 6). | ✅ `AgentTurnProjectionTests.streamingTurnHasNoLastMessage` |
| 2.8 | Open a turn that ended without producing a reply | Only the user message and the disclosure row are present — no empty reply block underneath. | ✅ `AgentTurnProjectionTests.emptyReplyTurnHidesLastMessage` |

### 3. Process disclosure

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 3.1 | Read the disclosure row of a finished turn | A chevron plus a one-line summary, with a divider below. Default state is collapsed. | 🖱（默认折叠） |
| 3.2 | Check the summary of a turn with tool calls | Shows the step count and elapsed time, e.g. `执行了3个步骤 · 12秒` ("executed 3 steps · 12s"). | ✅ `AgentTurnProjectionTests.finishedDisclosureTitleShowsStepsAndDuration` + UI `testProcessDisclosureShowsStepCount` |
| 3.3 | Check the summary of a turn with no tool calls | The step count falls back to the number of process messages. | ✅ `AgentTurnProjectionTests.disclosureFallsBackToProcessCount` |
| 3.4 | Click the disclosure row | The chevron flips to `chevron.down` and the process messages appear below the row. | ✅ UI `testProcessDisclosureExpandsAndCollapses` |
| 3.5 | Click again | The chevron returns to `chevron.right` and the process messages are removed. | ✅ UI `testProcessDisclosureExpandsAndCollapses`（折叠可见性允许滚动出视口） |
| 3.6 | Watch the disclosure row of a running turn | The summary uses the running label plus the step count, and the duration **ticks every second**. | ✅ `AgentTurnProjectionTests.runningDisclosureTitleUsesRunningLabel` |
| 3.7 | Expand and collapse repeatedly | The expand/collapse animates. Rows outside the turn do not jump and Markdown content does not flash. | 🖱 |
| 3.8 | Click inside an expanded process message | The click reaches the message content; it is not swallowed by the disclosure row. | 🖱（依赖 SwiftUI Button 命中测试） |

### 4. Load earlier messages

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 4.1 | Open a conversation with more history than one page | `Load earlier messages` is shown at the top of the list. | ✅ `ListPresentationTests.loadEarlierVisibleWhenHistoryExceedsPage` |
| 4.2 | Click it | The label is replaced by a small spinner while loading. | 🖱（由 `ConversationMessageListVM.isLoadingEarlier` 驱动） |
| 4.3 | Watch the viewport during loading | Older turns are prepended above, and the turn that was previously at the top stays pinned near the top of the viewport — no content jump. | 🔧 `MessageListScrollCoordinator.postPrependDelayNs == 50ms` |
| 4.4 | Click repeatedly while a load is in flight | No duplicate or skipped turns. | ✅ `ListPresentationTests.loadEarlierDoesNotDuplicateWhenReentrant` |
| 4.5 | Keep loading until the history runs out | The button disappears once no earlier history is left. | ✅ `ListPresentationTests.loadEarlierHidesButtonWhenExhausted` + `MessageListServicesTests.loadEarlierExhaustsAtTop` |
| 4.6 | Switch conversations and come back | The button reappears if earlier history still exists, and the list returns to the bottom. | ✅ `ListPresentationTests.switchConversationClearsState` |

### 5. Scrolling behaviour

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 5.1 | Stay at the bottom while a reply streams in | The list follows the growing content and keeps the newest turn fully visible. | 🖱 + 🔧 `MessageListScrollCoordinator.postAppendDelayNs` / `bottomEnterTolerance` |
| 5.2 | Scroll up to read history while a reply streams in | The list does not pull you back down. The viewport stays where you put it. | 🖱 |
| 5.3 | Scroll back down to the bottom after scrolling up | Auto-follow re-attaches and resumes. | 🖱 |
| 5.4 | Send a message while scrolled up in history | The new turn is brought into view even though you were reading older messages. | 🖱 |
| 5.5 | Check where the new turn lands | The top of the new turn sits around the **upper quarter** of the viewport, not at the bottom edge. | 🔧 `MessageListSendPositioning.targetTopFraction == 0.25` |
| 5.6 | Wait for that turn to finish | Once no turn is active, the list settles back to the real bottom of the content — the reserved space disappears. | 🖱 |
| 5.7 | Send a message while already at the bottom | The same upper-quarter placement applies; the newest content is not hidden behind the input area. | 🖱 |
| 5.8 | Open a conversation that is already at the bottom on first paint | The bottom-most turn is fully visible, with no blank area under it. | 🖱 |
| 5.9 | Resize the window while a reply streams in | No jump, no blank gap, no overlapping content. | 🖱 |
| 5.10 | Read a reply containing a code block | The code block scrolls horizontally on its own; vertical scrolling stays with the list. | 🖱 |
| 5.11 | Scroll to the bottom of a short conversation | The list cannot scroll past its content, and the last turn stays fully visible. | 🖱 |

### 6. Bottom status card

The card sits below all turns, at the very bottom of the list.

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 6.1 | Send a message | A card appears with a phase icon on the left, a title, and a small spinner on the right. It has a tinted background and a thin border. | 🖱（视觉）+ ✅ `AgentActivityProjectionTests.executingTool`（标题） |
| 6.2 | Read the title through a full run | The title follows the phase: `正在发送消息…` (sending), `正在思考…` (thinking), `正在生成回复…` (generating), `正在执行 N 个任务` (running N tasks), `等待你的确认` (waiting for confirmation). | ✅ `AgentActivityProjectionTests` 全套 phase case |
| 6.3 | Check the second line | A detail line carries extra context, e.g. `最近：<tool description>`. When the phase has no detail, the line is present but invisible. | ✅ `ListPresentationTests.detailPlaceholderIsSingleSpace` |
| 6.4 | Trigger more than one concurrent tool | The title becomes `正在执行 N 个任务` and the detail line shows the most recent task description. | ✅ `AgentActivityProjectionTests.multipleTools` |
| 6.5 | Reach a step that needs your confirmation | The title is `等待你的确认` with a raised-hand icon, and the pending tool description appears below. | ✅ `AgentActivityProjectionTests.waitingForUser` |
| 6.6 | Watch a long run across several tools and phases | The card does not flicker away between tools or between streaming phases. It stays for as long as the agent loop is still running. | 🖱 |
| 6.7 | Wait for the run to end | The card disappears once the agent loop reaches a terminal state — completed, failed, or cancelled. | ✅ `ListPresentationTests.activityClearedOnTerminalState` |
| 6.8 | Switch conversations while a turn is running | The card is cleared; it belongs to the selected conversation only. | ✅ `ListPresentationTests.activityIsolatedPerSelectedConversation` + UI `testBottomStatusCardIsHiddenWhenIdle` |
| 6.9 | Run a turn that fails | The card still disappears when the run ends in failure. | ✅ `ListPresentationTests.activityClearedOnTerminalState` |

### 7. Message content

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 7.1 | Read a user message | Rendered by the user message renderer with its normal appearance. | 🖱 |
| 7.2 | Read an assistant reply | Rendered by the assistant message renderer, Markdown supported. | 🖱 |
| 7.3 | Open a message that no renderer claims | An orange placeholder reading `No renderer for message: <uuid>` appears in place of the message. | ✅ UI `testNoRendererPlaceholderAppears`（基于夹具第 4 个 turn） |

### 8. Edge cases

| Step | Action | Expected | 覆盖 |
| --- | --- | --- | --- |
| 8.1 | Open a brand-new conversation with no messages | The list shows no turn groups and no `Load earlier messages` button; the loading view goes away. | ✅ `ListPresentationTests.emptyConversationLoadsCleanly` |
| 8.2 | Open a conversation whose history exactly fills one page | `Load earlier messages` is absent — it only appears when there is genuinely older history. | ✅ `ListPresentationTests.singlePageConversationHasNoEarlier` |
| 8.3 | Load earlier history, then send a new message | Prepended history stays in place and the new turn still gets the upper-quarter placement. | 🖱（发送路径依赖真实 AgentLoop） |
| 8.4 | Open a conversation with a very large number of turns | Scrolling stays responsive and no turn is duplicated or skipped across page boundaries. | 🔧 `MessageListServicesTests.refreshTail*` + `MessageListTailRefreshGate` |
| 8.5 | Send a message immediately after switching conversations | The new message attaches to the conversation you are now looking at, and no pending scroll from the previous conversation interferes. | ✅ `ListPresentationTests.rapidConversationSwitchingIsSafe` |

## Automated test entry points

```bash
# 单元测试（只跑本包）
cd Packages/PluginMessageListBrief
swift test

# UI 测试（需要 Xcode 完整 fetch 完所有依赖）
xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListBriefUITests
```

UI 测试夹具由 `MessageListBriefUITestingSupport` 提供（仅 `DEBUG` 编译），
通过 `--lumi-ui-testing-message-list-brief` 启动参数开启；建议同时开启
`--lumi-ui-testing-isolated-storage` 避免污染用户数据库。
