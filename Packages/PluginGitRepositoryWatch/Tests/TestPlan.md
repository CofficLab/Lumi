# TestPlan — PluginGitRepositoryWatch

## 包概述

PluginGitRepositoryWatch 的实现包，包含 5 个主要类型；当前测试覆盖 32 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 32

核心组件（源码目录）:
- `Providers/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `GitDirectorySnapshot`
- `GitDirectoryWatcher`
- `GitRepositoryWatchPlugin`
- `WorkingTreeWatcher`
- `GitRepositoryWatchProvider`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（2 条）：由 `nonGitDirectoryIsIgnored`、`pluginRegistersProvider` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Git目录解析**（7 条）：由 `resolvesGitDirectory`、`resolvesAbsoluteGitFile`、`picksGitDirLineFromMultiLineFile` 等用例锁定。
- **Git目录快照**（9 条）：由 `readsDirectHeadHash`、`fallsBackToPackedRefs`、`readsFullSnapshot` 等用例锁定。
- **Git仓库监听Provider**（9 条）：由 `startsWatchingRepository`、`broadcastsStopped`、`cancelledObserverStopsReceiving` 等用例锁定。
- **HEAD符号引用**（5 条）：由 `snapshotDistinguishesBranchesAtSameCommit`、`broadcastsHeadChangedOnBranchSwitchAtSameCommit`、`readHeadRefReturnsSymbolicTarget` 等用例锁定。
- **订阅令牌生命周期**：Provider 弱引用持有订阅令牌，释放令牌即注销（下次广播清理失效注册）；面板销毁后不得残留回调（#921）。
- **仓库根向上发现**：项目路径位于仓库子目录时，解析器须与 git 一致向上查找最近的 `.git`；遇到存在但格式非法的 `.git` 立即报错，不越过该仓库边界（#913）。
- **进程内工作区写入**：工作区 FSEventStream 不得设置 `IgnoreSelf`；内置编辑器保存、Agent 工具写文件都在同一进程内，过滤自身事件会让已打开的 Changes 停在旧状态（#911）。
- **HEAD 符号引用**：快照须保留 HEAD 的符号引用（`headRef`），不能只比解析后的 commit hash；同 commit 切换分支时 hash/index/refs 均不变，唯有符号引用变化，须据此广播 `.headChanged` 刷新工具栏（#213）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | non-git directory does not leave an active watcher | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonGitDirectoryIsIgnored` |
| 2 | 综合 | watch plugin registers the reusable provider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersProvider` |
| 3 | Git目录解析 | .git 是目录时直接返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesGitDirectory` |
| 4 | Git目录解析 | .git 指向绝对路径时原样返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesAbsoluteGitFile` |
| 5 | Git目录解析 | .git 指向相对路径时相对项目目录解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesRelativeGitFile` |
| 6 | Git目录解析 | .git 文件多行时取含 gitdir: 的那一行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `picksGitDirLineFromMultiLineFile` |
| 7 | Git目录解析 | .git 不存在时抛出未找到错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsWhenGitDirectoryMissing` |
| 8 | Git目录解析 | .git 文件缺少 gitdir: 行时抛出非法文件错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsWhenGitFileInvalid` |
| 9 | Git目录快照 | HEAD 是直接 hash 时返回该 hash | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsDirectHeadHash` |
| 10 | Git目录快照 | HEAD 指向 ref 时读取对应 ref 文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsHeadRef` |
| 11 | Git目录快照 | ref 文件缺失时回退到 packed-refs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToPackedRefs` |
| 12 | Git目录快照 | packed-refs 中也没有该 ref 时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWhenRefMissingEverywhere` |
| 13 | Git目录快照 | HEAD 文件缺失时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWhenHeadMissing` |
| 14 | Git目录快照 | 内容指纹对相同内容稳定、对不同内容不同 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fingerprintIsStableAndContentSensitive` |
| 15 | Git目录快照 | 文件不存在时指纹为 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fingerprintOfMissingFileIsNil` |
| 16 | Git目录快照 | 快照同时汇总 head / index / stash / refs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsFullSnapshot` |
| 17 | Git目录快照 | 空仓库的快照四项均为 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyRepositorySnapshotIsAllNil` |
| 18 | Git仓库监听Provider | 监听真实仓库时广播 started 且监听器就绪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startsWatchingRepository` |
| 19 | Git仓库监听Provider | 监听非仓库目录时不广播 started | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresNonRepository` |
| 20 | Git仓库监听Provider | 停止监听时广播 stopped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `broadcastsStopped` |
| 21 | Git仓库监听Provider | 重复监听同一目录是幂等的 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repeatedStartIsIdempotent` |
| 22 | Git仓库监听Provider | 注销观察者后不再收到事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledObserverStopsReceiving` |
| 23 | Git仓库监听Provider | 未监听就停止是安全的 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stopWithoutStartIsSafe` |
| 24 | Git仓库监听Provider | 释放订阅令牌后不再收到事件（回归 #921） | — | 释放令牌后启动/停止监听 | 观察者收不到任何广播 | P1 | ✅ 已覆盖 | `releasedObserverHandleStopsReceiving` |
| 25 | Git目录解析 | 项目目录是仓库子目录时向上找到仓库根的 .git（回归 #913） | 项目目录含嵌套子目录 | 以子目录为项目路径解析 | 返回仓库根的 `.git` | P1 | ✅ 已覆盖 | `resolvesAncestorGitDirectory` |
| 26 | Git仓库监听Provider | 项目路径是仓库子目录时正常监听并广播 started（回归 #913） | 项目目录含嵌套子目录 | 以子目录启动监听 | 监听器就绪且广播一次 started | P1 | ✅ 已覆盖 | `startsWatchingFromNestedProjectDirectory` |
| 27 | Git仓库监听Provider | 进程内写入工作区也会广播 workingTreeChanged（回归 #911） | 真实仓库，Provider 已启动监听 | 由测试进程（与编辑器保存同一进程）写入文件 | 节流与防抖后收到 `.workingTreeChanged` | P1 | ✅ 已覆盖 | `reportsInProcessWorkingTreeWrites` |
| 28 | HEAD符号引用 | 同一 commit 的两个分支：切换 HEAD 后快照必须不同（回归 #213） | 两分支 ref 指向同一 hash | 改写 HEAD 符号引用后重读快照 | hash 相同但快照不相等 | P0 | ✅ 已覆盖 | `snapshotDistinguishesBranchesAtSameCommit` |
| 29 | HEAD符号引用 | 进程内切换同 commit 分支也会广播 headChanged（回归 #213） | 真实仓库，Provider 已启动监听 | 由测试进程改写 HEAD 符号引用 | 防抖后收到 `.headChanged` | P0 | ✅ 已覆盖 | `broadcastsHeadChangedOnBranchSwitchAtSameCommit` |
| 30 | HEAD符号引用 | 符号 HEAD 返回 ref 目标 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readHeadRefReturnsSymbolicTarget` |
| 31 | HEAD符号引用 | detached HEAD 返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readHeadRefIsNilForDetachedHead` |
| 32 | HEAD符号引用 | HEAD 缺失时符号引用为 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `readHeadRefIsNilWhenHeadMissing` |

> 说明：全部 **32 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 25 / 25
- P2: 已覆盖 5 / 5
- **合计: 32 / 32**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（25 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 32 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginGitRepositoryWatch
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
