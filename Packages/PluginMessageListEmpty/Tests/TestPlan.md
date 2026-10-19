# TestPlan — PluginMessageListEmpty

## 包概述

PluginMessageListEmpty 的实现包，提供聊天区在「未选中会话 / 当前会话无消息」时的空态引导，
并以常驻注册的 ChatSection 槽位参与 `message-list` 互斥竞争。

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 41

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PluginMessageListEmptyPlugin`
- `MessageListEmptyServices`
- `MessageListGuideState`
- `NoConversationSelectedToolbarCoordinator`
- `EmptyStateActivityDay`
- `EmptyStateTokenDay`
- `ActivityFooterView`
- `EmptyStateAtmosphere`
- `MessageEmptyStateView`
- `NoConversationSelectedView`
- `PromptSuggestionFlow`
- `EmptyStateActivityViewModel`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CapabilityMotifGeometry**（5 条）：由 `motifCardSitsFullyInsideTheCanvas`、`motifSupportingGeometryStaysInsideTheCard`、`motifBandsStayInsideTheCardAndDoNotOverlap` 等用例锁定；改动该模块时优先跑对应测试文件。
- **FlowLayoutGeometry**（2 条）：由 `flowLayoutReportsTheWidestWrappedRowAndPositionsEachItem`、`flowLayoutUsesNaturalWidthWithoutWrappingAndHandlesNoItems` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GuideObserver**（2 条）：由 `guideStateTracksContextSelectionProjectsAndSuggestionChanges`、`toolbarCoordinatorOnlyHidesProjectToolsWhileActiveAndNoProjectsExist` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PluginMessageListEmptyPlugin**（4 条）：由 `pluginShowsEmptyStateOnlyForSelectedConversationWithoutVisibleMessages`、`pluginCanProvideNoSelectionEmptyStateWithoutOptionalProviders`、`pluginDoesNotBootWithoutChatSectionProvider`、`abandonedEvaluationNeverLeavesStateHanging` 锁定；改动该模块时优先跑对应测试文件。
- **PromptSuggestionVisibility**（2 条）：由 `promptSuggestionsRespectProjectVisibilityAndLauncherScope`、`promptSuggestionVisibilityAndScopeMustBothMatch` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RegistrationEvaluationWindow**（2 条，P0）：由 `emptyStateStaysOutOfTheSlotWhileEvaluationIsInFlight`、`emptyStateOnlyAppearsAfterEvaluationSettles` 锁定。锁定 `registrationState = .evaluating` 期间**不参与** `message-list` 槽位竞争这一三态模型核心不变量；改动 `scheduleRegistrationEvaluation` / `shouldRenderEmptyState` 时必须优先跑该文件。
- **EmptyStateActivityLoading**（7 条）：由 `loading fills the window and derives totals from both series`、`re-entering the empty state on the same day reuses the loaded window`、`a stale slow load cannot overwrite a newer window`、`a missing message provider degrades to an invisible strip` 锁定。覆盖 `loadIfNeeded(force:)` 的窗口填充、同日缓存门、`loadGeneration` 竞态防护、缺 provider 降级、token 与消息两级独立判空；改动 `EmptyStateActivityViewModel` 的加载路径时必须优先跑该文件。
- **EmptyStateActivityWindow**（10 条）：由 `the window covers every calendar day including idle ones`、`a same-day merge keeps the larger count regardless of arrival order`、`levels are normalized against the busiest day in the window`、`a quiet day next to a busy one stays on the lowest active level` 锁定。覆盖 `makeDays` 的窗口填充、跨天归一化、同日合并取 max、level 相对峰值归一化与 ceiling 除法；改动热力图分桶逻辑时必须优先跑该文件。
- **EmptyStateTokenTrend**（7 条）：由 `token days fill the whole window including idle days`、`no token consumption keeps the trend hidden`、`values below one thousand are shown verbatim` 等用例锁定；改动 token 趋势线或其紧凑数字格式化时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CapabilityMotifGeometry | motifCardSitsFullyInsideTheCanvas | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `motifCardSitsFullyInsideTheCanvas` |
| 2 | CapabilityMotifGeometry | motifSupportingGeometryStaysInsideTheCard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `motifSupportingGeometryStaysInsideTheCard` |
| 3 | CapabilityMotifGeometry | motifBandsStayInsideTheCardAndDoNotOverlap | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `motifBandsStayInsideTheCardAndDoNotOverlap` |
| 4 | CapabilityMotifGeometry | motifSymbolFitsWithinTheCardForEverySupportedSize | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `motifSymbolFitsWithinTheCardForEverySupportedSize` |
| 5 | CapabilityMotifGeometry | motifRejectsGeometryThatLeavesTheCard | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `motifRejectsGeometryThatLeavesTheCard` |
| 6 | FlowLayoutGeometry | flowLayoutReportsTheWidestWrappedRowAndPositionsEachItem | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `flowLayoutReportsTheWidestWrappedRowAndPositionsEachItem` |
| 7 | FlowLayoutGeometry | flowLayoutUsesNaturalWidthWithoutWrappingAndHandlesNoItems | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `flowLayoutUsesNaturalWidthWithoutWrappingAndHandlesNoItems` |
| 8 | GuideObserver | guideStateTracksContextSelectionProjectsAndSuggestionChanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `guideStateTracksContextSelectionProjectsAndSuggestionChanges` |
| 9 | GuideObserver | toolbarCoordinatorOnlyHidesProjectToolsWhileActiveAndNoProjectsExist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarCoordinatorOnlyHidesProjectToolsWhileActiveAndNoProjectsExist` |
| 10 | PluginMessageListEmptyPlugin | pluginShowsEmptyStateOnlyForSelectedConversationWithoutVisibleMessages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginShowsEmptyStateOnlyForSelectedConversationWithoutVisibleMessages` |
| 11 | PluginMessageListEmptyPlugin | pluginCanProvideNoSelectionEmptyStateWithoutOptionalProviders | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginCanProvideNoSelectionEmptyStateWithoutOptionalProviders` |
| 12 | PluginMessageListEmptyPlugin | pluginDoesNotBootWithoutChatSectionProvider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginDoesNotBootWithoutChatSectionProvider` |
| 13 | PluginMessageListEmptyPlugin | abandonedEvaluationNeverLeavesStateHanging | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `abandonedEvaluationNeverLeavesStateHanging` |
| 14 | PromptSuggestionVisibility | promptSuggestionsRespectProjectVisibilityAndLauncherScope | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `promptSuggestionsRespectProjectVisibilityAndLauncherScope` |
| 15 | PromptSuggestionVisibility | promptSuggestionVisibilityAndScopeMustBothMatch | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `promptSuggestionVisibilityAndScopeMustBothMatch` |
| 16 | RegistrationEvaluationWindow | emptyStateStaysOutOfTheSlotWhileEvaluationIsInFlight | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyStateStaysOutOfTheSlotWhileEvaluationIsInFlight` |
| 17 | RegistrationEvaluationWindow | emptyStateOnlyAppearsAfterEvaluationSettles | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyStateOnlyAppearsAfterEvaluationSettles` |
| 18 | EmptyStateActivityLoading | loading fills the window and derives totals from both series | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadPopulatesWindowAndTotals` |
| 19 | EmptyStateActivityLoading | the provider is asked for a window anchored at the model calendar | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadQueriesWindowStart` |
| 20 | EmptyStateActivityLoading | re-entering the empty state on the same day reuses the loaded window | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameDayReentryHitsTheCacheGate` |
| 21 | EmptyStateActivityLoading | an empty history resolves to zero instead of staying unknown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyHistoryResolvesToZero` |
| 22 | EmptyStateActivityLoading | a missing message provider degrades to an invisible strip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingProviderDegrades` |
| 23 | EmptyStateActivityLoading | a stale slow load cannot overwrite a newer window | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleSlowLoadLosesToTheNewerOne` |
| 24 | EmptyStateActivityLoading | token activity is tracked independently from message activity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenActivityIsIndependentFromMessages` |
| 25 | EmptyStateActivityWindow | the window covers every calendar day including idle ones | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `windowCoversIdleDays` |
| 26 | EmptyStateActivityWindow | timestamps inside one day collapse into a single bucket | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `timestampsNormalizeIntoDayBuckets` |
| 27 | EmptyStateActivityWindow | a same-day merge keeps the larger count regardless of arrival order | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameDayMergeKeepsLargerCountInEitherOrder` |
| 28 | EmptyStateActivityWindow | levels are normalized against the busiest day in the window | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `levelsNormalizeAgainstPeak` |
| 29 | EmptyStateActivityWindow | a quiet day next to a busy one stays on the lowest active level | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quietDayDoesNotRoundDownToEmpty` |
| 30 | EmptyStateActivityWindow | the only active day is the peak and lands on the top level | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loneActiveDayIsThePeak` |
| 31 | EmptyStateActivityWindow | an all-zero window stays entirely on the empty level | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `allZeroWindowStaysEmpty` |
| 32 | EmptyStateActivityWindow | a window ending before it starts produces no entries | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `invertedWindowIsEmpty` |
| 33 | EmptyStateActivityWindow | the visible range spans the first and last day of the window | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visibleRangeCoversTheWindow` |
| 34 | EmptyStateActivityWindow | a seeded all-zero window hides the strip instead of drawing an empty grid | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `seededZeroWindowHidesStrip` |
| 35 | EmptyStateTokenTrend | token days fill the whole window including idle days | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenDaysFillWindow` |
| 36 | EmptyStateTokenTrend | token days normalize timestamps falling inside the same day | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenDaysNormalizeToDayBuckets` |
| 37 | EmptyStateTokenTrend | no token consumption keeps the trend hidden | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenActivityIsHiddenWhenEmpty` |
| 38 | EmptyStateTokenTrend | seeded token days make the trend visible | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `seededTokenDaysEnableTrend` |
| 39 | CompactTokenFormatting | values below one thousand are shown verbatim | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smallValuesVerbatim` |
| 40 | CompactTokenFormatting | thousands switch to one decimal below one hundred units | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `thousandsFormatting` |
| 41 | CompactTokenFormatting | millions and billions use their own suffixes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `largeMagnitudes` |

