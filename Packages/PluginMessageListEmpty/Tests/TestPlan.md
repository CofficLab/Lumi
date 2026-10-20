# TestPlan — PluginMessageListEmpty

## 包概述

PluginMessageListEmpty 的实现包，提供聊天区在「未选中会话 / 当前会话无消息」时的空态引导，
并以常驻注册的 ChatSection 槽位参与 `message-list` 互斥竞争。

平台: macOS 14+, iOS 17+
测试文件: 12 个，单元用例总数: 62（另有 6 条 UI 测试，见「UI 测试」章节）

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Support/`
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
- `ActivityCardSlot`
- `ActivityCardLayout`
- `ActivityFusionCard`
- `ActivityFusionCardMetrics`
- `ActivitySparkline`
- `ActivitySparklineGeometry`
- `ActivityTokenFormat`
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
- **EmptyStateTokenTrend**（7 条）：由 `token days fill the whole window including idle days`、`no token consumption keeps the trend hidden`、`values below one thousand are shown verbatim` 等用例锁定；改动 token 序列或它的紧凑数字格式化（`ActivityTokenFormat.compact`）时优先跑对应测试文件。
- **ActivityCardLayout**（2 条）：由 `activityCardOnlyGoesSideBySideWhenTheChartKeepsItsMinimumWidth`、`activityCardLayoutIgnoresWidthBeyondTheCardCap` 锁定。守住「活动卡宽度够才并排」的阈值 `ActivityCardLayout.sideBySideMinWidth`（及其组成常量），以及「卡片封顶 520pt 之后，槽位再宽也不改变排布」这条不变量；改动活动卡排布时必须优先跑该文件。
- **ActivitySparklineGeometry**（7 条）：由 `every point stays inside the canvas`、`the series is normalized against its own peak`、`a flat series becomes a horizontal line` 等用例锁定。覆盖曲线与画布的坐标映射（归一化基准、峰值贴顶、等值序列成直线、单点居中）；改动曲线绘制时必须优先跑该文件。Canvas 里画错了不会让编译失败，只能靠这组几何断言守住。

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

| 42 | EmptyStateActivityLoading | a zero result stays retryable so late-arriving data still shows | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `zeroResultDoesNotPinTheStrip` |
| 43 | EmptyStateActivityLoading | a non-zero result still short-circuits repeat queries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonZeroResultKeepsTheCacheGate` |
| 44 | MessageListEmptyUITestingSupport | seeds exactly the three conversations the UI tests depend on | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureSeedsAllThreeConversations` |
| 45 | MessageListEmptyUITestingSupport | selects the empty conversation as the starting state | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureSelectsEmptyConversation` |
| 46 | MessageListEmptyUITestingSupport | the empty conversation really has no messages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureEmptyConversationIsEmpty` |
| 47 | MessageListEmptyUITestingSupport | the history conversation has the messages the activity strip counts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureHistoryConversationHasMessages` |
| 48 | MessageListEmptyUITestingSupport | activity counts include tool messages, unlike the empty-state check | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fixtureActivityCountsUseCrossConversationScope` |
| 49 | MessageListEmptyUITestingSupport | history messages carry tokens so the trend line has data | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fixtureHistoryCarriesTokens` |
| 50 | MessageListEmptyUITestingSupport | the tool-only conversation stays empty for the empty-state check | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fixtureToolOnlyConversationCountsAsEmpty` |
| 51 | MessageListEmptyUITestingSupport | repeated seed does not duplicate conversations | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fixtureSeedIsIdempotent` |
| 52 | MessageListEmptyUITestingSupport | the fixture only activates with its launch argument | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fixtureOnlyActivatesWithLaunchArgument` |

| 53 | EmptyStateAccessibility | emptyStateAccessibilityIdentifiersAreStableAndDistinct | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyStateAccessibilityIdentifiersAreStableAndDistinct` |

| 54 | ActivityFooterLayout | activityCardOnlyGoesSideBySideWhenTheChartKeepsItsMinimumWidth | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityCardOnlyGoesSideBySideWhenTheChartKeepsItsMinimumWidth` |
| 55 | ActivityFooterLayout | activityCardLayoutIgnoresWidthBeyondTheCardCap | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityCardLayoutIgnoresWidthBeyondTheCardCap` |
| 56 | ActivitySparklineGeometry | an empty series draws nothing | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptySeriesHasNoPoints` |
| 57 | ActivitySparklineGeometry | a zero-sized canvas draws nothing | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `zeroSizedCanvasHasNoPoints` |
| 58 | ActivitySparklineGeometry | the peak sits at the top of the canvas and the valley near the bottom | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `peakAndValleyAnchorToTheCanvas` |
| 59 | ActivitySparklineGeometry | every point stays inside the canvas | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pointsStayInsideTheCanvas` |
| 60 | ActivitySparklineGeometry | the series is normalized against its own peak | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizationIsRelativeToThePeak` |
| 61 | ActivitySparklineGeometry | a flat series becomes a horizontal line | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `flatSeriesIsHorizontal` |
| 62 | ActivitySparklineGeometry | a single sample is centered horizontally | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleSampleIsCentered` |

