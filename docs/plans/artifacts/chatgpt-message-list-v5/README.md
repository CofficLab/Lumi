# ChatGPT 消息列表 V5 — 评审截图与索引

本目录用于存放 **V5（ChatGPT）消息列表**的评审截图，供人工评审使用。

## 重要说明（必读）

**本目录当前不含任何 PNG 截图。**

原因：本次实现所在环境的 **XCTest automation mode 无法初始化**，
所有 `xcodebuild test` 都在启动阶段失败：

```
LumiUITests-Runner … encountered an error
(The test runner failed to initialize for UI testing.
 Underlying Error: 认证已取消。. System authentication is running.)
```

该故障**与本特性无关**：它是宿主环境的系统认证 / TCC 授权问题，
不是用例失败，也不出现在任何一个断言上。

另外两项环境限制：

- **无障碍树不可读**：`accessibility_observe` 返回
  `需要辅助功能权限。请打开 Lumi 设置 > Computer Use。`，
  因此无法用 AX 树做运行时验证。
- **App 可启动但 AX 树不可读**：以
  `--lumi-ui-testing --lumi-ui-testing-message-list-chatgpt --lumi-ui-testing-isolated-storage`
  启动后进程存活，但 AX 观察与 Automation Server（`localhost:18765`）
  都不可用，因此无法取真实截图。

因此：

- **截图没有伪造**。方案要求「由真实测试生成，不伪造」，因此宁可留空。
- 本索引记录了**已经跑通**的用例层级及其断言，供人工复核代码；
- 截图矩阵的**宽度**、**主题**、**语言**、**状态**组合清单见下，
  恢复 automation 后按此清单补跑即可。

## 已跑通的验证层级

### 1. 端到端集成测试（真实 Provider 链路）✅

`Packages/FactoryLumi/Tests/FactoryLumiTests/ChatGPTMessageListEndToEndTests.swift`

这一层用**真实的** `MessageStore` / `MessageManaging` /
`MessageRenderingProviding` / `MessageRendererPlugin` 串起完整链路：

```text
MessageStore → MessageManaging → V5 ViewModel → MessageRenderingProviding
             → MessageRendererPlugin → View
```

| 用例 | 断言要点 |
|---|---|
| `chatGPTSlotTakesOverWhenVerbosityIsChatGPT` | V5 槽位在 chatGPT 详细度下接管消息列表 |
| `chatGPTFeedsPersistedMessagesToRenderer` | 每条落库消息都能找到渲染器（否则 V5 显示空白） |
| `chatGPTRendersUserAndAssistantWithChatGPTStyle` | 用户 / 助手消息都走核心渲染器，verbosity 只改呈现不改分发 |
| `chatGPTDoesNotTakeOverOtherVerbosities` | V5 在其它详细度下不抢槽位 |

**这一层是「V5 不再是空 List」的直接证据。**

### 2. 包内单元测试 ✅

- `Packages/PluginMessageListChatGPT/Tests/PluginMessageListChatGPTTests/`
  （分页、turn 投影、投影缓存、滚动 reducer、来源分类器、首屏 gate、
  流式、无障碍、UI 夹具）
- `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ChatGPT*.swift`
  （路由矩阵、助手正文、reasoning、工具组、timeline marker、内联错误、
  Markdown 主题、无障碍）
- `Packages/KitMarkdown/Tests/KitMarkdownTests/ChatGPTTableLayoutTests.swift`

### 3. UI 用例（已编写，automation 恢复后可跑）⚠️

`LumiUITests/LumiMessageListChatGPTUITests.swift`

| 用例 | 断言要点 |
|---|---|
| `testAllChatGPTFixtureConversationsExist` | 5 个夹具会话全部出现在会话列表 |
| `testFirstScreenMaskClearsPromptlyForEveryFixture` | 每个夹具会话首屏遮罩在 6s 内消失 |
| `testChatGPTListIsVisibleAndNotBlank` | V5 列表容器可见且可交互 |
| `testAssistantBodyIsRendered` | 助手正文出现（守住「不再空白」） |
| `testUserBubbleHasCopyButton` | 用户气泡存在且复制按钮可用 |
| `testAssistantBodyHasNoBubble` | 助手正文没有被画进用户气泡容器 |
| `testTurnActionBarAppearsExactlyOnce` | 每个 turn 恰好一个轮尾复制按钮 |
| `testReasoningDisclosureIsExpandable` | reasoning 折叠块存在 |
| `testToolWorkGroupIsRendered` | 工具工作组存在 |
| `testInlineErrorIsRendered` | 内联错误出现 |
| `testCaptureVisualFixtureScreenshot` | 生成常规轮次截图附件 |

`LumiUITests/LumiMessageListChatGPTScrollUITests.swift`

| 用例 | 断言要点 |
|---|---|
| `testScrollFixtureLoads` | 长列表会话加载完成，遮罩消失 |
| `testBackToBottomButtonAppearsAfterUserScrollUp` | 用户上滚后「回到底部」按钮出现 |
| `testBackToBottomButtonRestoresFollowing` | 点击按钮后按钮消失（恢复跟随） |
| `testScrollingForwardRestoresFollowing` | 用户往前滚后恢复跟随 |
| `testDetachedStateSurvivesContentGrowth` | 脱离跟随后内容变高不把用户拽回底部 |

## 待补的截图矩阵

恢复 automation 后按下表逐项补拍。**每个宽度**都要覆盖全部状态组合，
文件名规则：`<宽度>-<主题>-<语言>-<状态>.png`。

### 逻辑宽度

`390`、`600`、`700`、`900`、`1440`。

### 几何边界（单独出图）

| 边界 | 说明 |
|---|---|
| `479` / `480` | 容器水平 padding 分界（16 → 24） |
| `768` | 内容列最大宽 |

### 每个宽度需覆盖的维度

- **主题**：light / dark
- **语言**：中文 / 英文
- **状态**：complete / streaming / hover / keyboard focus / reduced-motion
- **内容**：短消息、长用户、附件、全 Markdown、长代码、表格、图片、
  reasoning、工具组、错误、审批、长列表、滚动离底

### 评审要求

- ChatGPT V5 与 Lumi 既有呈现按**相同逻辑宽度**并排对照；
- 逐项记录：**几何断言 / 截图文件名 / 评审结果**；
- **不得**用「看起来差不多」替代清单；
- PNG **只做人工对照**，不做字节相等断言。
