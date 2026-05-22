# AgentToolKit

可复用的 Agent 工具协议与运行时模型。定义 LLM 工具调用、参数解析、权限风险、取消上下文与多语言 schema，供宿主应用与插件共享。

## Package

- Product: `AgentToolKit`
- Platform: macOS 14+
- Swift tools: 6.0

## Main Types

| 类型 | 说明 |
|------|------|
| `SuperAgentTool` | Agent 工具协议（名称、描述、schema、风险、执行） |
| `LocalizedAgentTool` | 按语言包装工具描述与 input schema |
| `ToolCall` | 模型发起的工具调用（含本地授权状态） |
| `ToolArgument` | 工具参数值（字符串、数字、布尔等） |
| `ToolExecutionContext` | 单次调用的取消上下文，可转发到底层资源 |
| `CommandRiskLevel` | 命令风险等级（逻辑层；UI 扩展在 LumiUI） |
| `ToolCallAuthorizationState` | 工具调用的本地授权状态 |
| `ToolContextProviding` | 宿主提供的工具构建上下文（如语言偏好） |
| `ToolError` / `ToolExecutionError` | 工具执行错误类型 |
| `ImageAttachment` / `ToolImageResultCodec` | 工具结果中的图片附件编解码 |

## 依赖与集成

在 `Package.swift` 中添加本地依赖：

```swift
dependencies: [
    .package(path: "../AgentToolKit"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AgentToolKit"]
    ),
]
```

## 基本用法

### 实现工具

```swift
import AgentToolKit

struct ReadFileTool: SuperAgentTool {
    let name = "read_file"

    func description(for language: LanguagePreference) -> String {
        "Read the contents of a file"
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": ["path": ["type": "string"]],
            "required": ["path"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard case let .string(path)? = arguments["path"] else {
            throw ToolError.invalidArguments("path is required")
        }
        return try String(contentsOfFile: path, encoding: .utf8)
    }
}
```

### 带取消的执行

```swift
func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
    let processId = context.onCancel { terminateProcess() }
    defer { context.removeCancellationHandler(processId) }

    try context.checkCancellation()
    // ... run work ...
    return result
}
```

## Host integration

- 工具注册、权限弹窗、对话持久化留在宿主应用（如 Lumi Core / 插件）。
- 可复用的协议、模型、风险与取消语义放在本 package。
- 与 LLM API 的 `ToolCall` 类型区分时，可使用 `AgentToolKit.ToolCall` 限定名。

## Testing

From this package directory:

```sh
swift test
```
