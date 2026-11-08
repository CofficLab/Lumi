# 仓库约定（Agent / 开发者）

## 工具参数中的数字

工具（Agent 调用）参数里的整数必须走带范围的解析，禁止把原始数字直接交给对负数或越界敏感的 API。

- **解析入口**：统一使用 `ToolArgumentNumber`、`toolInt(...)`、`optionalInt(...)` 这类带范围的解析，不要直接 `as? Int` 后使用。
- **危险 API**：`suffix`、`prefix`、`reserveCapacity`、数组/字符串下标、`Array(repeating:count:)`、`dropFirst`/`dropLast`、`Range` 构造、`UInt32`/`UInt16`/`UInt8` 转换，以及 `pageSize + 1` 这类加减后再使用的路径。
- **校验策略**：在入口处校验范围。Debug 下用 `assert` 暴露调用方错误；Release 下用 `max(1, min(上限, value))` 钳制保命。不要用「返回空结果」静默吞掉非法参数。
- **schema 同步**：工具的 `inputSchema` 必须声明与代码一致的 `minimum` / `maximum`。
- **对照**：
  - 错误：`items.suffix(limit)`
  - 正确：入口 `assert((1...200).contains(limit))`，使用 `items.suffix(max(1, min(200, limit)))`

适用范围：`Packages/` 下所有 `SuperAgentTool`，以及它们直接调用、可能接收工具参数的 service 入口。

## 工具失败必须抛出

工具失败不能用返回字符串表达（如 `return "Error: ..."`、`return "失败：..."`、`return "Missing ..."`）。`SuperAgentTool.execute` 返回的字符串会被包装成 `isError == false` 的成功结果，模型无法据此判断失败。

- **正确做法**：`throw ToolExecutionError.executionFailed(toolName: name, reason: "...")`，由 `ToolExecutionManager` 统一标记 `isError`。
- **catch 透传**：在 `catch` 中先 `catch let error as ToolExecutionError { throw error }`，避免把已抛出的工具错误二次包装成普通文案。
- **例外**：`Error` 的 `errorDescription` / `failureReason` 等本地化实现可以返回字符串；真正的空结果文案（如 `No projects found.`、`暂无记录`）也可以返回字符串。
- **闸门**：`python3 Scripts/check-tool-failure-strings.py` 扫描全部工具源码，发现 `return` 失败字面量会输出 `文件:行号` 并以非 0 退出。CI 见 `.github/workflows/tool-failure-strings.yml`。

适用范围：`Packages/` 下所有 `SuperAgentTool` 的 `execute` / `executeResult` 实现。

## 异步写回共享状态必须带身份校验

`Task` / `async` 方法在 `await` 之后写 ViewModel 或 service 的共享状态前，必须确认自己仍属于当前上下文（当前账号、项目、连接、会话、选中条目等）。只捕获一次值、等待结束后直接赋值，会让旧请求的结果覆盖用户刚切换后的新状态，表现为「显示了上一个项目/连接/会话的数据」。

- **统一形态**：`捕获身份 → await → 写回前比对`。身份可以是 `accountID + folder`、`projectPath`、`configID`、`imageID`、`selectionGeneration`、`logGeneration` 等；比较失败就直接 `return`，不要写任何状态，也不要补写错误文案。
- **错误分支同样要校验**：`catch` 里写 `errorMessage` 之前也要比对身份，否则旧请求的失败会覆盖新上下文。
- **列表翻页**：捕获列表标识与条数（或代次），写回前确认列表仍属于同一轮加载，否则丢弃该页，不要 `append`。
- **加载标记**：`isLoading` / `isSyncing` 这类标记不要与「数据写回」共用同一个布尔值。多个操作重叠时用计数（`beginLoading()` / `endLoading()` + `defer`），或拆成 `isLoading` 与 `isLoadingMore`，避免新任务一开始就被旧任务的收尾关掉转圈。
- **反例**：
  ```swift
  let configID = selectedConfig?.id
  let rows = try await fetchRows(configID)
  sqliteTables = rows        // await 期间可能已切库，旧结果覆盖新库
  ```
