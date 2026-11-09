# TestPlan — PluginProjectFileTree

## 包概述

PluginProjectFileTree 的实现包，包含 15 个主要类型；当前测试覆盖 16 条用例。

平台: macOS 14+, iOS 17+
测试文件: 7 个，用例总数: 16

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `FileTreeContext`
- `ProjectFileTreePluginRuntimeBridge`
- `ProjectFileTreePlugin`
- `CollectionItem`
- `FileTreeNodeItem`
- `PackageDependencyKind`
- `PathFormatter`
- `SelectionState`
- `FileTreeAppearanceObserver`
- `FileTreeObserver`
- `RefreshCoordinator`
- `ProjectProvidingObserver`
- `FileTreeActions`
- `FileSystemReading`
- `FileTreeDropProcessor`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ProjectFileTreePlugin**（2 条）：由 `explorerTabFollowsCurrentProject`、`gitStatusProviderDrainsLargeOutput` 等用例锁定；改动该模块时优先跑对应测试文件。
- **FileTreeDataSource**（1 条）：由 `collapsingParentClearsDescendantExpansion` 锁定；改动展开/折叠状态或展开路径持久化时优先跑对应测试文件。
- **RefreshCoordinator**（4 条）：由 `sameRootPathReappearanceRestartsWatching`、`sameRootPathReappearanceKeepsExpandedPaths`、`emptyRootPathDoesNotStartWatching`、`fullRefreshDoesNotStallTargetedRefresh` 锁定。视图消失会调用 `stop()` 关闭 watcher；同一根路径再次出现时必须重新挂载监听（并保留展开目录），不能因路径相等直接返回（**回归 #1097**）。全量刷新与精准刷新必须各自持有防抖任务且真正响应取消，全量刷新不能把精准 trailing 窗口取消后留下永久 pending（**回归 #1099**）。
- **FileTreeNSViewBridge**（2 条）：由 `newGitStatusTokenUpdatesVisibleRows`、`repeatedGitStatusTokenDoesNotReload` 锁定。新 Git 快照令牌必须通过 `updateGitStatus` 赋值并重载可见行，不能只改属性；相同令牌不得重复重载（**回归 #1098**）。
- **FileTreeDropProcessor**（2 条）：由 `partialDropFailureReportsFailedSources`、`successfulDropReportsNoFailedSources` 锁定。单个源移动失败不能静默跳过，`.moved` 必须携带 `failedSources` 供调用方提示部分失败（**回归 #1100**）。
- **SelectionState**（2 条）：由 `shiftClickSelectsEveryVisibleItemInRange`、`visibleOrderUpdateDropsCollapsedItems` 锁定。Shift 范围选择依赖 `updateVisibleOrder` 建立的显示顺序，重建时必须丢弃已折叠/不可见行（**回归 #1101**）。
- **FileTreeCollectionViewController**（1 条）：由 `controllerTracksVisibleOrderForShiftSelection` 锁定。每次树快照变化都必须把可见文件行按顺序写入 `SelectionState`，否则 Shift 点击只能退化为单选，右键“Send to Conversation”会漏发中间文件（**回归 #1101**）。
- **FileTreeCollectionViewController（反选）**（2 条）：由 `commandDeselectRemovesPathFromSelection`、`deselectCallbackKeepsRowStillSelectedNatively` 锁定。Cmd 点击已选项必须实现 `didDeselectItemsAt` 并移除自定义路径，否则发送目标仍包含已取消文件；回调中仍在原生选中集合内的行不得移除（**回归 #1102**）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ProjectFileTreePlugin | 文件树仅在存在当前项目时显示 Explorer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explorerTabFollowsCurrentProject` |
| 2 | ProjectFileTreePlugin | Git 状态扫描可处理超过 pipe 缓冲区的大量输出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitStatusProviderDrainsLargeOutput` |
| 3 | FileTreeDataSource | 折叠父目录会同时清除后代的展开状态与持久化记录 | 已展开 `src` 及其子目录 `src/Views` | 折叠 `src` 后再次展开 | 子目录保持折叠，持久化中不再包含 `/src/Views` | P0 | ✅ 已覆盖 | `collapsingParentClearsDescendantExpansion` |
| 4 | RefreshCoordinator | 视图消失后以同一根路径重新出现时重新挂载监听（**回归 #1097**） | 已设置根路径并 `stop()` | 再次 `setProjectRootPath` 相同路径 | 重新向 watcher 下发包含根目录的监听集合 | P0 | ✅ 已覆盖 | `sameRootPathReappearanceRestartsWatching` |
| 5 | RefreshCoordinator | 重新出现时仍监听此前展开的目录 | 根路径下有已展开的 `Sources` | `stop()` 后以相同路径重新出现 | watcher 收到包含 `Sources` 的新监听集合 | P1 | ✅ 已覆盖 | `sameRootPathReappearanceKeepsExpandedPaths` |
| 6 | RefreshCoordinator | 空根路径重复设置不会启动监听 | 无项目根路径 | 连续两次设置空路径 | watcher 未收到任何监听更新 | P2 | ✅ 已覆盖 | `emptyRootPathDoesNotStartWatching` |
| 7 | FileTreeNSViewBridge | 新的 Git 快照令牌会重载可见行（**回归 #1098**） | 桥接 Coordinator 已处理令牌 0 | 收到新令牌 1 与非空快照 | 视图控制器收到 `updateGitStatus`，快照内容为最新值 | P0 | ✅ 已覆盖 | `newGitStatusTokenUpdatesVisibleRows` |
| 8 | FileTreeNSViewBridge | 相同 Git 状态令牌不会重复重载 | 桥接 Coordinator 已处理令牌 1 | 再次收到令牌 1 | 视图控制器只收到一次更新 | P2 | ✅ 已覆盖 | `repeatedGitStatusTokenDoesNotReload` |
| 9 | RefreshCoordinator | 全量刷新不会让精准刷新永久停摆（**回归 #1099**） | E1 已发布并处于 trailing 窗口 | 窗口内调用 `refresh()`，随后产生 E2 | E2 仍递增 `targetedRefreshToken`，不会停在 pending | P0 | ✅ 已覆盖 | `fullRefreshDoesNotStallTargetedRefresh` |
| 10 | FileTreeDropProcessor | 部分移动失败时必须上报失败源（**回归 #1100**） | 两个源中一个移动成功、一个目标同名冲突 | 执行拖放处理 | `.moved` 的 `failedSources` 仅含失败源，`affectedParents` 只含成功源的父目录 | P0 | ✅ 已覆盖 | `partialDropFailureReportsFailedSources` |
| 11 | FileTreeDropProcessor | 全部移动成功时失败源列表为空 | 两个源均可移动 | 执行拖放处理 | `.moved` 的 `pairs` 为 2，`failedSources` 为空 | P1 | ✅ 已覆盖 | `successfulDropReportsNoFailedSources` |
| 12 | SelectionState | Shift 点击选中 anchor 到目标之间的全部可见行（**回归 #1101**） | 已登记 a、b、c 三行可见顺序 | 点击 a 后 Shift 点击 c | `selectedPaths` 为 a、b、c，`actionTargets` 按可见顺序返回三行 | P0 | ✅ 已覆盖 | `shiftClickSelectsEveryVisibleItemInRange` |
| 13 | SelectionState | 可见行顺序重建后按新范围选择，不包含已折叠行 | 已登记 a、b、c，随后 b 折叠 | 重建为 a、c 后点击 a 并 Shift 点击 c | `selectedPaths` 仅含 a、c | P1 | ✅ 已覆盖 | `visibleOrderUpdateDropsCollapsedItems` |
| 14 | FileTreeCollectionViewController | 文件树快照会建立可见行顺序，Shift 选择覆盖整个范围（**回归 #1101**） | 临时项目含 a、b、c 三个文件 | 加载视图并设置项目根后执行 Shift 选择 | 可见顺序包含三行，选中集合与发送目标均为 a、b、c | P0 | ✅ 已覆盖 | `controllerTracksVisibleOrderForShiftSelection` |
| 15 | FileTreeCollectionViewController | Cmd 取消选中后自定义选择与发送目标只剩剩余项（**回归 #1102**） | 自定义选择为 a、b，AppKit 原生选中只剩 b | 触发 `didDeselectItemsAt` 取消 a | `selectedPaths` 只剩 b，`actionTargets` 不再包含 a | P0 | ✅ 已覆盖 | `commandDeselectRemovesPathFromSelection` |
| 16 | FileTreeCollectionViewController | 反选回调中仍处于原生选中集合的行不会被移除 | 自定义选择为 a、b，原生选中仍含 a、b | 触发 `didDeselectItemsAt` 报告 a | 自定义选择保持 a、b 不变 | P2 | ✅ 已覆盖 | `deselectCallbackKeepsRowStillSelectedNatively` |

> 说明：全部 **16 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 5 / 5
- P2: 已覆盖 3 / 3
- **合计: 16 / 16**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（5 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 16 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginProjectFileTree
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
