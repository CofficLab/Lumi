# TestPlan — PluginActivityHeatmap

## 包概述

PluginActivityHeatmap 的实现包，包含 11 个主要类型；当前测试覆盖 24 条用例。

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 24

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

- **ActivityHeatmapViewModel**（5 条）：由 `reloadsAndCachesDailyCounts`、`reportsPeakTokenDay`、`burstInsertionsCoalesceIntoSingleReload` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitActivityHeatmapProjectViewModel**（2 条）：由 `scopesSnapshotsToTheSelectedProject`、`updatesRepositoryPath` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitActivityHeatmapProjectSection**（3 条）：由 `outOfWindowDayIsNotCounted`、`inWindowDaysAreCounted`、`gridEndIsExclusive` 等用例锁定；summary 必须与 52 周网格共用同一日期窗口，改动该模块时优先跑对应测试文件。
- **LocalGitActivityHeatmapProviderRefresh**（3 条）：由 `refreshLoadsAndCachesRecentHistory`、`failedInitialLoadClearsLoading`、`snapshotIgnoresMalformedDatesAndStandardizesPath` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LocalGitActivityHeatmapProvider**（1 条）：由 `groupsCommitsByDay` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（2 条）：由 `activityPeriodHasLegacyRanges`、`activityCachePersistsHistoricalCounts` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenCountFormat**（5 条）：由 `keepsSmallValues`、`compactsThousands`、`compactsMillions` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LocalGitActivityHeatmapProviderOffMain**（3 条）：由 `cacheWriteRunsOffMainActor`、`mainActorStaysResponsiveWhileCacheWriteIsBlocked`、`loadingCarriesParsedDatesForward` 锁定（**回归 #1203**）：Git I/O 之后的聚合与缓存写入必须在后台 executor 上执行，主 actor 只做 token 校验与状态发布。改动 `refresh` 的任务结构或 `makeSnapshot`/`persist` 的调用位置时优先跑对应测试文件。

### Git activity 刷新的 executor 契约（回归 #1203）

`LocalGitActivityHeatmapProvider` 是 `@MainActor`。`nonisolated static` 只是解除隔离声明，**从主 actor 的 Task 里同步调用并不会换 executor**：旧实现在 `await` 加载之后直接同步调用 `makeSnapshot` 与 `persist`，于是「按天聚合 + JSON 编码 + 建目录 + 原子写盘」整段留在主线程，仓库刷新时 UI 正好在等这份数据。

契约：分页加载 → 日期解析 → 按天聚合 → 编码写盘整段放进 `Task.detached`，主 actor 只在 `await` 之后校验 `refreshToken` 并发布 `currentSnapshot` / `isLoading`。日期在加载/过滤阶段解析一次并以 `[Date]` 带到聚合阶段（`loadRecentCommitDates` → `makeSnapshot(commitDates:)`），聚合阶段不再接触字符串日期。缓存写入通过 `CacheWriter` 注入点可断言其 executor；等待方必须异步轮询，在 MainActor 上同步 wait 会挡住被测任务本身。

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
| 17 | GitActivityHeatmapProjectSection | counts only the visible 52-week window, not the wider 12-month load range | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `outOfWindowDayIsNotCounted` |
| 18 | GitActivityHeatmapProjectSection | counts every visible day inclusively from grid start through the last cell | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inWindowDaysAreCounted` |
| 19 | GitActivityHeatmapProjectSection | excludes the day at the exclusive right edge of the grid window | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gridEndIsExclusive` |
| 20 | ActivityHeatmapViewModel | a burst of insertions coalesces into one debounced reload (#1262) | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `burstInsertionsCoalesceIntoSingleReload` |
| 21 | ActivityHeatmapViewModel | an immediate reload cancels a pending debounced reload (#1262) | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `immediateReloadCancelsPendingDebounce` |
| 22 | LocalGitActivityHeatmapProviderOffMain | 缓存写入不得在主 actor 上执行（回归 #1203） | 注入 CacheWriter 探针记录所在线程 | refresh 后异步轮询探针 | 写盘线程非主线程，且探针快照与最终发布的一致 | P0 | ✅ 已覆盖 | `cacheWriteRunsOffMainActor` |
| 23 | LocalGitActivityHeatmapProviderOffMain | 缓存写入被挡住时主 actor 仍能继续跳板（回归 #1203） | 探针门闩阻塞写盘（5s 安全网） | 门闩期间在主 actor 上连续跳板 | 主 actor 正常推进，loading 未提前结束，释放后正常收尾 | P0 | ✅ 已覆盖 | `mainActorStaysResponsiveWhileCacheWriteIsBlocked` |
| 24 | LocalGitActivityHeatmapProviderOffMain | 加载阶段返回解析好的日期，越界即停止分页（回归 #1203） | 两页提交，第二页混入越界与非法日期 | 调用 loadRecentCommitDates 后聚合 | 每个日期只解析一次并带到聚合，越界提交被丢弃且分页停止 | P1 | ✅ 已覆盖 | `loadingCarriesParsedDatesForward` |

> 说明：全部 **24 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 18 / 18
- P2: 已覆盖 0 / 0
- **合计: 24 / 24**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（18 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 24 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