- **正确**：
  ```swift
  let configID = selectedConfig?.id
  let rows = try await fetchRows(configID)
  guard selectedConfig?.id == configID else { return }
  sqliteTables = rows
  ```
- **回归测试**：每个修复点至少有一个测试用延迟/门闩构造「旧请求晚到」，断言新状态不被覆盖；只测最终成功路径不算覆盖此约定。

适用范围：`Packages/` 下所有 `Task` / `async` 方法中在 `await` 后写 `@Published`、`private(set) var` 或共享 service 状态的位置。

## 迁移到新工作副本后的完整性核查

把仓库复制到新磁盘/新路径后，不要直接开工。先确认副本是「可用的仓库」，而不是一堆文件。复制过程可能丢对象、丢引用，或把工作区停留在旧提交上。

1. **先看仓库能不能读**
   - `git status` 能正常输出，且不出现 `bad object HEAD` / `fatal: not a git repository`。
   - `git rev-parse HEAD` 与 `git cat-file -t <HEAD>` 都能找到对象；`git log -1` 能打印提交。对象缺失时先 `git fetch origin`，通常能补齐。
2. **与 origin 对齐，量化差距**
   - `git fetch origin`，然后 `git rev-list --count HEAD..origin/dev` 看落后多少提交。
   - 落后数量与预期不符（例如刚提交过却落后几十条），说明副本是旧快照，不能当基线。
   - `git remote -v` 确认远端指向真实仓库，而不是旧路径或本地目录。
3. **判定工作区未提交改动的归属**（关键，不要一上来就 reset）
   - `git status --short` 列出改动，再逐文件与旧副本的 HEAD 版本比对：`diff -q <新副本文件> <旧副本文件>`。
   - 内容与旧副本 HEAD 一致 → 这些「改动」只是旧快照差异，可安全丢弃；内容有旧副本没有的东西 → 先 `git stash push -u -m "<日期>-pre-sync"` 保留，再对齐。
   - 旧副本里未提交的改动也要单独判断：先确认它是否已作为提交存在于新副本的 origin 历史中，再决定搬运还是丢弃。
4. **对齐方式**
   - 新副本没有本地独有提交时，优先 `git merge --ff-only origin/dev`；工作区有会冲突的改动就先 stash。
   - 不要在未确认改动归属前执行 `git reset --hard` / `git checkout -- .`。
5. **收尾确认**：`git status` 干净或只剩明确无关的改动，`git rev-parse HEAD` 与 `origin/dev` 一致，再开始编译与提交。外接卷上构建较慢时，先怀疑 I/O 或锁文件，不要误判为代码错误。

## 多会话并发提交

多个会话可能同时在同一仓库提交。暂存区是仓库级共享状态，`git commit` 会带走当时暂存的一切，别人的改动很容易被卷进自己的提交。

- **提交前核对暂存区**：先 `git diff --cached --name-only`，确认只有本次改动涉及的文件。发现他人的文件被暂存，用 `git restore --staged <path>` 退回暂存后再提交，不要连同提交。
- **禁止全量暂存**：不用 `git commit -a`、`git add -A`、`git add .`，只按明确路径暂存（`git add <path>`）。
- **提交前看工作区**：先 `git status`，确认是否有其他会话正在进行的改动；若有，在提交信息或汇报中写明本次提交涉及的文件范围，便于事后核对归属。
- **推送前先 fetch**：`git fetch` 后只推自己的提交范围；若远端已包含自己的提交（被判为「已在远端」），不要重复推送，也不要为了「推自己的」去 rebase 掉别人的提交。

适用范围：所有在该仓库执行 git 暂存、提交与推送的会话，包括自动化脚本。
