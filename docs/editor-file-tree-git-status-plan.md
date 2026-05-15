# Editor File Tree Git Status Plan

目标：在 Lumi 的编辑器文件树中实现类似 Xcode Project Navigator 的 Source Control 状态标记，在文件行右侧显示 `M`、`A`、`D`、`R`、`?` 等 Git 工作区状态，并在文件变化、Git 索引变化、项目切换时自动刷新。

## 背景

- 文件树入口：
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Views/EditorFileTreeView.swift`
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Views/EditorFileTreeNodeView.swift`
- 文件树刷新：
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Services/EditorFileTreeRefreshCoordinator.swift`
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Services/EditorFileTreeWatcher.swift`
- Git 能力：
  - `LumiApp/Plugins/AgentGitToolsPlugin/Services/GitService.swift`
  - `LumiApp/Plugins/GitPlugin/Services/GitCommitService.swift`
  - 已经通过 `LibGit2Swift` 获取 staged / unstaged diff file list。

当前文件树只监听文件系统目录变化并重载可见节点，节点视图没有 Git 状态输入，也没有 `.git` 目录或 index 变化监听。实现时应避免让每个节点各自查询 Git，Git 状态应由文件树级别的 coordinator 统一获取并通过只读映射传给节点。

## 状态定义

新增轻量模型，建议放在 `LumiApp/Plugins/EditorRailFileTreePlugin/Services/EditorFileTreeGitStatusProvider.swift`：

- `EditorFileTreeGitStatus`
  - `modified`
  - `added`
  - `deleted`
  - `renamed`
  - `untracked`
  - `staged`
  - `conflicted`
- `EditorFileTreeGitStatusEntry`
  - `path: String`，项目根目录相对路径，使用 `/` 分隔。
  - `status: EditorFileTreeGitStatus`
  - `isStaged: Bool`
- `EditorFileTreeGitStatusSnapshot`
  - `entriesByRelativePath: [String: EditorFileTreeGitStatusEntry]`
  - `directoryAggregateByRelativePath: [String: EditorFileTreeGitStatus]`
  - `repoRootPath: String`
  - `capturedAt: Date`

状态优先级建议：

1. `conflicted` 显示 `C`
2. `deleted` 显示 `D`
3. `renamed` 显示 `R`
4. `added` 或 `untracked` 显示 `A` / `?`
5. `modified` 显示 `M`
6. `staged` 可作为辅助样式，不覆盖具体变更类型

目录聚合状态用于父目录右侧标记。父目录只显示子树中最高优先级状态，例如某目录下同时有 `M` 和 `?`，显示更需要注意的那个状态。

## Git 状态获取

新增 `EditorFileTreeGitStatusProvider`：

- 输入：`projectRootPath`
- 输出：`EditorFileTreeGitStatusSnapshot`
- 实现优先使用 LibGit2Swift，而不是 shell `git status`。
- 先复用现有 `GitService.getUncommittedChanges(path:)` 或抽出更底层的 status 方法。
- 需要补齐 untracked / conflicted：
  - 如果当前 `LibGit2.getDiffFileList` 不返回 untracked 或 conflict，需要在 LibGit2Swift 能力层补方法。
  - 短期 fallback 可以用 porcelain v1 解析，但应封装在 provider 内，后续替换不影响 UI。

路径规范：

- 将 Git 返回路径规范化为相对 `repoRootPath` 的 POSIX 路径。
- 文件树节点使用 `url.path` 计算相对路径时必须走同一个 normalizer。
- 对根节点使用空字符串 `""` 作为目录 key。
- rename 状态优先记录新路径；如果 LibGit2 返回 old/new path，UI 标记应出现在新路径。

错误策略：

- 非 Git 仓库：返回空 snapshot，文件树不显示标记。
- Git 状态查询失败：保留上一份 snapshot，并记录 warning；不要阻断文件树渲染。
- projectRootPath 不存在：清空 snapshot。

## 刷新设计

在 `EditorFileTreeRefreshCoordinator` 中加入 Git 状态管理：

- 新增 `@Published private(set) var gitStatusSnapshot = EditorFileTreeGitStatusSnapshot.empty`
- `setProjectRootPath(_:)` 时：
  - 重置旧 snapshot。
  - 检测是否 Git repo。
  - 启动一次状态刷新。
  - 额外监听 Git 元数据变化。
- 文件系统变化时：
  - 保持现有 `refreshToken` 逻辑。
  - 触发一次 debounced Git status refresh。
- 手动刷新时：
  - 同时刷新文件树和 Git snapshot。

监听对象：

- 已展开目录保持现有监听。
- Git 状态还需要监听：
  - `.git/index`
  - `.git/HEAD`
  - `.git/refs/heads`
  - `.git/MERGE_HEAD`
  - `.git/rebase-merge` / `.git/rebase-apply`
- 如果 `.git` 是 worktree 文件，需要先解析其中的 `gitdir: ...` 指向真实 git dir。

防抖建议：

- 文件树内容刷新：沿用当前 300 ms。
- Git 状态刷新：150-300 ms，取消前一个任务。
- 大仓库保护：如果一次 status 超过阈值，例如 500 ms，后续刷新退避到 1-2 秒，并在日志中打点。

并发约束：

- Git status 查询在后台 task 执行。
- 只有 snapshot 赋值回到 MainActor。
- 项目切换时取消旧 task，并校验返回结果仍属于当前 `projectRootPath`。

## UI 方案

在 `EditorFileTreeView` 中把 snapshot 传给根节点：

- `gitStatusSnapshot: coordinator.gitStatusSnapshot`

在 `EditorFileTreeNodeView` 中新增参数：

