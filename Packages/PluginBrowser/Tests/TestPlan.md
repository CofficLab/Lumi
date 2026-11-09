# TestPlan — PluginBrowser

## 包概述

PluginBrowser Lumi's browser capability plugin: an integrated WebKit workspace and the official Chrome DevTools MCP server for controlling Chrome.

平台: macOS 14+, iOS 17+
测试文件: 11 个，用例总数: 54

核心组件（源码目录）:
- `Models/`
- `Services/`
- `Tools/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `BrowserPlugin`
- `BrowserSession`
- `BrowserWebView`
- `BrowserWorkspaceView`
- `BrowserAccessibilityNode`
- `BrowserAccessibilitySnapshot`
- `BrowserInteractionAction`
- `BrowserInteractionResult`
- `BrowserNavigationAction`
- `BrowserWaitCondition`
- `BrowserWaitResult`
- `BrowserElementRefStore`
- `BrowserContentBoundary`
- `BrowserAccessibilityScript`
- `BrowserInteractionScript`
- `BrowserSnapshotTool`
- `BrowserReadTool`
- `BrowserOpenTool`
- `BrowserStatusTool`
- `BrowserInteractTool`
- `BrowserWaitTool`
- `BrowserScreenshotTool`
- `BrowserNavigateTool`
- `BrowserEvaluateTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **BrowserPlugin**（5 条）：由 `browserManagesRailLifecycle`、`browserSuppressesContentHeaderWhileActive`、`browserRestoresHiddenContentHeaderOnDeactivate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Browser 可访问性快照**（8 条）：由 `buildsTreeFromFlatList`、`rendersRoleNameAndState`、`escapesForgedNodeLinesInName` 等用例锁定；快照的树结构、渲染格式与 interactive_only 过滤语义不得随意变更，否则 LLM 侧解析会失效。
- **Browser ref 登记簿**（5 条）：由 `normalizesRefFormats`、`staleMessageIncludesLastKnownSignature` 等用例锁定；ref 规范化规则与失效提示的措辞是 LLM 恢复动作的依据。
- **Browser 内容边界**（6 条）：由 `wrapsContentInMarkers`、`neutralizesForgedMarkers` 等用例锁定；nonce 机制是防提示注入的核心，任何削弱都会造成安全问题。
- **Browser 工具本地化**（3 条）：由 `allToolsDescribeInChinese`、`interactExposesEveryAction` 等用例锁定；工具描述与参数说明必须覆盖 4 种语言。
- **PluginBrowser 工具装配**（5 条）：由 `registersAllTools`、`removesAllToolsOnShutdown` 等用例锁定；工具漏注册或漏注销是本插件最容易犯且最难发现的错误。
- **Browser 活动会话隔离**（2 条）：由 `readOnlyToolsDoNotHijackActiveConversation`、`explicitSelectionStillSwitchesActiveConversation` 锁定；只读工具只能读取自己会话的页面，不得改写用户当前选中的 Browser 工作区。
- **Browser 会话释放**（4 条）：由 `deletedConversationReleasesBrowserSession`、`deletingActiveConversationClearsActiveState` 等用例锁定；删除会话必须立刻释放 BrowserSession/WKWebView，并在活动会话被删时清空活动状态。
- **Browser 整页截图边界**（6 条）：由 `clampsExtremelyWidePages`、`downscalesBeyondPixelBudget`、`outputPixelsStayWithinBudget` 等用例锁定；整页截图必须同时限制宽度、高度与总像素数，不能只钳制高度（issue #1060）。
- **Browser type 动作的 Unicode 输入**（3 条）：由 `typePreservesEmojiAndCJK`、`typePreservesZWJEmoji`、`typePreservesCombiningMarks` 用例锁定；`type` 必须按完整字符（优先 grapheme）逐次写入，不能按 UTF-16 码元拆分 surrogate pair（issue #1059）。
- **Browser contenteditable 输入**（3 条）：由 `fillWritesContentEditableHost`、`typeAppendsToContentEditableHost`、`rejectsNonEditableHost` 锁定；快照暴露为 textbox 的 contenteditable 元素必须能被 `fill` / `type` 写入，不可编辑元素仍须拒绝（issue #1093）。
- **Browser ref 分配与唯一性**（3 条）：由 `snapshotReplacesPresetDuplicateRefs`、`interactionRejectsAmbiguousRef`、`interactionReportsStaleRef` 锁定；ref 必须由 Lumi 分配并覆盖页面预置值，交互遇到同名多元素时必须拒绝（issue #1091）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | BrowserPlugin | Browser 激活和关闭时管理 Rail 生命周期 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `browserManagesRailLifecycle` |
| 2 | BrowserPlugin | Browser 激活期间持续压制 content header，退出时还原激活前的值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `browserSuppressesContentHeaderWhileActive` |
| 3 | BrowserPlugin | Browser 退出时不强行显示本该隐藏的 content header | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `browserRestoresHiddenContentHeaderOnDeactivate` |
| 4 | BrowserPlugin | plugin metadata is stable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadata` |
| 5 | BrowserPlugin | 新用户安装后 Browser 插件默认不启动，ActivityBar 不出现浏览器图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `disabledByDefaultSkipsActivityBarItem` |
| 6 | 可访问性快照 | 扁平列表被重建为树结构 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsTreeFromFlatList` |
| 7 | 可访问性快照 | 父节点必须排在子节点之前，否则该节点被当作根 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toleratesOutOfOrderParents` |
| 8 | 可访问性快照 | 渲染输出包含 ref、角色、名称与状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersRoleNameAndState` |
| 9 | 可访问性快照 | 空名称渲染为占位符而不是空引号 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `rendersPlaceholderForEmptyName` |
| 10 | 可访问性快照 | 状态标记顺序固定，便于逐行 diff | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `rendersStateFlagsInFixedOrder` |
| 11 | 可访问性快照 | interactive_only 过滤掉非交互的叶子，但保留仍有交互后代的分支 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prunesNonInteractiveLeaves` |
| 12 | 可访问性快照 | 可交互角色判定覆盖常用表单控件 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `identifiesInteractiveRoles` |
| 13 | ref 登记簿 | 接受 @lumi-3、lumi-3 与裸数字三种写法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizesRefFormats` |
| 14 | ref 登记簿 | 拒绝非法 ref | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsInvalidRefs` |
| 15 | ref 登记簿 | 失效 ref 的提示带上「上次见到」的特征 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleMessageIncludesLastKnownSignature` |
| 16 | ref 登记簿 | 重新快照会清除失效标记 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `registerClearsStaleMarker` |
| 17 | ref 登记簿 | 区分「从未见过」与「曾经存在但已消失」 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `distinguishesUnknownFromStale` |
| 18 | 内容边界 | 内容被包裹在带 nonce 的标记之间 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `wrapsContentInMarkers` |
| 19 | 内容边界 | begin 与 end 携带同一个 nonce | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `markersShareNonce` |
| 20 | 内容边界 | 安全声明位于边界之外，不受页面内容影响 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preambleIsOutsideBoundary` |
| 21 | 内容边界 | 页面伪造的边界标记被中和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `neutralizesForgedMarkers` |
| 22 | 内容边界 | 含真实 nonce 的行不被中和 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsRealMarkers` |
| 23 | 内容边界 | 普通正文不受影响 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `leavesOrdinaryContentAlone` |
| 24 | 工具本地化 | 全部工具在中文偏好下返回中文描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allToolsDescribeInChinese` |
| 25 | 工具本地化 | 全部工具的参数说明在中文偏好下返回中文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allToolArgumentsDescribeInChinese` |
| 26 | 工具本地化 | 交互工具的动作枚举覆盖全部动作 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `interactExposesEveryAction` |
| 27 | 工具装配 | onBoot 注册全部 9 个浏览器工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAllTools` |
| 28 | 工具装配 | 全部工具归到 Browser 插件分组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `groupsToolsUnderBrowserPlugin` |
| 29 | 工具装配 | onShutdown 注销全部浏览器工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesAllToolsOnShutdown` |
| 30 | 工具装配 | 工具的风险等级符合预期 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskLevelsAreAppropriate` |
| 31 | 工具装配 | 只有读工具可以并行执行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `executionCapabilitiesAreCorrect` |
| 32 | Browser 活动会话隔离 | 后台会话的只读工具不会切换当前 Browser 会话 | 用户选中 A，B 已有页面会话 | 依次对 B 执行 read/snapshot/find/evaluate/screenshot | `activeConversationID` 始终为 A，`activeSession` 仍为空 | P1 | ✅ 已覆盖 | `readOnlyToolsDoNotHijackActiveConversation` |
| 33 | Browser 活动会话隔离 | 用户显式选择会话仍然会切换 Browser 工作区 | 会话 B 已有页面会话 | 调用 `selectConversation(B)` | 活动会话与活动页面都切到 B | P1 | ✅ 已覆盖 | `explicitSelectionStillSwitchesActiveConversation` |
| 34 | Browser 会话释放 | 删除会话后释放对应 BrowserSession | 会话已有页面会话 | 投递 `ConversationEvent.deleted` | BrowserSession 被释放（weak 引用为 nil），不再持有该会话 | P1 | ✅ 已覆盖 | `deletedConversationReleasesBrowserSession` |
| 35 | Browser 会话释放 | 删除当前活动会话会清空活动状态 | 会话为当前活动会话 | 调用 `closeSession` | 活动会话与活动页面都清空 | P1 | ✅ 已覆盖 | `deletingActiveConversationClearsActiveState` |
| 36 | Browser 会话释放 | 删除其它会话不影响当前活动的 Browser 会话 | 会话 A 活动，B 有页面会话 | 删除 B | A 仍是活动会话且页面实例保留，B 被释放 | P1 | ✅ 已覆盖 | `deletingOtherConversationKeepsActiveSession` |
| 37 | Browser 会话释放 | 非删除类会话事件不会释放 BrowserSession | 会话已有页面会话 | 投递 `.updated` 与 `.listChanged` | 页面实例保留 | P2 | ✅ 已覆盖 | `unrelatedConversationEventsKeepSession` |
| 38 | Browser 整页截图边界 | 极宽页面被钳制到单边上限（**回归 #1060**） | width=200000、height=300 | 调用 `BrowserScreenshotGeometry.fitted` | rect 宽度等于 16000，不再使用页面原始宽度 | P1 | ✅ 已覆盖 | `clampsExtremelyWidePages` |
| 39 | Browser 整页截图边界 | 超高页面同样被钳制 | height=500000 | 调用 `fitted` | rect 高度等于 16000 | P1 | ✅ 已覆盖 | `clampsExtremelyTallPages` |
| 40 | Browser 整页截图边界 | 超过总像素预算时按比例降采样并保持长宽比 | 200000×200000 页面 | 调用 `fitted` 并计算输出尺寸 | outputScale < 1，输出长宽相等且总像素不超过 16M | P1 | ✅ 已覆盖 | `downscalesBeyondPixelBudget` |
| 41 | Browser 整页截图边界 | 常规页面不缩放 | 1280×720 页面 | 调用 `fitted` | rect 原样返回且 outputScale 为 1 | P1 | ✅ 已覆盖 | `leavesNormalPagesUntouched` |
| 42 | Browser 整页截图边界 | 非法尺寸至少保留 1 点 | 宽高为 0 或负数 | 调用 `fitted` | rect 宽高均为 1 | P2 | ✅ 已覆盖 | `clampsNonPositiveSizes` |
| 43 | Browser 整页截图边界 | 降采样后的输出像素不超过预算 | 多种宽高组合 | 调用 `fitted` 并计算 outputPixels | 均不超过 16M | P1 | ✅ 已覆盖 | `outputPixelsStayWithinBudget` |
| 44 | Browser type 动作的 Unicode 输入 | Emoji 与中文按完整字符输入（**回归 #1059**） | 输入框替身按 USVString 语义保存 value | 执行 type 脚本输入 `A😀B中文` | value 与输入完全一致，且每个字符各触发一组按键事件 | P1 | ✅ 已覆盖 | `typePreservesEmojiAndCJK` |
| 45 | Browser type 动作的 Unicode 输入 | ZWJ 组合 Emoji 不被拆坏 | 同上 | 输入家庭 Emoji 序列 | value 与输入完全一致 | P1 | ✅ 已覆盖 | `typePreservesZWJEmoji` |
| 46 | Browser type 动作的 Unicode 输入 | 组合附加符号不产生替换字符 | 同上 | 输入含 U+0301 组合符的文本 | value 与输入完全一致 | P1 | ✅ 已覆盖 | `typePreservesCombiningMarks` |
| 47 | Browser contenteditable 输入 | fill 写入 contenteditable 内容并派发 input/change（**回归 #1093**） | contenteditable 的 div 替身 | 执行 fill 脚本 | textContent 等于输入，且派发 input 与 change | P1 | ✅ 已覆盖 | `fillWritesContentEditableHost` |
| 48 | Browser contenteditable 输入 | type 逐字符追加到 contenteditable 内容（**回归 #1093**） | 同上 | 执行 type 脚本输入 `A😀` | textContent 等于输入，每个字符触发一组按键事件 | P1 | ✅ 已覆盖 | `typeAppendsToContentEditableHost` |
| 49 | Browser contenteditable 输入 | 不可编辑的普通 div 仍然拒绝文本 | 非 contenteditable 的 div 替身 | 执行 fill 脚本 | 返回失败，内容保持不变 | P1 | ✅ 已覆盖 | `rejectsNonEditableHost` |
| 50 | 可访问性快照 | 名称中的换行与引号不会伪造额外的节点行（**回归 #1092**） | 名称为 `Save"\n@lumi-99 button "Delete` 的按钮 | 分别渲染完整快照与 interactive_only 快照 | 节点只占一行，换行、引号被转义 | P1 | ✅ 已覆盖 | `escapesForgedNodeLinesInName` |
| 51 | 可访问性快照 | 多行 value 与 href 中的控制字符被转义（**回归 #1092**） | 值含换行/引号/反斜杠的 textbox，href 含伪造行的链接 | 渲染快照 | value 与 href 中的控制字符均被转义，不产生额外行 | P1 | ✅ 已覆盖 | `escapesControlCharactersInValueAndHref` |
| 52 | Browser ref 分配与唯一性 | 快照覆盖页面预置的重复 ref，并沿用已分配的计数器（**回归 #1091**） | 两个按钮都预置 `data-lumi-browser-ref="lumi-1"` | 执行两次快照脚本（第二次带已持久化计数器） | 两次 ref 分别为 lumi-1/2 与 lumi-3/4，不重复 | P0 | ✅ 已覆盖 | `snapshotReplacesPresetDuplicateRefs` |
| 53 | Browser ref 分配与唯一性 | 同名 ref 匹配多个元素时拒绝交互（**回归 #1091**） | 页面上两个元素共享同一 ref | 对 `@lumi-1` 执行 click | 返回失败并提示匹配 2 个元素，不点击任何元素 | P0 | ✅ 已覆盖 | `interactionRejectsAmbiguousRef` |
| 54 | Browser ref 分配与唯一性 | 没有匹配元素时仍然报告失效 ref | 页面没有该 ref | 对 `@lumi-7` 执行 click | 返回 `STALE_REF:lumi-7` | P1 | ✅ 已覆盖 | `interactionReportsStaleRef` |

> 说明：全部 **54 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 39 / 39
- P2: 已覆盖 13 / 13
- **合计: 54 / 54**（仅表示清单场景，非源码覆盖率）

## 未覆盖说明

以下能力依赖真实 `WKWebView` 运行时，单元测试无法覆盖，需要在 App 中人工验证：

- 可访问性脚本在真实 DOM 上的 role 映射与名称计算
- 交互动作在真实元素上的效果（遮挡检测、下拉选项匹配）
- 截图的 `takeSnapshot` 渲染结果
- 等待机制在真实异步页面上的时序

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（39 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（13 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 54 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginBrowser
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
