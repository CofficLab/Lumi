# LLMProviderKit

可复用的 LLM 供应商适配层。将多个 OpenAI / Anthropic 兼容供应商的重复逻辑提取到独立的 Swift Package，避免每个 Provider 插件中维护相同的请求构建和响应解析代码。

---

## 架构概览

```
┌─────────────────────────────────────────────────┐
│  LumiApp (Main Target)                          │
│  ┌───────────────────────────────────────────┐  │
│  │  SuperLLMProvider Protocol                │  │
│  │  - buildRequest / buildRequestBody        │  │
│  │  - parseResponse / parseStreamChunk       │  │
│  └───────────────────────────────────────────┘  │
│  ↕                                              │
│  ┌───────────────────────────────────────────┐  │
│  │  LLMProviderKitBridge.swift               │  │
│  │  - SuperAgentToolBridge (→ LLMToolSchema) │  │
│  │  - ChatMessage / ToolCall / StreamChunk   │  │
│  │    App ↔ Kit 类型转换                      │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                        ↕
┌─────────────────────────────────────────────────┐
│  LLMProviderKit (Swift Package)                 │
│  ┌───────────────────────────────────────────┐  │
│  │  OpenAICompatibleProviderAdapter          │  │
│  │  - buildRequest / buildRequestBody        │  │
│  │  - buildStreamingRequestBody              │  │
│  │  - parseResponse / parseStreamChunk       │  │
│  │  - transformMessage / formatTool          │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │  AnthropicCompatibleProviderAdapter       │  │
│  │  (Claude API 适配)                         │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │  CoreModels                               │  │
│  │  ChatMessage, ToolCall, StreamChunk...    │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## 新增 OpenAI 兼容供应商

1. 在 `LumiApp/Plugins/` 下创建新目录 `LLMProviderYourName/`
2. 创建 Provider 文件（参考下面的模板）
3. 创建 Plugin 文件注册供应商
4. 在 Xcode 中将文件添加到 Lumi target

### 最小 Provider模板

```swift
import Foundation
import LLMProviderKit
import MagicKit

/// YourName API 供应商实现
///
/// 完全兼容 OpenAI 格式
final class YourNameProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "🔷"

    // MARK: - 基础信息

    static let id = "yourname"
    static let displayName = String(localized: "YourName", table: "YourName")
    static let description = String(localized: "LLM by YourName", table: "YourName")
    static let websiteURL: String? = "https://yourname.com"

    // MARK: - 配置

    static let apiKeyStorageKey = "DevAssistant_ApiKey_YourName"
    static let defaultModel = "your-model-id"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "your-model-id", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
    ]

    static let isEnabled = true

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.yourname.com/v1/chat/completions",
            includeUsageInStreamOptions: true   // 如果你的 API 支持 usage 信息
        )
    )

    override init() { super.init() }

    var baseURL: String { adapter.configuration.baseURL }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: apiKey)
    }

    func buildRequestBody(messages: [ChatMessage], model: String, tools: [SuperAgentTool]?, systemPrompt: String) throws -> [String: Any] {
        let kitMessages = messages.map { LLMProviderKit.ChatMessage(app: $0) }
        let kitTools = tools?.map { SuperAgentToolBridge(tool: $0) }
        return try adapter.buildRequestBody(messages: kitMessages, model: model, tools: kitTools, systemPrompt: systemPrompt)
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        let result = try adapter.parseResponse(data: data)
        let kitToolCalls = result.toolCalls?.map { ToolCall(kit: $0) }
        return (result.content, kitToolCalls)
    }

    func buildStreamingRequestBody(messages: [ChatMessage], model: String, tools: [SuperAgentTool]?, systemPrompt: String) throws -> [String: Any] {
        let kitMessages = messages.map { LLMProviderKit.ChatMessage(app: $0) }
        let kitTools = tools?.map { SuperAgentToolBridge(tool: $0) }
        return try adapter.buildStreamingRequestBody(messages: kitMessages, model: model, tools: kitTools, systemPrompt: systemPrompt)
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let kitChunk = try adapter.parseStreamChunk(data: data) else { return nil }
        return StreamChunk(kit: kitChunk)
    }
}
```

### 配置选项

`OpenAICompatibleProviderConfiguration` 支持以下选项：

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `baseURL` | *(必填)* | API 端点 URL |
| `additionalHeaders` | `[:]` | 额外请求头（如 `HTTP-Referer`, `X-Title`） |
| `includeUsageInStreamOptions` | `false` | 流式请求是否添加 `stream_options: { include_usage: true }` |
| `returnsEmptyChunkWhenNoDelta` | `false` | 无内容增量时是否返回空 chunk（某些供应商需要） |
| `acceptsFunctionScopedToolCallID` | `false` | 是否从 `function` 对象中读取 tool call ID |
| `includesReasoningContentInMessages` | `false` | 是否在 assistant 历史消息中回传 `reasoning_content` |

### 已有供应商

| 供应商 | 类型 | baseURL | 特殊配置 |
|--------|------|---------|----------|
| OpenAI | OpenAI兼容 | api.openai.com | `includeUsageInStreamOptions: true` |
| DeepSeek | OpenAI兼容 | api.deepseek.com | — |
| OpenRouter | OpenAI兼容 | openrouter.ai | `additionalHeaders`, `returnsEmptyChunkWhenNoDelta: true`, `acceptsFunctionScopedToolCallID: true` |
| AiRouter | OpenAI兼容 | api.airouter.org | `includeUsageInStreamOptions: true` |
| FreeModel | OpenAI兼容 | api.freemodel.dev | `includeUsageInStreamOptions: true` |
| Feifeimiao | OpenAI兼容 | api.feifeimiao.top | `includeUsageInStreamOptions: true` |
| FlyMux | OpenAI兼容 | api.flymux.com | `includeUsageInStreamOptions: true` |
| HyperAPI | OpenAI兼容 | hyperapi.cc | `includeUsageInStreamOptions: true` |
| MegaLLM | OpenAI兼容 | ai.megallm.io | — |
| Xiaomi | OpenAI兼容 | token-plan-cn.xiaomimimo.com | `includesReasoningContentInMessages: true` |
| Xybbz | OpenAI兼容 | sub2api.xybbz.xyz | `includeUsageInStreamOptions: true` |
| Anthropic | Anthropic兼容 | api.anthropic.com | 使用 `AnthropicCompatibleProviderAdapter` |
| Zhipu | OpenAI兼容 | open.bigmodel.cn | 尚未迁移 |
| Aliyun | OpenAI兼容 | dashscope.aliyuncs.com | 尚未迁移 |
