# TestPlan — PluginConversationFork

## 包概述

PluginConversationFork 的实现包，包含 5 个主要类型；当前测试覆盖 15 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 15

核心组件（源码目录）:
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationForkButton`
- `ConversationForkCoordinator`
- `ConversationForkPlugin`
- `ConversationForkPopoverContent`
- `ConversationSummarizer`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（15 条）：由 `summarizerEmptyFallback`、`summarizerFallbackWithHistory`、`renderHistory` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | Summarizer 回退摘要：无历史时返回占位 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `summarizerEmptyFallback` |
| 2 | 综合 | Summarizer 回退摘要：有历史时拼装本地摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summarizerFallbackWithHistory` |
| 3 | 综合 | renderHistory 渲染 user/assistant 前缀 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderHistory` |
| 4 | 综合 | filteredMessages 只保留 user/assistant 且非空消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `filteredMessagesDropsIrrelevantRolesAndEmpty` |
| 5 | 综合 | filteredMessages 仅保留最近 maxMessages 条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filteredMessagesKeepsRecentOnly` |
| 6 | 综合 | filteredMessages 截断超长单条消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `filteredMessagesTruncatesLongContent` |
| 7 | 综合 | Fork 按钮通过 sender 发送摘要到新对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forkSendsSummary` |
| 8 | 综合 | preview 统计参与摘要的消息条数与提问轮数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `previewCountsMessagesAndRequests` |
| 9 | 综合 | preview 对空对话标记为无内容 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `previewEmptyConversation` |
| 10 | 综合 | preview 以传入的源对话为准，不跟随当前选中对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `previewTargetsGivenConversation` |
| 11 | 综合 | fork 建新对话、注入摘要并透传标题/项目/模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `forkCreatesConversationAndSendsSummary` |
| 12 | 综合 | fork 以传入的源对话为准，不跟随当前选中对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forkTargetsGivenConversation` |
| 13 | 综合 | fork 对空对话抛出 emptyConversation，且不新建对话 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `forkEmptyConversationThrows` |
| 14 | 综合 | displayTitle 回退到最后一条提问 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayTitleFallsBackToLastRequest` |
| 15 | 综合 | truncate 截断超长文本并补省略号 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `truncateLongText` |

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 7 / 7
- P2: 已覆盖 6 / 6
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（7 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
