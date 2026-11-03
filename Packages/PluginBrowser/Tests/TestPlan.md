# TestPlan — PluginBrowser

## 包概述

PluginBrowser Lumi's browser capability plugin: an integrated WebKit workspace and the official Chrome DevTools MCP server for controlling Chrome.

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 31

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
- **Browser 可访问性快照**（6 条）：由 `buildsTreeFromFlatList`、`rendersRoleNameAndState` 等用例锁定；快照的树结构、渲染格式与 interactive_only 过滤语义不得随意变更，否则 LLM 侧解析会失效。
- **Browser ref 登记簿**（5 条）：由 `normalizesRefFormats`、`staleMessageIncludesLastKnownSignature` 等用例锁定；ref 规范化规则与失效提示的措辞是 LLM 恢复动作的依据。
- **Browser 内容边界**（6 条）：由 `wrapsContentInMarkers`、`neutralizesForgedMarkers` 等用例锁定；nonce 机制是防提示注入的核心，任何削弱都会造成安全问题。
- **Browser 工具本地化**（3 条）：由 `allToolsDescribeInChinese`、`interactExposesEveryAction` 等用例锁定；工具描述与参数说明必须覆盖 4 种语言。
- **PluginBrowser 工具装配**（5 条）：由 `registersAllTools`、`removesAllToolsOnShutdown` 等用例锁定；工具漏注册或漏注销是本插件最容易犯且最难发现的错误。

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

> 说明：全部 **31 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 20 / 20
- P2: 已覆盖 11 / 11
- **合计: 31 / 31**（仅表示清单场景，非源码覆盖率）

## 未覆盖说明

以下能力依赖真实 `WKWebView` 运行时，单元测试无法覆盖，需要在 App 中人工验证：

- 可访问性脚本在真实 DOM 上的 role 映射与名称计算
- 交互动作在真实元素上的效果（遮挡检测、下拉选项匹配）
- 截图的 `takeSnapshot` 渲染结果
- 等待机制在真实异步页面上的时序

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（20 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（11 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 31 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
