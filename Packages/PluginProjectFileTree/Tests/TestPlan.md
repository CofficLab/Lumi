# TestPlan — PluginProjectFileTree

## 包概述

PluginProjectFileTree 的实现包，包含 15 个主要类型；当前测试覆盖 8 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 8

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
- **RefreshCoordinator**（3 条）：由 `sameRootPathReappearanceRestartsWatching`、`sameRootPathReappearanceKeepsExpandedPaths`、`emptyRootPathDoesNotStartWatching` 锁定。视图消失会调用 `stop()` 关闭 watcher；同一根路径再次出现时必须重新挂载监听（并保留展开目录），不能因路径相等直接返回（**回归 #1097**）。
- **FileTreeNSViewBridge**（2 条）：由 `newGitStatusTokenUpdatesVisibleRows`、`repeatedGitStatusTokenDoesNotReload` 锁定。新 Git 快照令牌必须通过 `updateGitStatus` 赋值并重载可见行，不能只改属性；相同令牌不得重复重载（**回归 #1098**）。

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

> 说明：全部 **8 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 3 / 3
- P2: 已覆盖 2 / 2
- **合计: 8 / 8**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（3 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 8 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
