# TestPlan — PluginConversationTokenUsage

## 包概述

PluginConversationTokenUsage 的实现包，包含 7 个主要类型；当前测试覆盖 21 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 21

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Support/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationTokenUsagePlugin`
- `TokenUsageToolbarState`
- `TokenUsageStats`
- `TokenUsageObserver`
- `TokenCountFormatter`
- `TokenUsageHeaderView`
- `TokenUsagePopover`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **TokenUsageObserverAndLifecycle**（12 条）：由 `observerReplaysCurrentSelectionOnInit`、`observerForwardsSelectionChanges`、`observerForwardsEveryMessageChangeKind` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenUsageStats**（9 条）：由 `tokenUsageAggregatesInputAndOutputTokens`、`tokenUsagePrefersCacheTotalInputTokensOverRawInput`、`tokenUsageIgnoresNonAssistantMessages` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | TokenUsageObserverAndLifecycle | 初始化时立即回放当前选中会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `observerReplaysCurrentSelectionOnInit` |
| 2 | TokenUsageObserverAndLifecycle | 选中会话变化时转发新的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerForwardsSelectionChanges` |
| 3 | TokenUsageObserverAndLifecycle | 五类消息变化事件都转发所属会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerForwardsEveryMessageChangeKind` |
| 4 | TokenUsageObserverAndLifecycle | 取消后释放两个订阅并停止转发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerCancelReleasesSubscriptions` |
| 5 | TokenUsageObserverAndLifecycle | 重复取消是幂等的 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `observerCancelIsIdempotent` |
| 6 | TokenUsageObserverAndLifecycle | 启动后注册 header 右侧贡献项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootRegistersHeaderTrailingItem` |
| 7 | TokenUsageObserverAndLifecycle | 缺少必需 Provider 时不注册贡献项也不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutProvidersIsNoop` |
| 8 | TokenUsageObserverAndLifecycle | 启动时把当前选中会话同步到 header 状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootSyncsSelectedConversationToToolbarState` |
| 9 | TokenUsageObserverAndLifecycle | 选中会话变化后 header 状态跟随更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionChangeUpdatesToolbarState` |
| 10 | TokenUsageObserverAndLifecycle | 重复启动会注销上一轮的观察者 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `secondBootCancelsPreviousObserver` |
| 11 | TokenUsageObserverAndLifecycle | 关闭时移除贡献项并注销观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesItemAndCancelsObserver` |
| 12 | TokenUsageObserverAndLifecycle | 未启动就关闭不会抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownWithoutBootIsSafe` |
| 13 | TokenUsageStats | tokenUsageAggregatesInputAndOutputTokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenUsageAggregatesInputAndOutputTokens` |
| 14 | TokenUsageStats | tokenUsagePrefersCacheTotalInputTokensOverRawInput | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenUsagePrefersCacheTotalInputTokensOverRawInput` |
| 15 | TokenUsageStats | tokenUsageIgnoresNonAssistantMessages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenUsageIgnoresNonAssistantMessages` |
| 16 | TokenUsageStats | tokenUsageSkipsResponsesWithoutReportedUsage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenUsageSkipsResponsesWithoutReportedUsage` |
| 17 | TokenUsageStats | tokenUsageEmptyStatsHaveZeroTotals | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `tokenUsageEmptyStatsHaveZeroTotals` |
| 18 | TokenUsageStats | tokenCountFormatterKeepsSmallValuesVerbatim | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenCountFormatterKeepsSmallValuesVerbatim` |
| 19 | TokenUsageStats | tokenCountFormatterUsesUnitsAndPromotesAcrossMagnitudes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenCountFormatterUsesUnitsAndPromotesAcrossMagnitudes` |
| 20 | TokenUsageStats | toolbarStateForwardsTypedEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarStateForwardsTypedEvents` |
| 21 | TokenUsageStats | toolbarStateDoesNotNotifyWhenSelectionIsUnchanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarStateDoesNotNotifyWhenSelectionIsUnchanged` |

> 说明：全部 **21 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 17 / 17
- P2: 已覆盖 1 / 1
- **合计: 21 / 21**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（17 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 21 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationTokenUsage
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