- `gitStatusSnapshot: EditorFileTreeGitStatusSnapshot`

节点行右侧显示：

- 文件节点：查 `entriesByRelativePath[relativePath]`
- 目录节点：查 `directoryAggregateByRelativePath[relativePath]`
- 无状态：不显示，占位宽度可以保留 16-20 px，避免行内容跳动。

视觉样式：

- 字母标记放在 `Spacer()` 后，类似 Xcode 右侧状态列。
- 字体：`system(size: 10, weight: .semibold, design: .monospaced)`
- 颜色：
  - `M`: accent 或 warning 色
  - `A` / `?`: success 或 green
  - `D`: destructive red
  - `R`: purple/secondary accent
  - `C`: red + stronger weight
- 选中行上应保持足够对比度，必要时使用 `theme.sidebarSelectionTextColor().opacity(...)`。
- 增加 `.help(...)`：
  - `M` -> `Modified`
  - `A` -> `Added`
  - `?` -> `Untracked`
  - `D` -> `Deleted`
  - `R` -> `Renamed`
  - `C` -> `Conflict`

不要在文件名旁边插入状态文字，避免破坏文件树扫描效率；状态列应右对齐。

## 分阶段实施

### Phase 1: 模型和 Provider

- [ ] 新增 `EditorFileTreeGitStatusProvider.swift`。
- [ ] 定义 status enum、entry、snapshot。
- [ ] 实现路径 normalizer。
- [ ] 复用或封装 LibGit2Swift status 获取。
- [ ] 对非 Git 仓库返回 empty snapshot。
- [ ] 添加 provider 单元测试：
  - [ ] modified file。
  - [ ] added / untracked file。
  - [ ] deleted file。
  - [ ] staged + unstaged 同文件。
  - [ ] nested directory aggregate。

### Phase 2: Coordinator 接入

- [ ] 在 `EditorFileTreeRefreshCoordinator` 持有 snapshot。
- [ ] 项目切换时刷新 Git 状态。
- [ ] 文件系统变化时 debounced 刷新 Git 状态。
- [ ] 增加 `.git` 元数据监听。
- [ ] 处理 worktree `gitdir`。
- [ ] 确保项目切换取消旧 refresh task。

### Phase 3: UI 标记

- [ ] `EditorFileTreeView` 向根节点传入 snapshot。
- [ ] `EditorFileTreeNodeView` 接收 snapshot 并计算当前节点状态。
- [ ] 在行尾渲染固定宽度状态标记。
- [ ] 为选中、hover、深浅色主题调整颜色。
- [ ] 为状态标记添加 tooltip。

### Phase 4: 边界场景

- [ ] 删除文件：文件树里已不存在的路径通常无法显示 `D`；如果需要显示 deleted 文件，应新增虚拟节点策略，本期先不做。
- [ ] ignored 文件：不显示。
- [ ] submodule：先按普通目录处理，不递归读取子仓库状态。
- [ ] nested Git repo：先只显示当前项目根仓库状态。
- [ ] rename：只在新路径显示 `R`。
- [ ] conflict：如 LibGit2Swift 能力不足，先预留 enum 和 UI，后续补数据源。

### Phase 5: 验证

- [ ] 打开 Git 仓库，修改已跟踪文件，文件树显示 `M`。
- [ ] 新建未跟踪文件，文件树显示 `?`。
- [ ] `git add` 后标记仍显示具体变更，样式可体现 staged。
- [ ] 删除文件后父目录聚合状态有反馈，除非本期明确不展示 deleted 文件。
- [ ] 切换项目后旧项目状态不残留。
- [ ] 在非 Git 目录打开文件树，不显示任何标记且无报错。
- [ ] 通过 Xcode / 终端 / Lumi 自身修改文件，标记自动刷新。
- [ ] 大目录展开和滚动不触发每行 Git 查询。

## 风险和取舍

- `D` 状态天然对应一个当前文件系统中不存在的路径，单纯文件树无法渲染删除的文件节点。本期建议只让父目录显示聚合状态；如果要像 Source Control 面板一样显示 deleted 文件，需要把 Git status paths 合并进文件树数据源，复杂度更高。
- 当前 watcher 只监听已展开目录；Git 状态刷新不能只依赖可见目录，否则折叠目录内的变更不会反映到父级聚合状态。Provider 必须读取整个 repo 的 status snapshot。
- LibGit2Swift 现有封装可能没有完整 porcelain 状态信息。可以先扩展 LibGit2Swift 封装；shell fallback 只能作为短期兼容层。
- 每次 refresh 全量计算目录聚合，简单可靠；如果大仓库性能不足，再做增量更新。

## 建议文件变更清单

- 新增：
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Services/EditorFileTreeGitStatusProvider.swift`
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Services/EditorFileTreeGitStatusModels.swift`，如果模型较多可拆出。
- 修改：
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Services/EditorFileTreeRefreshCoordinator.swift`
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Services/EditorFileTreeWatcher.swift`，如需支持文件级 watcher 或 git metadata watcher。
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Views/EditorFileTreeView.swift`
  - `LumiApp/Plugins/EditorRailFileTreePlugin/Views/EditorFileTreeNodeView.swift`
  - `LumiApp/Plugins/AgentGitToolsPlugin/Services/GitService.swift` 或 LibGit2Swift 封装层，如需补齐 status 类型。

## 完成标准

- 文件树右侧能稳定显示 Git 状态标记。
- 状态刷新由文件树级别统一完成，节点视图不做 Git I/O。
- 非 Git 项目、项目切换、快速连续文件变化都不会造成 UI 卡顿或状态串项目。
- 关键状态和目录聚合逻辑有测试覆盖。
