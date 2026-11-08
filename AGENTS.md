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