> 说明：全部 **62 条单元场景**已在本包 `swift test` 中实跑通过（6 suites / 62 tests，约 0.02 s）；另有 6 条 UI 测试见下方章节。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 45 / 45
- P2: 已覆盖 6 / 6
- **合计: 62 / 62**（仅表示清单场景，非源码覆盖率）
- **UI 测试: 6 条**（3 通过 / 2 跳过 / 1 未执行，见「UI 测试」章节）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（11 条）
- **P1**: 其余功能性用例（45 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## UI 测试

位置：`LumiUITests/LumiMessageListEmptyUITests.swift`（独立 target，不能 import 本包，常量需复述）。
夹具：`Packages/PluginMessageListEmpty/Sources/PluginMessageListEmpty/MessageListEmptyUITestingSupport.swift`（DEBUG only）。

启动参数：`--lumi-ui-testing-message-list-empty` + `--lumi-ui-testing-isolated-storage`。

夹具植入三个会话：空会话（默认选中）、带 8 条跨 30 天历史消息的会话、仅含 1 条 tool 消息的会话。
历史消息刻意放在**另一个**会话：活动条统计是跨会话的，放进当前空会话会让「空态 + 活动条」永不共存。

| ID | 用例 | 结果 | 说明 |
|----|------|------|------|
| U1 | `testEmptyStateAppearsForConversationWithoutMessages` | ✅ 通过 | 选中无消息会话时空态出现 |
| U2 | `testActivityStripAppearsAlongsideEmptyState` | ✅ 通过 | 空态与活动卡同时出现（覆盖下述缺陷 1+2） |
| U3 | `testActivityCardRendersAnchorSummary` | ✅ 通过 | 锚点文案可见、带窗口天数 30，且落在活动卡范围内（锚点靠**文字**定位，见「无障碍标识符的传播陷阱」） |
| U4 | `testActivityCardAlignsWithThePromptFlow` | ✅ 通过 | 活动卡宽度 ≤ 520pt，且水平中心与提示胶囊流的并集中心重合 |
| U5 | `testEmptyStateAndActivityStripYieldToConversationWithMessages` | ⏭️ 跳过 | 依赖会话列表容器，本环境 rail 未渲染 |
| U6 | `testToolOnlyConversationStillShowsEmptyState` | ⏭️ 跳过 | 同上 |

> U3/U4 均已在真机跑通（`-only-testing:LumiUITests/LumiMessageListEmptyUITests`）。
> U4 的水平中心比较取「所有带 `suggestion-flow` 标识符的元素的并集」：
> 胶囊流的标识符会传播到每一个 chip 上（见下节），单取第一个匹配元素会拿到
> 某一个 chip，而不是整条流。

### 跳过的原因（环境限制，非产品缺陷）

会话列表由 rail 侧栏承载（`WorkbenchSplitView` 要求 `railView != nil && isRailViewVisible`）。
本次执行环境的窗口布局下 rail 未渲染，`lumi.conversation-list` 容器不存在。

**已在远程基线（`origin/dev`，不含本次提交）上复跑确认**：以下三类用例在同一环境下
结果一致，均为既存失败/无法执行，与本插件改动无关：

| 用例类 | 基线结果 | 本分支结果 |
|--------|---------|-----------|
| `LumiMessageListSwitchUITests`（切换遮罩） | ❌ 大会话未出现在会话列表 | 同样失败 |
| `LumiFreshInstallEmptyStateUITests`（首条消息 → 列表出现） | ❌ 2 条失败 / 1 条通过 | 完全一致 |
| `LumiMessageListEmptyUITests`（本插件切换类） | — | ⏭️ skip |

同时说明标识符契约未被破坏：基线中通过的那条
`testFreshInstallShowsEmptyStateInsteadOfBlankChat` 依赖 `no-conversation-selected`
标识符，本次改名后它仍然通过。

U5/U6 已实现为「容器不存在 → skip（附原因）；容器存在但找不到会话行 → fail」，
两者分开归因，避免环境问题掩盖真实回归。

## 无障碍标识符的传播陷阱（UI 测试实测）

SwiftUI 的 `.accessibilityIdentifier` 会**向下传播**，并且会覆盖子孙元素自己的标识符。
这条规则在合卡之后才暴露出来，实测结论如下：

