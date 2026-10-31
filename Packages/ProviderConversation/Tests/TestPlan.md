# TestPlan — ProviderConversation

## 包概述

ProviderConversation 的实现包，包含 8 个主要类型；当前测试覆盖 17 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 17

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AutomationLevel`
- `ConversationLanguage`
- `SelectedConversationObserverHandle`
- `ConversationEvent`
- `ConversationSummary`
- `DefaultConversationManager`
- `ReasoningEffort`
- `ResponseVerbosity`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（17 条）：由 `testCreateConversationSelectsAndUpdatesTitle`、`testEmptyTitleFallsBackToUntitled`、`testSelectDeselectDelete` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | testCreateConversationSelectsAndUpdatesTitle | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testCreateConversationSelectsAndUpdatesTitle` |
| 2 | 综合 | testEmptyTitleFallsBackToUntitled | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmptyTitleFallsBackToUntitled` |
| 3 | 综合 | testSelectDeselectDelete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSelectDeselectDelete` |
| 4 | 综合 | testSortedConversationsByLastMessage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSortedConversationsByLastMessage` |
| 5 | 综合 | testUpdateTitle | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testUpdateTitle` |
| 6 | 综合 | testConversationModelSelectionUsesSingleStableID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testConversationModelSelectionUsesSingleStableID` |
| 7 | 综合 | testConversationSummaryDecodesLegacyProviderAndModelPair | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testConversationSummaryDecodesLegacyProviderAndModelPair` |
| 8 | 综合 | testPerConversationPreferences | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPerConversationPreferences` |
| 9 | 综合 | testSettingSameVerbosityDoesNotNotify | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSettingSameVerbosityDoesNotNotify` |
| 10 | 综合 | testGlobalPreferencesApplyToNewConversations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testGlobalPreferencesApplyToNewConversations` |
| 11 | 综合 | testConversationCountAndProjectCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testConversationCountAndProjectCount` |
| 12 | 综合 | testFetchConversationPageFiltersByProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFetchConversationPageFiltersByProject` |
| 13 | 综合 | testSelectedConversationObserverReceivesChanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSelectedConversationObserverReceivesChanges` |
| 14 | 综合 | testSelectedConversationObserverStopsAfterCancel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSelectedConversationObserverStopsAfterCancel` |
| 15 | 综合 | testSelectedConversationObserverAutoUnregistersOnDeinit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSelectedConversationObserverAutoUnregistersOnDeinit` |
| 16 | 综合 | testConversationObserverReceivesSemanticChanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testConversationObserverReceivesSemanticChanges` |
| 17 | 综合 | testMultipleSelectedConversationObservers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleSelectedConversationObservers` |

> 说明：全部 **17 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 13 / 13
- P2: 已覆盖 4 / 4
- **合计: 17 / 17**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 17 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderConversation
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
