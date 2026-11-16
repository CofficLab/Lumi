# TestPlan — PluginGitChatToolbar

## 包概述

PluginGitChatToolbar 的实现包：标题栏 Git Chat 弹层的数据来源与视图。当前测试覆盖 18 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 18

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `GitChatCapability`
- `GitChatCapabilityAdapter`
- `GitChatProjectCapability`
- `GitChatObserver`
- `GitChatToolbarPlugin`
- `GitChatToolbarViewModel`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **GitChatToolbarViewModel**（8 条）：由 `gitProjectLoadsStatusAndCommits`、`selectCommitLoadsChanges`、`reloadAllDebounceCoalesces` 等锁定状态/提交合成、选中加载与 1 秒去抖；无项目能力时点击文件不得崩溃。
- **GitChatObserver**（2 条）：由 `projectChangeTriggersReload`、`watchEventTriggersReload` 锁定项目切换与仓库 watch 事件触发重载。
- **GitChatWorkingChangesCache**（5 条，#1300）：由 `cacheMatchesStatusSynthesis`、`changesAreSortedByPath`、`cacheClearedOnProjectSwitch` 等锁定变更项缓存与 status 合成一致、按路径排序、切换/停 watch 后清空。
- **GitChatErrorVisibility**（3 条，**回归 #390**）：由 `statusReadErrorStaysVisibleWithCommits`、`commitDiffErrorStaysVisible`、`cleanStateDoesNotShowErrorBanner` 锁定错误可见性；部分读取失败（status 失败但 commits 成功、commit diff 失败）必须始终展示错误横幅，不得被「工作区干净 / 0 文件」等正常空态掩盖，正常干净态不得误报错误。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | GitChatToolbarViewModel | 非 Git 项目：isGitRepository 为 false，无数据 | InMemory provider 未标记该路径为仓库 | updateProjectPath 后等待加载 | isGitRepository 为 false，commits/workingChanges 为空 | P1 | ✅ 已覆盖 | `nonGitProjectShowsNoData` |
| 2 | GitChatToolbarViewModel | Git 项目：status + commits + workingChanges 合成正确 | 仓库已设置 status 与 commits | updateProjectPath 后等待加载 | 提交数正确，变更项含 modified/added/untracked 且状态枚举正确 | P1 | ✅ 已覆盖 | `gitProjectLoadsStatusAndCommits` |
| 3 | GitChatToolbarViewModel | 选中 commit 加载其变更文件 | 仓库已设置 commit 的变更文件 | selectCommit 后等待加载，再 clearCommitSelection | 选中变更文件正确，清除后选中态与变更清空 | P1 | ✅ 已覆盖 | `selectCommitLoadsChanges` |
| 4 | GitChatToolbarViewModel | reloadAll 去抖：多次调用只产生一次实际加载 | 仓库已设置 status | 快速连发 3 次 reloadAll，等待去抖触发 | 只产生一次加载，变更项数正确 | P1 | ✅ 已覆盖 | `reloadAllDebounceCoalesces` |
| 5 | GitChatToolbarViewModel | 分支名与仓库路径派生自工作区状态 | status.branch 为 dev | updateProjectPath 后等待加载 | branchName 为 dev，repositoryPath 为项目路径 | P1 | ✅ 已覆盖 | `branchAndRepositoryPathDerived` |
| 6 | GitChatToolbarViewModel | 分支名为空时回退到 HEAD | status.branch 为空白 | updateProjectPath 后等待加载 | branchName 回退为 HEAD | P1 | ✅ 已覆盖 | `emptyBranchFallsBackToHEAD` |
| 7 | GitChatToolbarViewModel | 点击工作区文件：以预览方式交给项目能力 | 注入记录用项目能力 | previewWorkingChange | 项目能力收到仓库路径与相对路径 | P1 | ✅ 已覆盖 | `previewWorkingChangeDelegatesToProjectCapability` |
| 8 | GitChatToolbarViewModel | 无项目能力时点击文件不崩溃 | 未注入项目能力 | previewWorkingChange | 不崩溃，状态不变 | P0 | ✅ 已覆盖 | `previewWorkingChangeWithoutProjectCapability` |
| 9 | GitChatObserver | 项目切换触发 ViewModel 重载 | 两个仓库均已设置 status | updateProjectPath 切到第二个仓库 | projectPath 更新，加载第二个仓库的变更 | P1 | ✅ 已覆盖 | `projectChangeTriggersReload` |
| 10 | GitChatObserver | GitRepositoryWatching 事件触发重载 | watch 已启动 | 更新 status 后广播 workingTreeChanged，等待去抖 | 变更项数更新为新 status | P1 | ✅ 已覆盖 | `watchEventTriggersReload` |
| 11 | GitChatWorkingChangesCache | 未加载时变更项为空 | capability 为 nil | 读取 workingChanges/workingChangeCount | 均为空/0 | P2 | ✅ 已覆盖 | `emptyBeforeLoad` |
| 12 | GitChatWorkingChangesCache | 缓存的变更项与 status 合成结果一致 | 仓库已设置 status | updateProjectPath 后等待加载 | 缓存变更项路径与 status.workingChanges() 一致 | P1 | ✅ 已覆盖 | `cacheMatchesStatusSynthesis` |
| 13 | GitChatWorkingChangesCache | 变更项按路径排序 | status 含乱序路径 | updateProjectPath 后等待加载 | 变更项按路径升序 | P1 | ✅ 已覆盖 | `changesAreSortedByPath` |
| 14 | GitChatWorkingChangesCache | 项目切换后缓存被清空 | 先加载 Git 仓库再切到非 Git 项目 | updateProjectPath 切换 | 缓存清空，不残留上一仓库数据 | P1 | ✅ 已覆盖 | `cacheClearedOnProjectSwitch` |
| 15 | GitChatWorkingChangesCache | watch 停止后缓存被清空 | 仓库已加载 | resetForMissingWatch | 缓存清空 | P1 | ✅ 已覆盖 | `cacheClearedWhenWatchMissing` |
| 16 | GitChatErrorVisibility | status 读取失败时即使有提交也必须展示错误（**回归 #390**） | 只设置 commits 不设置 status | updateProjectPath 后等待加载 | errorMessage 非空、0 变更、提交非空，shouldShowErrorBanner 为真 | P0 | ✅ 已覆盖 | `statusReadErrorStaysVisibleWithCommits` |
| 17 | GitChatErrorVisibility | commit diff 读取失败必须展示错误而非 0 文件（**回归 #390**） | 设置 status/commits 但不设置该 commit 变更 | selectCommit 后等待加载 | 选中变更为空、errorMessage 非空，shouldShowErrorBanner 为真 | P0 | ✅ 已覆盖 | `commitDiffErrorStaysVisible` |
| 18 | GitChatErrorVisibility | 工作区干净且无错误时不展示错误横幅 | status 成功且 0 变更、commits 成功 | updateProjectPath 后等待加载 | errorMessage 为 nil，shouldShowErrorBanner 为假 | P1 | ✅ 已覆盖 | `cleanStateDoesNotShowErrorBanner` |

> 说明：全部 **18 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 14 / 14
- P2: 已覆盖 1 / 1
- **合计: 18 / 18**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 18 条用例位于 `Tests/PluginGitChatToolbarTests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginGitChatToolbar
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」