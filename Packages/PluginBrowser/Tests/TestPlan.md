# TestPlan — PluginBrowser

## 包概述

PluginBrowser Lumi's browser capability plugin: an integrated WebKit workspace and the official Chrome DevTools MCP server for controlling Chrome.

平台: macOS 14+, iOS 17+
测试文件: 21 个，用例总数: 95

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
- **Browser find 路径 interactive_only 过滤**（6 条）：由 `interactiveFilterDropsHeadingWhenInteractiveOnly`、`interactiveFilterDisabledKeepsAllMatches`、`interactiveFilterKeepsOnlyInteractiveRoles`、`interactiveFilterKeepsAllWhenAllInteractive`、`interactiveFilterReturnsEmptyWhenNoneInteractive`、`interactiveFilterOnEmptyMatchesReturnsEmpty` 锁定。`browser_snapshot` 带 role/name/text 过滤走 find 分支时，必须经 `BrowserAccessibilityNode.filterInteractive` 同样应用 interactive_only，与快照树过滤共用 `isInteractive` 判据；非交互匹配（如 heading）不得漏出，全部非交互时返回空匹配提示（**回归 #834**）。
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
- **Browser click 遮挡检测**（2 条）：由 `coveredClickReportsFailureAndDoesNotClick`、`uncoveredClickSucceedsAndClicks` 锁定；非链接元素被遮挡时 `click()` 返回失败对象，调用处必须检查 `.ok` 并原样回传失败，不得因 JS 对象恒真而误报 "Clicked." 成功（issue #832）。
- **browser_evaluate 结果解析**（6 条）：由 `stringValueReturnsAsIs`、`errorEnvelopeMapsToScriptFailed`、`largeResultDecodesOffMain` 等用例锁定；信封到 `.success` / `.scriptFailed` / `.noPage` 的映射是模型判断脚本成败的依据，数 MB 结果的解析必须在后台完成（issue #1297）。
- **截图 PNG 编码**（3 条）：由 `encodesValidPNGFromCGImage`、`directEncodingMatchesTIFFRoundTrip`、`encodingRunsOffMainThread` 锁定；直接从 CGImage 建位图并在后台编码，去掉 TIFF 往返，像素尺寸不得丢失（issue #1282）。
- **browser_wait 取消行为**（4 条）：由 `cancellationThrowsImmediately`、`cancellationStopsPolling`、`timeoutReturnsFalse` 锁定；取消必须立刻向上传播并停止轮询，否则 load / navigation 分支会在主线程忙轮询到超时（issue #418）。
- **Browser DNS 根点归一化**（8 条）：由 `trailingRootDotLocalHostsAreStillLocal`、`openAndNavigateToolsRequireApprovalForTrailingDot`、`openWithoutApprovalIsBlocked`、`approvedHostKeyIsNormalized` 锁定；`localhost.` 与 `localhost` 解析到同一个回环地址，分类与审批键都必须先去掉 DNS 根点，否则等价 host 就能绕过本地访问审批（issue #830）。
- **Browser 本地地址分类**（3 条）：由 `publicDomainsStartingWithFcOrFdAreNotLocal`、`ipv6ULAAndLinkLocalAreLocal`、`existingLocalAndPublicClassificationsArePreserved` 锁定；只有含 `:` 的 IPv6 字面量才可能属于 `fc00::/7`，fc/fd 开头的公网域名（如 `fdic.gov`）不得被判为内网，否则触发错误的本地网络审批并阻断导航（issue #831）。
- **back/forward/reload 导航失败传播**（4 条）：由 `backNavigationCancellationPropagates`、`reloadNavigationFailurePropagates`、`successfulNavigationReturns`、`blockedLocalNavigationPropagates` 锁定；back/forward/reload 必须通过 continuation 等待导航结果，WebKit 报错或策略取消时必须抛出错误，不得静默返回成功（issue #833）。

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
| 55 | Browser 本地地址分类 | fc/fd 开头的公网域名不得被判为内网（**回归 #831**） | — | 对 `fdic.gov`/`fc.com` 等调用 `isLocalHost` 与 `requiresLocalAccessApproval` | 均返回 false，不触发本地网络审批 | P0 | ✅ 已覆盖 | `publicDomainsStartingWithFcOrFdAreNotLocal` |
| 56 | Browser 本地地址分类 | 真正的 IPv6 ULA 与链路本地地址仍判为内网 | — | 对 `fc00::1`/`fd12::1`/`fe80::1` 等调用分类器 | 均返回 true | P1 | ✅ 已覆盖 | `ipv6ULAAndLinkLocalAreLocal` |
| 57 | Browser 本地地址分类 | 既有本地与公网分类保持不变 | — | 对 localhost/::1/*.local/IPv4 私网与公网域名调用分类器 | 本地/私网为 true，公网为 false | P1 | ✅ 已覆盖 | `existingLocalAndPublicClassificationsArePreserved` |
| 58 | Browser 脚本重复执行 | 快照脚本可在同一页面重复执行 | 同一 JS 全局环境 | 连续两次 evaluateScript 快照脚本 | 均无 SyntaxError，返回空树 total=0 | P0 | ✅ 已覆盖 | `snapshotScriptRunsRepeatedly` |
| 59 | Browser 脚本重复执行 | 交互脚本可在同一页面重复执行 | 同一 JS 全局环境 | 连续两次 evaluateScript 滚动脚本 | 均无 SyntaxError，ok=true | P0 | ✅ 已覆盖 | `interactionScriptRunsRepeatedly` |
| 60 | Browser 脚本重复执行 | 先快照后交互不重复声明全局 | 同一 JS 全局环境 | 先快照再交互 | 两者均成功，无 __OPTS 重复声明 | P0 | ✅ 已覆盖 | `snapshotThenInteractionSharePage` |
| 61 | Browser 脚本重复执行 | find 脚本可在同一页面重复执行 | 同一 JS 全局环境 | 连续两次 evaluateScript find 脚本 | 均无 SyntaxError，total=0 | P1 | ✅ 已覆盖 | `findScriptRunsRepeatedly` |
| 62 | Browser DNS 根点归一化 | 带 DNS 根点的本地主机必须仍判为内网（**回归 #830**） | — | 对 `localhost.`/`printer.local.`/`127.0.0.1.` 等调用 `isLocalHost` 与 `requiresLocalAccessApproval` | 均返回 true，本地访问审批不被绕过 | P0 | ✅ 已覆盖 | `trailingRootDotLocalHostsAreStillLocal` |
| 63 | Browser DNS 根点归一化 | 带根点的公网域名不得被误判为内网 | — | 对 `example.com.`/`8.8.8.8.`/`fdic.gov.` 调用分类器 | 均返回 false，不触发多余的本地网络审批 | P0 | ✅ 已覆盖 | `trailingRootDotKeepsPublicHostsPublic` |
| 64 | Browser DNS 根点归一化 | 多个根点同样归一化，方向偏保守 | — | 对 `localhost..`/`localhost...` 调用分类器与 `normalizedHost` | 判为内网，归一化结果为 `localhost` | P1 | ✅ 已覆盖 | `repeatedRootDotsAreNormalized` |
| 65 | Browser DNS 根点归一化 | 既有归一化行为保持不变 | — | 对 `[::1]`/`LOCALHOST`/空串调用 `normalizedHost`，并复核既有本地与公网分类 | 方括号与大小写归一化不变，既有分类结果不变 | P1 | ✅ 已覆盖 | `existingNormalizationIsPreserved` |
| 66 | Browser DNS 根点归一化 | 带根点的回环地址在打开与导航工具上必须是高风险（**回归 #830**） | — | 对 `http://localhost.:3000` 等调用 `browser_open` / `browser_navigate(goto)` 的 `permissionRiskLevel` | 均为 `.high`；`https://example.com.` 仍为 `.low` | P0 | ✅ 已覆盖 | `openAndNavigateToolsRequireApprovalForTrailingDot` |
| 67 | Browser DNS 根点归一化 | 未获批准时带根点的回环地址必须被拦下，且不创建会话（**回归 #830**） | localAccessApproved=false | 调用 `BrowserSessionManager.open("http://localhost.:3000")` | 抛出 `blockedLocalNavigation`，且 `hasSession` 为 false | P0 | ✅ 已覆盖 | `openWithoutApprovalIsBlocked` |
| 68 | Browser DNS 根点归一化 | 审批键按归一化主机记录，未批准时不留键 | — | 对 `http://localhost.:3000`/`http://[::1]:8080/`/`http://PRINTER.LOCAL./` 调用 `approvedHostKey` | 分别得到 `localhost`/`::1`/`printer.local`；未批准时为 nil | P1 | ✅ 已覆盖 | `approvedHostKeyIsNormalized` |
| 69 | Browser DNS 根点归一化 | 批准 localhost 后等价写法都算已批准，无关主机不算 | 会话已批准 localhost | 对 `localhost.`/`LOCALHOST.`/`localhost..` 与 `evil.com`/`localhost.evil.com` 调用 `hasApprovedLocalHost` | 等价写法为 true，无关主机为 false；无审批记录时全为 false | P1 | ✅ 已覆盖 | `approvedLocalHostCoversEquivalentForms` |
| 70 | browser_evaluate 结果解析 | 字符串结果原样返回，不做二次转义 | — | 对 `{"ok":true,"value":"hello"}` 调用 `decodeEvaluateResult` | 得到 `.success("hello")` | P1 | ✅ 已覆盖 | `stringValueReturnsAsIs` |
| 71 | browser_evaluate 结果解析 | 对象结果被美化输出，便于模型阅读 | — | 对含嵌套对象与数组的信封调用 `decodeEvaluateResult` | 输出含换行与键名 | P1 | ✅ 已覆盖 | `objectValueIsPrettyPrinted` |
| 72 | browser_evaluate 结果解析 | 缺失 value 时返回 null 占位 | — | 对 `{"ok":true}` 调用 `decodeEvaluateResult` | 得到 `.success("null")` | P2 | ✅ 已覆盖 | `missingValueReturnsNull` |
| 73 | browser_evaluate 结果解析 | 错误信封映射为 scriptFailed 并带上原因 | — | 对 `{"ok":false,"error":"boom"}` 调用 `decodeEvaluateResult` | 得到 `.scriptFailed("boom")` | P1 | ✅ 已覆盖 | `errorEnvelopeMapsToScriptFailed` |
| 74 | browser_evaluate 结果解析 | 非法 JSON 映射为 noPage，不得当成脚本结果 | — | 对 `not json` 调用 `decodeEvaluateResult` | 得到 `.noPage` | P1 | ✅ 已覆盖 | `malformedJSONMapsToNoPage` |
| 75 | browser_evaluate 结果解析 | 数 MB 结果必须在后台解析，不得占用主 actor（**回归 #1297**） | — | 在 `Task.detached` 里解析约 2 MB 的字符串信封 | 解析成功且内容完整，不依赖主 actor | P0 | ✅ 已覆盖 | `largeResultDecodesOffMain` |
| 76 | 截图 PNG 编码 | 从 CGImage 直接编码得到有效 PNG | — | 用 `NSBitmapImageRep(cgImage:)` 编码 40×30 图片 | 字节非空且以 PNG magic 开头 | P1 | ✅ 已覆盖 | `encodesValidPNGFromCGImage` |
| 77 | 截图 PNG 编码 | 直接编码与 TIFF 往返编码的像素尺寸不得丢失 | — | 比较两条路径 PNG 解码后的 `pixelsWide` / `pixelsHigh` | 两者一致（不受屏幕缩放影响） | P1 | ✅ 已覆盖 | `directEncodingMatchesTIFFRoundTrip` |
| 78 | 截图 PNG 编码 | PNG 编码必须在后台线程执行（**回归 #1282**） | — | 在 `Task.detached` 的同步闭包里编码并检查 `Thread.isMainThread` | 编码成功且不在主线程 | P0 | ✅ 已覆盖 | `encodingRunsOffMainThread` |
| 79 | browser_wait 取消行为 | 取消后必须立刻抛出 CancellationError（**回归 #418**） | 等待循环运行中 | 启动 `BrowserWaitLoop.run`，50 ms 后 `task.cancel()` | 抛出 `CancellationError`，而不是空转到超时 | P0 | ✅ 已覆盖 | `cancellationThrowsImmediately` |
| 80 | browser_wait 取消行为 | 取消后不得继续轮询（**回归 #418**） | 等待循环运行中 | 取消后再等 400 ms，比较 actor 计数器的轮询次数 | 计数停止增长 | P0 | ✅ 已覆盖 | `cancellationStopsPolling` |
| 81 | browser_wait 取消行为 | 条件成立时正常返回 true | — | 以 `isSatisfied: { true }` 运行等待循环 | 返回 true | P1 | ✅ 已覆盖 | `satisfiedConditionReturns` |
| 82 | browser_wait 取消行为 | 超时返回 false 而不是抛错 | deadline 为 50 ms 后 | 以 `isSatisfied: { false }` 运行等待循环 | 返回 false | P0 | ✅ 已覆盖 | `timeoutReturnsFalse` |
| 83 | 导航失败传播 | back 导航被策略取消时抛出错误而非返回成功（**回归 #833**） | 会话已创建 | 启动 `performAndWaitNavigation`，模拟 `didFailProvisionalNavigation` 回调 | 抛出 WebKit 错误，不静默返回成功 | P0 | ✅ 已覆盖 | `backNavigationCancellationPropagates` |
| 84 | 导航失败传播 | reload 导航失败时抛出错误而非返回成功（**回归 #833**） | 会话已创建 | 启动 `performAndWaitNavigation`，模拟 `didFail` 回调 | 抛出 WebKit 错误，不静默返回成功 | P0 | ✅ 已覆盖 | `reloadNavigationFailurePropagates` |
| 85 | 导航失败传播 | 导航成功时正常返回 | 会话已创建 | 启动 `performAndWaitNavigation`，模拟 `didFinish` 回调 | 正常返回，不抛错 | P1 | ✅ 已覆盖 | `successfulNavigationReturns` |
| 86 | 导航失败传播 | 本地审批策略取消导航时抛出 blockedLocalNavigation（**回归 #833**） | 会话已创建 | 启动 `performAndWaitNavigation`，模拟 `didFailProvisionalNavigation` 带 `blockedLocalNavigation` | 抛出 `blockedLocalNavigation` 错误 | P0 | ✅ 已覆盖 | `blockedLocalNavigationPropagates` |
| 87 | find 交互过滤 | 带过滤时 interactive_only 必须丢掉非交互 heading 匹配（**回归 #834**） | matches 为 heading "Welcome" 与 button "Submit" | 以 interactiveOnly=true 调用 `filterInteractive` | 只剩 button（lumi-2），heading 被剔除 | P0 | ✅ 已覆盖 | `interactiveFilterDropsHeadingWhenInteractiveOnly` |
| 88 | find 交互过滤 | interactive_only 关闭时保留全部匹配 | matches 为 heading/button/link | 以 interactiveOnly=false 调用 `filterInteractive` | 三条原样保留，顺序不变 | P1 | ✅ 已覆盖 | `interactiveFilterDisabledKeepsAllMatches` |
| 89 | find 交互过滤 | 只保留可交互角色 | matches 为 button/link/textbox/paragraph/heading | 以 interactiveOnly=true 调用 `filterInteractive` | 只剩 button/link/textbox | P1 | ✅ 已覆盖 | `interactiveFilterKeepsOnlyInteractiveRoles` |
| 90 | find 交互过滤 | 全部可交互时全部保留 | matches 为 button/link | 以 interactiveOnly=true 调用 `filterInteractive` | 两条都保留 | P1 | ✅ 已覆盖 | `interactiveFilterKeepsAllWhenAllInteractive` |
| 91 | find 交互过滤 | 全部非交互时返回空（触发空匹配提示） | matches 为 heading/paragraph | 以 interactiveOnly=true 调用 `filterInteractive` | 返回空列表 | P1 | ✅ 已覆盖 | `interactiveFilterReturnsEmptyWhenNoneInteractive` |
| 92 | find 交互过滤 | 空匹配列表过滤后仍为空 | matches 为空 | 以 interactiveOnly=true 调用 `filterInteractive` | 返回空列表 | P2 | ✅ 已覆盖 | `interactiveFilterOnEmptyMatchesReturnsEmpty` |
| 93 | Browser click 遮挡检测 | 被遮挡的非链接元素点击必须报告失败且不执行真实点击（**回归 #832**） | elementFromPoint 返回遮挡元素 | 对 `@lumi-1`（BUTTON）执行 click | 返回 ok=false 且提示被遮挡，`el.click()` 未执行 | P0 | ✅ 已覆盖 | `coveredClickReportsFailureAndDoesNotClick` |
| 94 | Browser click 遮挡检测 | 未被遮挡的非链接元素点击成功并执行真实点击 | elementFromPoint 返回自身 | 对 `@lumi-1`（BUTTON）执行 click | 返回 ok=true、message "Clicked."，`el.click()` 执行一次 | P1 | ✅ 已覆盖 | `uncoveredClickSucceedsAndClicks` |
| 95 | Browser 会话标题同步 | 运行时修改 document.title 后会话标题立即跟随 | 内联加载带标题的 HTML 页面 | `browser` 场景：加载 Original 页后用 JS 把 `document.title` 改为 Changed | 会话缓存标题先变为 Original、随后立即变为 Changed（**#835**） | P0 | ✅ 已覆盖 | `runtimeTitleChangeIsReflected` |

> 说明：全部 **95 条场景**已在本包 `swift test` 中实跑通过。
>
> 变异验证（#835）：禁用 init 中的 `observeTitle()` → `runtimeTitleChangeIsReflected` 转红（加载期的 Initial 标题与运行时 Changed 标题都收不到——URL 观察对 `loadHTMLString` 的标题时序不生效）。变异确认转红后还原，最终 95 条全绿。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> **#834 变异验证**：对 `BrowserAccessibilityNode.filterInteractive` 注入 3 个变异均被相应用例捕获——M1 过滤谓词 `$0.isInteractive`→`true`（等同忽略 interactive_only 的旧 bug，被 `interactiveFilterDropsHeadingWhenInteractiveOnly` 等捕获）；M2 谓词→`!$0.isInteractive`（反向选择，被 `interactiveFilterKeepsAllWhenAllInteractive` 唯一捕获）；M3 guard 的 `else { return nodes }`→`else { return [] }`（关闭标志时误清空，被 `interactiveFilterDisabledKeepsAllMatches` 唯一捕获）。
> **#832 变异验证**：对 `BrowserInteractionScript` 的 click 路径注入 2 个变异均被相应用例捕获——M1 还原原始 bug（成功 `return true;` + 调用处 `if (!click()) return fail(...)`，JS 失败对象恒真使遮挡被当成功），被 `coveredClickReportsFailureAndDoesNotClick` 捕获（ok=false 与遮挡提示两处断言失败）；M2 把成功返回改为 `return { ok: false };`，被 `uncoveredClickSucceedsAndClicks` 唯一捕获（ok=true 与 message "Clicked." 两处断言失败），证明正向用例能区分成功返回。

## 覆盖率统计

- P0: 已覆盖 21 / 21
- P1: 已覆盖 59 / 59
- P2: 已覆盖 15 / 15
- **合计: 95 / 95**（仅表示清单场景，非源码覆盖率）

## 未覆盖说明

以下能力依赖真实 `WKWebView` 运行时，单元测试无法覆盖，需要在 App 中人工验证：

- 可访问性脚本在真实 DOM 上的 role 映射与名称计算
- 交互动作在真实元素上的效果（真实 DOM 命中测试、下拉选项匹配）
- 截图的 `takeSnapshot` 渲染结果
- 等待机制在真实异步页面上的时序

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（21 条）
- **P1**: 其余功能性用例（59 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（15 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 95 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
