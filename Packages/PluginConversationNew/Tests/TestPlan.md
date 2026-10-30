# TestPlan — PluginConversationNew

## 包概述

PluginConversationNew 的实现包，包含 9 个主要类型；当前测试覆盖 19 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 19

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
- **CreateNewConversationTool**（12 条）：由 `missingTaskThrows`、`titleFallsBackToDerived`、`explicitTitleWins` 等用例锁定；改动该模块时优先跑对应测试文件。
- **NewConversationRowRenderer**（6 条）：由 `canRenderMatchesToolWithPayload`、`canRenderRejectsOtherTools`、`canRenderRejectsUndecodableResults` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationNewPlugin | 只有 ChatSection 可见且存在选中会话时才显示新建按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `showsNewChatButtonOnlyForSelectedConversation` |
| 2 | CreateNewConversationTool | task 缺失或空白时抛出执行失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingTaskThrows` |
| 3 | CreateNewConversationTool | title 缺省或空白时由 task 推导 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `titleFallsBackToDerived` |
| 4 | CreateNewConversationTool | 显式 title 优先于推导标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `explicitTitleWins` |
| 5 | CreateNewConversationTool | 创建对话后选中态被恢复为原对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionIsRestoredAfterCreate` |
| 6 | CreateNewConversationTool | 创建失败时同样恢复选中态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionIsRestoredOnFailure` |
| 7 | CreateNewConversationTool | 无能力时返回失败文本且不抛出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingCapabilityReturnsFailureText` |
| 8 | CreateNewConversationTool | 返回内容包含可被渲染器解析的 payload | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resultContainsDecodablePayload` |
| 9 | CreateNewConversationTool | 创建对话时透传当前项目与模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createInheritsProjectAndModel` |
| 10 | CreateNewConversationTool | derivedTitleUsesFirstSentence | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `derivedTitleUsesFirstSentence` |
| 11 | CreateNewConversationTool | 超长标题被截断到上限 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `derivedTitleTruncates` |
| 12 | CreateNewConversationTool | 风险等级为 low，inputSchema 要求 task | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `schemaAndRisk` |
| 13 | CreateNewConversationTool | 展示描述包含标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayDescriptionIncludesTitle` |
| 14 | NewConversationRowRenderer | 命中本工具且 payload 可解析时渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canRenderMatchesToolWithPayload` |
| 15 | NewConversationRowRenderer | 工具名不匹配时不渲染 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `canRenderRejectsOtherTools` |
| 16 | NewConversationRowRenderer | 结果缺失或 payload 损坏时不渲染 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `canRenderRejectsUndecodableResults` |
| 17 | NewConversationRowRenderer | extractJSONHandlesEdgeCases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractJSONHandlesEdgeCases` |
| 18 | NewConversationRowRenderer | 解码保留 starter 与标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `decodeSuggestionRoundTrips` |
| 19 | NewConversationRowRenderer | 渲染优先级高于默认工具卡片 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `priorityIsAboveDefault` |

> 说明：全部 **19 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 10 / 10
- P2: 已覆盖 6 / 6
- **合计: 19 / 19**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 19 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
