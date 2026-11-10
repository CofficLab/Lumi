# TestPlan — PluginProjectFileTree

## 包概述

PluginProjectFileTree 的实现包，包含 15 个主要类型；当前测试覆盖 41 条用例。

平台: macOS 14+, iOS 17+
测试文件: 13 个，用例总数: 41

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
- **FileTreeDataSource**（2 条）：由 `collapsingParentClearsDescendantExpansion`、`targetedReloadDuringRebuildIsReplayed` 锁定；改动展开/折叠状态、展开路径持久化或重建流程时优先跑对应测试文件。折叠父目录必须清除后代展开状态；重建期间的精准刷新必须在提交后重放，不能被空树 guard 丢弃（**回归 #1103**）。
- **RefreshCoordinator**（4 条）：由 `sameRootPathReappearanceRestartsWatching`、`sameRootPathReappearanceKeepsExpandedPaths`、`emptyRootPathDoesNotStartWatching`、`fullRefreshDoesNotStallTargetedRefresh` 锁定。视图消失会调用 `stop()` 关闭 watcher；同一根路径再次出现时必须重新挂载监听（并保留展开目录），不能因路径相等直接返回（**回归 #1097**）。全量刷新与精准刷新必须各自持有防抖任务且真正响应取消，全量刷新不能把精准 trailing 窗口取消后留下永久 pending（**回归 #1099**）。
- **FileTreeNSViewBridge**（2 条）：由 `newGitStatusTokenUpdatesVisibleRows`、`repeatedGitStatusTokenDoesNotReload` 锁定。新 Git 快照令牌必须通过 `updateGitStatus` 赋值并重载可见行，不能只改属性；相同令牌不得重复重载（**回归 #1098**）。
- **FileTreeDropProcessor**（2 条）：由 `partialDropFailureReportsFailedSources`、`successfulDropReportsNoFailedSources` 锁定。单个源移动失败不能静默跳过，`.moved` 必须携带 `failedSources` 供调用方提示部分失败（**回归 #1100**）。
- **SelectionState**（2 条）：由 `shiftClickSelectsEveryVisibleItemInRange`、`visibleOrderUpdateDropsCollapsedItems` 锁定。Shift 范围选择依赖 `updateVisibleOrder` 建立的显示顺序，重建时必须丢弃已折叠/不可见行（**回归 #1101**）。
- **FileTreeCollectionViewController**（1 条）：由 `controllerTracksVisibleOrderForShiftSelection` 锁定。每次树快照变化都必须把可见文件行按顺序写入 `SelectionState`，否则 Shift 点击只能退化为单选，右键“Send to Conversation”会漏发中间文件（**回归 #1101**）。
- **FileTreeCollectionViewController（反选）**（2 条）：由 `commandDeselectRemovesPathFromSelection`、`deselectCallbackKeepsRowStillSelectedNatively` 锁定。Cmd 点击已选项必须实现 `didDeselectItemsAt` 并移除自定义路径，否则发送目标仍包含已取消文件；回调中仍在原生选中集合内的行不得移除（**回归 #1102**）。
- **FileTreeNodeItem**（3 条）：由 `samePathFileAndDirectoryHaveDistinctIdentity`、`swiftPackageMetadataChangesIdentity`、`reloadedNodeIdentityFollowsFileTypeSwap` 锁定。diffable 相等性必须包含 `isDirectory` 与图标元数据，同一路径的文件被替换成同名目录（或反向替换）时必须产出不相等的新节点，否则 cell 会继续显示旧文件类型（**回归 #1104**）。
- **FileTreeFacade（VS Code）**（5 条）：由 `nonZeroCodeStatusFallsBackToApplication`、`unlaunchableCommandFallsBackToApplication`、`successfulCodeCommandSkipsApplicationFallback`、`applicationFallbackFailureReportsFailure`、`missingCommandExitStatusIsObserved` 锁定。`/usr/bin/env code` 能启动不代表 `code` 存在，必须检查实际退出状态；非零退出或无法启动时回退到 VS Code 应用 URL，并向上报告最终失败（**回归 #1105**）。
- **GitStatusProvider（porcelain 解析）**（3 条）：由 `arrowInRegularFileNameIsPreserved`、`stagedRenameUsesDestinationPath`、`worktreeRenameUsesDestinationPath` 锁定。只有 XY 为 `R`/`C` 时 `old -> new` 才是 Git 的分隔符；普通 `??`、` M` 条目里的 ` -> ` 属于文件名，必须完整保留，否则快照键失真、文件和父目录都查不到状态（**回归 #1106**）。
- **GitStatusProvider（冲突状态）**（2 条）：由 `addAddAndDeleteDeleteAreConflicted`、`unmergedCodesAreRecognized` 锁定。未合并状态码包含 `DD`/`AU`/`UD`/`UA`/`DU`/`AA`/`UU`，不能只判断 `U`，否则 add/add 与 delete/delete 冲突会显示为普通新增/删除（**回归 #1107**）。
- **FileTreeActions**（5 条）：由 `unchangedRenameIsNoOp`、`renameKeepsLeadingAndTrailingSpaces`、`emptyRenameIsNoOp`、`creationNameTrimsSpaces`、`whitespaceOnlyCreationNameIsRejected` 锁定。命名弹窗必须返回原始输入，重命名保留合法首尾空格、确认未修改的预填名称时按 no-op 处理（不得发起真实重命名）；新建文件/目录仍裁剪首尾空格并拒绝纯空白名称（**回归 #1108**）。
- **FileTreeFacade（批量删除）**（3 条）：由 `batchTrashProcessesEveryTarget`、`batchTrashReportsPartialFailure`、`batchTrashSkipsNestedTargets` 锁定。`trashItemsReporting` 必须逐个处理顶层目标（跳过被选中目录的子路径），保留成功与失败集合，供调用方汇报部分失败（**回归 #1109**）。
- **FileTreeCollectionViewController（批量删除）**（3 条）：由 `deleteMenuCarriesEverySelectedTarget`、`performDeleteTrashesEveryTarget`、`performDeleteKeepsFailedTargetSelected` 锁定。Move to Trash 菜单必须携带 `actionTargets(for:)` 的全部目标，删除后按成功项移除选择并刷新各自父目录；部分失败时保留失败项的选择并给出警告，不能只删除右键项（**回归 #1109**）。

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
| 17 | FileTreeDataSource | 重建期间的精准刷新会在提交后重放（**回归 #1103**） | 后台遍历已读取目录 D 的旧内容并被门闩阻塞 | 向 D 新增文件并调用 `reloadDirectory(D)`，随后放行遍历 | 重建提交后重放刷新，`new.txt` 出现在列表中 | P0 | ✅ 已覆盖 | `targetedReloadDuringRebuildIsReplayed` |
| 18 | FileTreeNodeItem | 同一路径的文件与目录具有不同 diffable 身份（**回归 #1104**） | 同一 URL 分别构造 `isDirectory` 为假与真的节点 | 比较两个节点并放入集合 | 节点不相等，集合元素数为 2 | P0 | ✅ 已覆盖 | `samePathFileAndDirectoryHaveDistinctIdentity` |
| 19 | FileTreeNodeItem | Swift Package 目录元数据变化会改变节点身份 | 同一目录分别按普通目录与含 `Package.swift` 构造 | 比较两个节点 | 包目录节点与普通目录节点不相等 | P1 | ✅ 已覆盖 | `swiftPackageMetadataChangesIdentity` |
| 20 | FileTreeNodeItem | 外部替换文件类型后精准刷新会更新节点身份（**回归 #1104**） | 根目录下 `entry` 为普通文件 | 标记 `entry` 为目录并 `reloadDirectory(root)` | 节点 `isDirectory` 变为真，且与新节点不相等 | P0 | ✅ 已覆盖 | `reloadedNodeIdentityFollowsFileTypeSwap` |
| 21 | FileTreeFacade | `code` 命令非零退出时必须回退到应用打开（**回归 #1105**） | 命令退出状态为 127 | 解析打开结果 | 调用应用回退且最终成功 | P1 | ✅ 已覆盖 | `nonZeroCodeStatusFallsBackToApplication` |
| 22 | FileTreeFacade | `code` 命令无法启动时回退到应用打开 | 命令退出状态为 nil | 解析打开结果 | 调用应用回退且最终成功 | P1 | ✅ 已覆盖 | `unlaunchableCommandFallsBackToApplication` |
| 23 | FileTreeFacade | `code` 命令成功退出时不会触发应用回退 | 命令退出状态为 0 | 解析打开结果 | 返回成功且未调用应用回退 | P2 | ✅ 已覆盖 | `successfulCodeCommandSkipsApplicationFallback` |
| 24 | FileTreeFacade | 应用回退仍失败时报告打开失败（**回归 #1105**） | 命令退出状态为 127，应用回退返回 false | 解析打开结果 | 最终结果为失败 | P0 | ✅ 已覆盖 | `applicationFallbackFailureReportsFailure` |
| 25 | FileTreeFacade | 命令缺失时外部进程退出状态非零（**回归 #1105**） | 使用 `/usr/bin/env` 运行不存在的命令 | 执行并等待退出 | 退出状态非 nil 且非 0 | P0 | ✅ 已覆盖 | `missingCommandExitStatusIsObserved` |
| 26 | GitStatusProvider | 普通文件名中的箭头不会被当作重命名（**回归 #1106**） | porcelain 含 `?? Sources/a -> b.swift` 与 ` M Sources/c -> d.swift` | 解析 unstaged 条目 | 路径完整保留，状态分别为 `?` 与 `M` | P0 | ✅ 已覆盖 | `arrowInRegularFileNameIsPreserved` |
| 27 | GitStatusProvider | 暂存区重命名仍取箭头后的新路径 | porcelain 为 `R  old.swift -> new.swift` | 解析 staged 条目 | 路径为 `new.swift`，状态为 `R` | P1 | ✅ 已覆盖 | `stagedRenameUsesDestinationPath` |
| 28 | GitStatusProvider | 工作区重命名同样取箭头后的新路径 | porcelain 为 ` R old.swift -> new.swift` | 解析 unstaged 条目 | 路径为 `new.swift`，状态为 `R` | P1 | ✅ 已覆盖 | `worktreeRenameUsesDestinationPath` |
| 29 | GitStatusProvider | add/add 与 delete/delete 冲突按 conflicted 处理（**回归 #1107**） | porcelain 含 `AA`、`DD`、`UU` 三条冲突 | 解析 staged 与 unstaged 条目 | staged 三条均为 `C`，unstaged 为空，`C` 映射为 `.conflicted` | P0 | ✅ 已覆盖 | `addAddAndDeleteDeleteAreConflicted` |
| 30 | GitStatusProvider | 全部未合并状态码都被识别，普通状态不会被误判 | — | 遍历 7 个未合并码与 7 个普通码 | 未合并码全部为真，普通码全部为假 | P1 | ✅ 已覆盖 | `unmergedCodesAreRecognized` |
| 31 | FileTreeActions | 直接确认未修改的预填名称不会触发重命名（**回归 #1108**） | 输入与当前名称均为 ` draft ` | 解析重命名目标 | 返回 nil（no-op），不发起真实重命名 | P0 | ✅ 已覆盖 | `unchangedRenameIsNoOp` |
| 32 | FileTreeActions | 重命名保留合法的首尾空格（**回归 #1108**） | 输入 `  draft  `，当前名称为 `draft` | 解析重命名目标 | 返回 `  draft  `，未被裁剪 | P0 | ✅ 已覆盖 | `renameKeepsLeadingAndTrailingSpaces` |
| 33 | FileTreeActions | 清空输入不会触发重命名 | 输入为空字符串 | 解析重命名目标 | 返回 nil | P2 | ✅ 已覆盖 | `emptyRenameIsNoOp` |
| 34 | FileTreeActions | 新建文件仍裁剪首尾空格 | 输入 `  note.txt  ` | 解析新建名称 | 返回 `note.txt` | P1 | ✅ 已覆盖 | `creationNameTrimsSpaces` |
| 35 | FileTreeActions | 纯空白的新建名称被拒绝 | 输入 `   ` | 解析新建名称 | 返回 nil | P2 | ✅ 已覆盖 | `whitespaceOnlyCreationNameIsRejected` |
| 36 | FileTreeFacade | 批量删除会处理全部选中目标（**回归 #1109**） | 两个目标 URL | 执行 `trashItemsReporting` | 两个目标都进入删除回调，全部记为成功 | P0 | ✅ 已覆盖 | `batchTrashProcessesEveryTarget` |
| 37 | FileTreeFacade | 批量删除会保留失败项用于部分失败汇报（**回归 #1109**） | 两个目标中第二个删除失败 | 执行 `trashItemsReporting` | 成功项与失败项分别返回，`hasPartialFailure` 为真 | P0 | ✅ 已覆盖 | `batchTrashReportsPartialFailure` |
| 38 | FileTreeFacade | 批量删除会跳过被选中目录的子路径 | 同时选中目录与目录内文件 | 执行 `trashItemsReporting` | 只对目录调用删除，总数按顶层目标计 | P2 | ✅ 已覆盖 | `batchTrashSkipsNestedTargets` |
| 39 | FileTreeCollectionViewController | 多选时 Move to Trash 菜单携带全部选中项（**回归 #1109**） | 已 Cmd 选中 a.txt、b.txt | 构建 a.txt 的右键菜单 | 删除项 `representedObject` 为两项数组 | P0 | ✅ 已覆盖 | `deleteMenuCarriesEverySelectedTarget` |
| 40 | FileTreeCollectionViewController | 多选删除会移除全部目标的选择（**回归 #1109**） | 已选中 a.txt、b.txt | `performDelete` 处理全部目标 | 删除器收到两项，选择清空，成功提示 | P0 | ✅ 已覆盖 | `performDeleteTrashesEveryTarget` |
| 41 | FileTreeCollectionViewController | 部分失败时保留失败项的选择并给出警告 | 删除器只成功 a.txt、失败 b.txt | `performDelete` 处理全部目标 | 选择只剩 b.txt，提示为 warning 且包含 b.txt | P1 | ✅ 已覆盖 | `performDeleteKeepsFailedTargetSelected` |

> 说明：全部 **41 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 21 / 21
- P1: 已覆盖 13 / 13
- P2: 已覆盖 7 / 7
- **合计: 41 / 41**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（21 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 41 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
