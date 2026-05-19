# LLMProviderKit

可复用的 LLM 供应商适配层。将 OpenAI / Anthropic 兼容 API 的请求构建、响应解析与流式分片处理提取到独立的 Swift Package，供任意宿主应用或插件复用。

## Package

- Product: `LLMProviderKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 架构概览

```
┌─────────────────────────────────────────────────┐
│  Host App / Provider Plugin                     │
│  - 供应商元数据（id、模型目录、API Key 存储）      │
│  - HTTP 会话与错误映射                            │
│  - 实现 LLMToolSchemaProviding（可选）           │
└─────────────────────────────────────────────────┘
                        ↕
┌─────────────────────────────────────────────────┐
│  LLMProviderKit                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  OpenAICompatibleProviderAdapter          │  │
│  │  - buildRequest / buildRequestBody        │  │
│  │  - buildStreamingRequestBody              │  │
│  │  - parseResponse / parseStreamChunk       │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │  AnthropicCompatibleProviderAdapter       │  │
│  │  (Claude Messages API 适配)                │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │  CoreModels                               │  │
│  │  ChatMessage, ToolCall, StreamChunk...    │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## 依赖与集成

在 `Package.swift` 中添加本地或远程依赖：

```swift
dependencies: [
    .package(path: "../LLMProviderKit"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["LLMProviderKit"]
    ),
]
```

## 基本用法

### OpenAI 兼容 API

```swift
import LLMProviderKit

struct MyTool: LLMToolSchemaProviding {
    let name = "get_weather"
    let toolDescription = "Get weather for a city"
    let inputSchema: [String: Any] = [
        "type": "object",
        "properties": ["city": ["type": "string"]],
        "required": ["city"],
    ]
}

let adapter = OpenAICompatibleProviderAdapter(
    configuration: .init(
        baseURL: "https://api.example.com/v1/chat/completions",
        includeUsageInStreamOptions: true
    )
)

let url = URL(string: adapter.configuration.baseURL)!
var request = adapter.buildRequest(url: url, apiKey: "sk-...")
let messages = [
    ChatMessage(role: .user, content: "Hello"),
]
let body = try adapter.buildRequestBody(
    messages: messages,
    model: "gpt-4o",
    tools: [MyTool()],
    systemPrompt: "You are helpful."
)
request.httpBody = try JSONSerialization.data(withJSONObject: body)

let (data, _) = try await URLSession.shared.data(for: request)
let result = try adapter.parseResponse(data: data)
// result.content, result.toolCalls
```

### 流式响应

```swift
var streamRequest = adapter.buildRequest(url: url, apiKey: apiKey)
let streamBody = try adapter.buildStreamingRequestBody(
    messages: messages,
    model: "gpt-4o",
    tools: nil,
    systemPrompt: ""
)
streamRequest.httpBody = try JSONSerialization.data(withJSONObject: streamBody)

// 对每个 SSE 数据块调用 parseStreamChunk
if let chunk = try adapter.parseStreamChunk(data: sseData) {
    // chunk.content, chunk.toolCalls, chunk.isDone, chunk.inputTokens ...
}
```

### Anthropic 兼容 API

```swift
let adapter = AnthropicCompatibleProviderAdapter(
    configuration: .init(
        baseURL: "https://api.anthropic.com/v1/messages",
        apiVersion: "2023-06-01"
    )
)

var request = adapter.buildRequest(url: URL(string: adapter.configuration.baseURL)!, apiKey: apiKey)
let body = try adapter.buildRequestBody(
    messages: messages,
    model: "claude-sonnet-4-20250514",
    tools: [MyTool()],
    systemPrompt: "You are helpful."
)
request.httpBody = try JSONSerialization.data(withJSONObject: body)
```

## 核心类型

| 类型 | 说明 |
|------|------|
| `ChatMessage` | 对话消息（含 tool call / tool result / reasoning） |
| `ToolCall` | 模型发起的工具调用 |
| `StreamChunk` | 流式增量（文本、工具调用、用量、完成标记） |
| `LLMToolSchemaProviding` | 工具 schema 协议，由宿主提供具体工具定义 |
| `LLMModelCatalogItem` | 模型目录项（上下文窗口、能力标记） |

## 配置选项

### `OpenAICompatibleProviderConfiguration`

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `baseURL` | *(必填)* | API 端点 URL |
| `additionalHeaders` | `[:]` | 额外请求头（如 `HTTP-Referer`, `X-Title`） |
| `includeUsageInStreamOptions` | `false` | 流式请求是否添加 `stream_options: { include_usage: true }` |
| `returnsEmptyChunkWhenNoDelta` | `false` | 无内容增量时是否返回空 chunk |
| `acceptsFunctionScopedToolCallID` | `false` | 是否从 `function` 对象中读取 tool call ID |
| `includesReasoningContentInMessages` | `false` | 是否在 assistant 历史消息中回传 `reasoning_content` |

### `AnthropicCompatibleProviderConfiguration`

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `baseURL` | *(必填)* | Messages API 端点 URL |
| `additionalHeaders` | `[:]` | 额外请求头 |
| `apiVersion` | `"2023-06-01"` | `anthropic-version` 请求头值 |
| `defaultMaxTokens` | `8192` | 请求体默认 `max_tokens` |

## 常见供应商配置示例

| 场景 | Adapter | 典型配置 |
|------|---------|----------|
| OpenAI 官方 | OpenAI | `includeUsageInStreamOptions: true` |
| OpenRouter | OpenAI | `additionalHeaders`, `returnsEmptyChunkWhenNoDelta: true`, `acceptsFunctionScopedToolCallID: true` |
| 推理模型（reasoning_content） | OpenAI | `includesReasoningContentInMessages: true` |
| Anthropic 官方 | Anthropic | 默认 `apiVersion` |
| DashScope 等 Anthropic 兼容网关 | Anthropic | 自定义 `baseURL` 与 `additionalHeaders` |

## Testing

From this package directory:

```sh
swift test
```

Tests cover request building, response parsing, stream chunk handling, and configuration edge cases for both adapters.