> 说明：全部 **41 条场景**已在本包 `swift test` 中实跑通过（4 suites / 41 tests，约 0.1 s）。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 32 / 32
- P2: 已覆盖 3 / 3
- **合计: 41 / 41**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（32 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 未覆盖范围

以下部分**没有**单元测试覆盖，属已知缺口，不得当作已验证：

- **UI 呈现**：空态引导页、英雄图标、`EmptyStateAtmosphere`、建议 chip 的流式布局、chip 点击后执行 prompt、文件夹导入流程。
- **底部活动条布局**：`bottomFixed` 槽位在矮窗口下不被挤出屏幕这一设计理由，目前仅靠代码评审保证，无 UI 测试。
- **i18n 文案**：`summaryText` 的本地化模板渲染未做断言。

补 UI 测试时建议最高优先级覆盖「矮窗口 + 有历史数据」组合，它直接验证 `bottomFixed` 存在的理由。

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 41 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMessageListEmpty
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
6. **异步用例避免 sleep 等待** → 用可控 stub（挂起 + continuation）而非固定时长睡眠，确保慢机器上不 flake
7. **断言有效性自检** → 新增异步/竞态用例后，建议对被测代码做一次变异（如删掉守卫、把归一化改成截断）确认新用例会失败；不会失败的断言等于没有断言
