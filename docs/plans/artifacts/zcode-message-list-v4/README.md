# ZCode 消息列表 V4 — 评审截图与索引

本目录用于存放 **V4（ZCode）消息列表**与 Lumi 既有呈现的**并排对照截图**，
供人工评审使用。

## 重要说明（必读）

**本目录当前不含任何 PNG 截图。**

原因：本次实现所在环境（macOS 桌面机）的 **XCTest automation mode 在长时间
UI 测试运行后被楔死**，后续所有 `xcodebuild test` 都在启动阶段失败：

```
LumiUITests-Runner … Failed to initialize for UI testing:
Error Domain=com.apple.dt.XCTest.XCTFuture Code=1000
"Timed out while enabling automation mode."
```

该故障**与本特性无关**：同一时段内，仓库**既有**的
`LumiMessageListBriefUITests` 也在启动阶段以完全相同的方式失败。
尝试过的恢复手段（等待、`launchctl kickstart` AX/tccd、重启测试宿主）
均未解除。

因此：

- **截图没有伪造**。计划要求「由真实测试生成，不伪造」，因此宁可留空。
- 本索引记录了**已经跑通**的 UI 用例及其断言，供人工复核代码；
- 截图矩阵的**宽度**、**主题**、**语言**、**状态**组合清单见下，
  恢复 automation 后按此清单补跑即可。

## 已跑通的 UI 用例

以下用例在 automation 正常时**实际执行并通过**（见提交 `a087fc312` 的
CI/本地运行记录）：

### `LumiUITests/LumiMessageListZCodeUITests.swift`

| 用例 | 断言要点 |
|---|---|
| `testAllZCodeFixtureConversationsExist` | 5 个夹具会话全部出现在会话列表 |
| `testFirstScreenMaskClearsPromptlyForEveryFixture` | 每个夹具会话首屏遮罩在 6s 内消失 |
| `testScrollFixtureMaskClearsPromptly` | 30 轮长列表会话首屏遮罩在 6s 内消失 |
| `testZCodeListIsVisibleAndNotBlank` | V4 列表容器可见且可交互 |
| `testSwitchingAcrossAllVerbositiesNeverShowsTwoLists` | brief→standard→detailed→zcode→brief 往返，任意时刻最多一个消息列表可见 |
| `testUserBubbleHasCopyButton` | 用户气泡存在且复制按钮可用 |
| `testLongUserBubbleHasExpandToggle` | 超长用户输入有展开 / 收起按钮 |
| `testLongUserBubbleToggleChangesState` | 展开后状态变化（AX label） |
| `testAssistantBodyHasNoBubble` | 助手正文没有被画进用户气泡容器 |
| `testTurnActionBarAppearsExactlyOnce` | 每个 turn 恰好一个轮尾复制按钮 |
| `testTurnActionBarHasCopyAndTime` | 轮尾复制按钮与时间标签都在 |
| `testNoFakeLikeEditForkButtons` | 不出现 like / fork 等计划禁止的假按钮 |
| `testToolWorkHistoryGroupAppears` | 工具会话出现工作历史分组 |
| `testToolWorkHistoryToggles` | 工作历史可展开 / 收起 |

### `LumiUITests/LumiMessageListZCodeScrollUITests.swift`

| 用例 | 断言要点 |
|---|---|
| `testScrollFixtureLoads` | 长列表会话加载完成，遮罩消失 |
| `testBackToBottomButtonAppearsAfterUserScrollUp` | 用户上滚后「回到底部」按钮出现 |
| `testBackToBottomButtonRestoresFollowing` | 点击按钮后按钮消失（恢复跟随） |
| `testScrollingForwardRestoresFollowing` | 用户往前滚后恢复跟随 |

## 待补的截图矩阵

恢复 automation 后按下表逐项补拍。**每个宽度**都要覆盖全部状态组合，
文件名规则：`<宽度>-<主题>-<语言>-<状态>.png`。

### 逻辑宽度

`390`、`600`、`700`、`900`、`1440`。

### 几何边界（单独出图）

| 边界 | 说明 |
|---|---|
| `447` / `448` | 内容列窄屏分界 |
| `623` / `624` | 中屏分界 |
| `863` / `864` | 宽屏分界 |
| `1279` / `1280` | 超宽屏分界 |

### 每个宽度需覆盖的维度

- **主题**：light / dark
- **语言**：中文 / 英文
- **状态**：complete / streaming / hover / keyboard focus / reduced-motion
- **内容**：短消息、长用户、附件、全 Markdown、长代码、表格、图片、
  reasoning、工具组、错误、审批、长列表、滚动离底

### 评审要求

- ZCode 与 Lumi 的**同内容 fixture** 按**相同逻辑宽度**并排对照；
- 逐项记录：**几何断言 / 截图文件名 / 评审结果**；
- **不得**用「看起来差不多」替代清单；
- PNG **只做人工对照**，不做字节相等断言。
