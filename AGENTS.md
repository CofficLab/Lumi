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