| 现象 | 实测 |
|------|------|
| 标识符挂在**非元素**的容器视图上 | 完全失效：既不生成元素，也不影响子孙（`activity-card` 曾因此永远找不到） |
| 标识符挂在**元素**上（`.accessibilityElement(children:)`） | 元素自己可寻址；其子孙中**没有自己标识符**的会继承它 |
| 祖先**元素**带标识符 | 覆盖子孙**元素**的标识符（活动条带 id 时，卡片的 id 被盖掉） |
| 叶子文字自带标识符 | 能留住（锚点把标识符挂在 `Text` 上时可寻址） |
| 自定义 `Layout`（`FlowLayout`）带标识符 | 传播到它排布的每个子视图，覆盖 chip 自己的 `suggestion.<id>` |

因此本插件的活动条区域采用**只留一个可寻址元素**的策略：

- `activityStripID` 挂在**活动卡**上（它也是活动条的全部可见内容）；
- 活动条的外层容器**不设标识符**，否则会遮蔽卡片的标识符；
- 卡内的锚点文案**不设标识符**，改由**文字**定位 —— 它要被断言的本来就是
  它写着什么（「… messages in the last … days」），用文字定位更贴切。

新增标识符前请先打印一次无障碍层级树（`app.debugDescription` 后过滤 `message-list`）
确认它真的可寻址，再写断言 —— 标识符写错不会让编译失败，只会让 UI 测试在
「元素找不到」上失败。

## 由 UI 测试发现并修复的产品缺陷

### 缺陷 1：活动条永不加载（`.task` 死锁）

`ActivityCardSlot.body` 原先把内容包在 `Group { if model.hasActivity { ... } }` 上挂 `.task`。
首次渲染时 `totalMessages == nil`、`hasActivity == false`，`Group` 内容为空；
SwiftUI 不会为空分支建立真实 view identity，**`.task` 因此从不执行**。
于是 `loadIfNeeded` 永不被调用 → `hasActivity` 永远 false，构成死锁。

实测证据（临时日志，已清理）：`body` 求值 3 次，`loadIfNeeded` 执行 0 次。

修复：容器内加一个 0 高度、透明的 `Color.clear` 作为 `.task` 的挂载载体。

### 缺陷 2：零结果被缓存门永久锁死

`loadIfNeeded` 原有缓存门条件为 `totalMessages != nil`。
App 启动时空态先渲染、跨会话统计稍后就绪，首次查询**本来就该是 0**；
一旦得到 0 就被判定为「已加载」，此后永不重查。

实测时序：查询返回 0 → 0.4s 后数据就绪（合计 9 条）→ 再次进入空态命中缓存门 → 活动条不显示。

修复：只在 `totalMessages > 0` 时命中缓存门。零结果视为「可能还没准备好」，保持可重试。
回归防护：`zeroResultDoesNotPinTheStrip`（已用变异测试验证：改回旧逻辑该用例即失败）。

**用户可感知症状**：明明有历史数据，本次运行内底部活动条一直不出现。

## 未覆盖范围

以下部分**没有**测试覆盖，属已知缺口，不得当作已验证：

- **矮窗口下活动卡是否仍在首屏可见**。
  活动卡已从 `bottomFixed` 底栏槽位移入空态内容流（紧跟提示胶囊），
  矮窗口时它可能落在首屏之外，需要滚动才能看到 —— 这是为「融合」刻意做的取舍。
  `XCUIElement.frame` 只读，XCUITest 没有稳定的 macOS 窗口 resize API；拖拽窗口边缘会引入 flake。
  项目既有边界一致：`LumiMessageListBriefUITests` 同样把 resize 归为「纯视觉验证，以人工验收为主」。
- **纯视觉细节**：热力图色阶、`EmptyStateAtmosphere` 渐变、chip 圆角与阴影。需截图回归，CI 成本过高。
- **锚点文案的具体计数**：由夹具单测 `fixtureActivityCountsUseCrossConversationScope` 钉住，
  UI 层只断言文案渲染与窗口天数，不在两层重复脆弱断言。
- **文件夹导入 / 项目切换流程**：`fileImporter` 涉及系统面板，UI 测试无法可靠驱动。

## 跨平台说明

- 单元测试：Package 声明 macOS 14+, iOS 17+，62 条用例位于 `Tests/`
- UI 测试：仅 macOS（`LumiUITests` target），6 条用例

## 测试执行

```bash
# 单元测试
cd Packages/PluginMessageListEmpty
swift test

# UI 测试（macOS，需要能渲染 rail 侧栏的窗口布局）
xcodebuild -project Lumi.xcodeproj -scheme Lumi -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListEmptyUITests test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
6. **异步用例避免 sleep 等待** → 用可控 stub（挂起 + continuation）而非固定时长睡眠，确保慢机器上不 flake
7. **断言有效性自检** → 新增异步/竞态用例后，建议对被测代码做一次变异（如删掉守卫、把归一化改成截断）确认新用例会失败；不会失败的断言等于没有断言
