# TestPlan — PluginActivityHeatmap

## 包概述

PluginActivityHeatmap 的实现包，包含 11 个主要类型；当前测试覆盖 16 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 16

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`
- `Providers/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ActivityHeatmapPlugin`
- `GitActivityHeatmapProjectCapability`
- `ActivityHeatmapIdleTimeState`
- `GitActivityHeatmapProjectObserver`
- `MessageObserver`
- `LocalGitActivityHeatmapProvider`
- `TokenCountFormat`
- `GitActivityHeatmapProjectViewModel`
- `ActivityHeatmapManualView`
- `ActivityTokenTrendChart`
- `GitActivityHeatmapProjectSection`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ActivityHeatmapViewModel**（3 条）：由 `reloadsAndCachesDailyCounts`、`reportsPeakTokenDay`、`ignoresConsumptionOutsideTrendWindow` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitActivityHeatmapProjectViewModel**（2 条）：由 `scopesSnapshotsToTheSelectedProject`、`updatesRepositoryPath` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LocalGitActivityHeatmapProviderRefresh**（3 条）：由 `refreshLoadsAndCachesRecentHistory`、`failedInitialLoadClearsLoading`、`snapshotIgnoresMalformedDatesAndStandardizesPath` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LocalGitActivityHeatmapProvider**（1 条）：由 `groupsCommitsByDay` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（2 条）：由 `activityPeriodHasLegacyRanges`、`activityCachePersistsHistoricalCounts` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenCountFormat**（5 条）：由 `keepsSmallValues`、`compactsThousands`、`compactsMillions` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ActivityHeatmapViewModel | loads missing history once, combines cached days with today's live counts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reloadsAndCachesDailyCounts` |
| 2 | ActivityHeatmapViewModel | peak token day picks the busiest day inside the trend window | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsPeakTokenDay` |
| 3 | ActivityHeatmapViewModel | peak token day ignores consumption outside the trend window | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresConsumptionOutsideTrendWindow` |
| 4 | GitActivityHeatmapProjectViewModel | syncs the matching project snapshot and rejects another repository's snapshot | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `scopesSnapshotsToTheSelectedProject` |
| 5 | GitActivityHeatmapProjectViewModel | updates the watched repository only when the project path changes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updatesRepositoryPath` |
| 6 | LocalGitActivityHeatmapProviderRefresh | loads recent history in pages, caches its snapshot, and cancels observers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshLoadsAndCachesRecentHistory` |
| 7 | LocalGitActivityHeatmapProviderRefresh | a failed first load always clears the loading state | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedInitialLoadClearsLoading` |
| 8 | LocalGitActivityHeatmapProviderRefresh | ignores malformed commit dates and standardizes repository paths | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `snapshotIgnoresMalformedDatesAndStandardizesPath` |
| 9 | LocalGitActivityHeatmapProvider | groups commit logs by the local calendar day | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `groupsCommitsByDay` |
| 10 | 综合 | activityPeriodHasLegacyRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityPeriodHasLegacyRanges` |
| 11 | 综合 | activityCachePersistsHistoricalCounts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityCachePersistsHistoricalCounts` |
| 12 | TokenCountFormat | keeps values below one thousand as-is | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsSmallValues` |
| 13 | TokenCountFormat | compacts thousands with one decimal below one hundred | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactsThousands` |
| 14 | TokenCountFormat | compacts millions with one decimal below one hundred | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactsMillions` |
| 15 | TokenCountFormat | compacts billions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactsBillions` |
| 16 | TokenCountFormat | promotes to a larger unit when rounding crosses a magnitude | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `promotesAcrossMagnitude` |

> 说明：全部 **16 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 15 / 15
- P2: 已覆盖 0 / 0
- **合计: 16 / 16**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 16 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginActivityHeatmap
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
