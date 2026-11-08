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
