# LLM Provider Kit Plan

目标：将多个 LLM 供应商插件中重复的 OpenAI-compatible 请求构造、消息转换、工具格式化、响应解析和 SSE 流解析逻辑提取到 `Packages` 下的独立 Swift Package，让供应商插件只保留自身 metadata、模型目录、base URL、headers 和少量协议差异。

## 背景

当前供应商插件中存在大量结构相同或高度相似的代码，典型文件包括：

- `LumiApp/Plugins/LLMProviderOpenAI/OpenAIProvider.swift`
- `LumiApp/Plugins/LLMProviderDeepSeek/DeepSeekProvider.swift`
- `LumiApp/Plugins/LLMProviderOpenRouter/OpenRouterProvider.swift`
- `LumiApp/Plugins/LLMProviderAiRouter/AiRouterProvider.swift`
- `LumiApp/Plugins/LLMProviderFreeModel/FreeModelProvider.swift`
- `LumiApp/Plugins/LLMProviderFeifeimiao/FeifeimiaoProvider.swift`
- `LumiApp/Plugins/LLMProviderFlyMux/FlyMuxProvider.swift`
- `LumiApp/Plugins/LLMProviderHyperAPI/HyperAPIProvider.swift`
- `LumiApp/Plugins/LLMProviderMegaLLM/MegaLLMProvider.swift`
- `LumiApp/Plugins/LLMProviderXiaomi/XiaomiProvider.swift`
- `LumiApp/Plugins/LLMProviderXybbz/XybbzProvider.swift`

重复点主要集中在：

- `buildRequest(url:apiKey:)`
- `buildRequestBody(messages:model:tools:systemPrompt:)`
- `buildStreamingRequestBody(messages:model:tools:systemPrompt:)`
- `parseResponse(data:)`
- `parseStreamChunk(data:)`
- `transformMessage(_:)`
- `formatTool(_:)`
- OpenAI-compatible response DTO，例如 `choices.message.tool_calls`

这些逻辑属于协议适配层，不应该分散在每个供应商插件内。抽成 package 后，新增兼容供应商时只需要声明配置和模型列表，减少复制粘贴带来的解析差异和修复遗漏。

## 设计原则

- 公共 package 不依赖 App target。
- Provider 插件保留供应商身份、模型目录、base URL、额外 headers 和特例配置。
- 先覆盖 OpenAI-compatible 供应商，不强行统一 Anthropic、Aliyun、Zhipu、MLX 等差异较大的实现。
- 抽象以可测试的纯逻辑为核心，避免在 package 内引入 UI、Keychain、插件注册等 App 运行时依赖。
- 迁移应分阶段完成，每个阶段都能编译和测试。

## 包结构

新增 package：

- `Packages/LLMProviderKit/Package.swift`
- `Packages/LLMProviderKit/Sources/LLMProviderKit`
- `Packages/LLMProviderKit/Tests/LLMProviderKitTests`

建议模块划分：

- `LLMProviderCoreModels.swift`
  - `LLMModelCapabilities`
  - `LLMModelSpec`
  - `LLMModelCatalogItem`
  - 如果选择完整下沉核心类型，也包含 `ChatMessage`、`ToolCall`、`StreamChunk`、`StreamEventType`
- `OpenAICompatibleProviderConfiguration.swift`
  - `baseURL`
  - `additionalHeaders`
  - `includeUsageInStreamOptions`
  - `emptyStreamChunkFallback`
  - `toolCallIDStrategy`
- `OpenAICompatibleRequestBuilder.swift`
  - request headers
  - non-stream request body
  - stream request body
- `OpenAICompatibleMessageTransformer.swift`
  - `ChatMessage` 到 OpenAI-compatible message dictionary
  - tool result message
  - assistant tool calls
- `OpenAICompatibleToolFormatter.swift`
  - `SuperAgentTool` 到 function tool schema
- `OpenAICompatibleResponseModels.swift`
  - 通用 `choices/message/tool_calls/function` DTO
- `OpenAICompatibleResponseParser.swift`
  - 普通 JSON 响应解析
- `OpenAICompatibleStreamParser.swift`
  - SSE `data:` 解析
  - `[DONE]`
  - text delta
  - tool call delta
  - usage
  - error

## 模块边界方案

当前 `SuperLLMProvider`、`ChatMessage`、`ToolCall`、`StreamChunk`、`SuperAgentTool` 等核心类型定义在 App target 内：

- `LumiApp/Core/Proto/SuperLLMProvider.swift`
- `LumiApp/Core/Entities/ChatMessage.swift`
- `LumiApp/Core/Entities/ToolCall.swift`
- `LumiApp/Core/Entities/StreamChunk.swift`
- `LumiApp/Core/Proto/SuperAgentTool.swift`

Swift Package 不能依赖 App target，所以有两个实现路径。

### 方案 A：完整下沉核心 LLM 类型

将 LLM provider 相关核心类型移动到 `LLMProviderKit`，App target 和供应商插件统一 import 该 package。

优点：

- 抽象边界最清晰。
- request builder、parser 可以直接使用 `ChatMessage`、`ToolCall`、`StreamChunk`、`SuperAgentTool`。
- 供应商插件代码最薄，长期维护成本最低。

缺点：

- 首次迁移影响面较大。
- 需要更新 App target 中所有引用这些类型的文件。
- 需要处理访问控制，将 package 对外 API 标记为 `public`。

### 方案 B：先抽纯协议工具

package 只提供与 App 类型无关的 OpenAI-compatible DTO、JSON/SSE parser、dictionary builder。App target 内保留 `ChatMessage`、`ToolCall`、`StreamChunk`，provider 使用 adapter 在两边转换。

优点：

- 首次改动更小。
- 更容易单独验证 stream parser 和 response parser。

缺点：

- provider 里仍会保留一部分 adapter 重复代码。
- 后续如果继续抽象，仍需处理核心类型下沉。

建议采用方案 A，但按小步迁移执行。若首次风险需要进一步降低，可以先落地方案 B 的 parser 和 DTO，再在第二阶段下沉核心类型。

## 公共 API 形态

建议让 OpenAI-compatible provider 通过组合复用，而不是继承复杂基类：

```swift
public struct OpenAICompatibleProviderConfiguration: Sendable {
    public var baseURL: String
    public var additionalHeaders: [String: String]
    public var includeUsageInStreamOptions: Bool
    public var returnsEmptyChunkWhenNoDelta: Bool
    public var acceptsFunctionScopedToolCallID: Bool
}
```

```swift
public struct OpenAICompatibleProviderAdapter: Sendable {
    public init(configuration: OpenAICompatibleProviderConfiguration)

    public func buildRequest(url: URL, apiKey: String) -> URLRequest
    public func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any]
    public func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any]
    public func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?)
    public func parseStreamChunk(data: Data) throws -> StreamChunk?
}
```

供应商插件保留 `SuperLLMProvider` 实现，但把重复逻辑委托给 adapter：

```swift
final class DeepSeekProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: .init(
            baseURL: "https://api.deepseek.com/v1/chat/completions"
        )
    )

    var baseURL: String { adapter.configuration.baseURL }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: apiKey)
    }
}
```

如果 Swift access control 或 protocol 默认实现更适合当前代码，也可以提供 protocol extension：

```swift
public protocol OpenAICompatibleProvider: SuperLLMProvider {
    var openAICompatibleConfiguration: OpenAICompatibleProviderConfiguration { get }
}
```

但第一版更推荐组合式 adapter，迁移时更容易逐个 provider 落地。

## 供应商分类

第一批迁移 OpenAI-compatible 供应商：

- OpenAI
- DeepSeek
- OpenRouter
- AiRouter
- FreeModel
- Feifeimiao
- FlyMux
- HyperAPI
- MegaLLM
- Xiaomi
- Xybbz

暂缓迁移或单独设计 adapter：

- Anthropic：message/content block/tool use/event stream 结构不同。
- Aliyun：存在供应商特定请求和流式结构。
- Zhipu：存在供应商特定请求和流式结构。
- MLX：本地推理，不属于远程 OpenAI-compatible HTTP provider。

## 分阶段实施

### Phase 1: 新建 Package 和测试骨架

- [ ] 新增 `Packages/LLMProviderKit/Package.swift`。
- [ ] 新增 `Sources/LLMProviderKit` 和 `Tests/LLMProviderKitTests`。
- [ ] 配置 macOS platform，与现有 packages 保持一致。
- [ ] 添加最小 public API 和空测试，确认 `swift test` 可运行。

### Phase 2: 下沉核心模型

- [ ] 将 `LLMModelCapabilities`、`LLMModelSpec`、`LLMModelCatalogItem` 移入 package。
- [ ] 将 `ChatMessage`、`ToolCall`、`StreamChunk`、`StreamEventType` 移入 package。
- [ ] 评估 `SuperAgentTool` 是否整体下沉；如果依赖 App 内权限或语言类型过重，先定义轻量 `LLMToolSchemaProviding` adapter。
- [ ] 将相关 initializer、properties 标记为 `public`。
- [ ] App target 引入 `LLMProviderKit`。
- [ ] 更新 App 内引用并确保编译。

### Phase 3: 实现 OpenAI-compatible 公共逻辑

- [ ] 实现 request builder。
- [ ] 实现 message transformer。
- [ ] 实现 tool formatter。
- [ ] 实现普通 response DTO 和 parser。
- [ ] 实现 SSE parser。
- [ ] 支持 provider 配置项：
  - [ ] additional headers。
  - [ ] stream usage options。
  - [ ] empty chunk fallback。
  - [ ] OpenRouter tool call id 兼容策略。

### Phase 4: 迁移第一批 Provider

- [ ] OpenAIProvider 使用 `OpenAICompatibleProviderAdapter`。
- [ ] DeepSeekProvider 使用 `OpenAICompatibleProviderAdapter`。
- [ ] OpenRouterProvider 使用 `OpenAICompatibleProviderAdapter`，保留额外 headers 和 tool id 策略。
- [ ] 迁移 AiRouter、FreeModel、Feifeimiao、FlyMux、HyperAPI、MegaLLM、Xiaomi、Xybbz。
- [ ] 删除每个 provider 中重复的 response DTO、`transformMessage`、`formatTool`、`parseStreamChunk`。
- [ ] 保留 provider 自身 model catalog、default model、api key storage key、website URL。

### Phase 5: 清理和文档

- [ ] 删除迁移后不再使用的 `Model/*Models.swift` 重复 DTO。
- [ ] 更新 provider 插件说明，记录新 provider 接入方式。
- [ ] 在 `Packages/LLMProviderKit/README.md` 增加新供应商模板。
- [ ] 检查是否还有相同 OpenAI-compatible parser 残留。

## 单元测试计划

`LLMProviderKitTests` 至少覆盖：

- [ ] `buildRequest` 设置 POST、Authorization、Content-Type。
- [ ] `buildRequest` 合并 additional headers。
- [ ] 普通 request body 包含 `model`、`messages`、`stream=false`。
- [ ] 有 tools 时生成 OpenAI function tool schema。
- [ ] 无 tools 时不写入 `tools`。
- [ ] streaming body 设置 `stream=true`。
- [ ] OpenAI 配置下写入 `stream_options.include_usage=true`。
- [ ] user / assistant / tool message 转换正确。
- [ ] assistant message 带 tool calls 时转换正确。
- [ ] 普通 JSON 响应解析 content。
- [ ] 普通 JSON 响应解析 tool calls。
- [ ] 空 `choices` 抛出可诊断错误。
- [ ] SSE text delta 返回 `.textDelta`。
- [ ] SSE `[DONE]` 返回 `isDone=true`。
- [ ] SSE error 返回 error chunk。
- [ ] SSE usage 返回 input/output tokens。
- [ ] SSE tool call start 返回 tool calls。
- [ ] SSE tool arguments delta 返回 `partialJson`。
- [ ] malformed UTF-8 或 malformed JSON 的容错策略符合预期。
- [ ] OpenRouter function scoped id fallback 正确。

Provider 迁移后建议补集成型测试：

- [ ] OpenAIProvider delegating adapter 后 request body 与迁移前一致。
- [ ] DeepSeekProvider delegating adapter 后 request body 与迁移前一致。
- [ ] OpenRouterProvider 额外 headers 保持一致。

## 风险和取舍

- 核心类型下沉会触发较多 import 和 access control 修改，建议独立成一个 PR/commit，避免和 provider 迁移混在一起。
- `SuperAgentTool` 依赖 `LanguagePreference`、`ToolArgument`、`CommandRiskLevel` 等 App 概念，可能不适合第一步整体下沉。若依赖链过长，先抽一个只包含 `name`、`description`、`inputSchema` 的轻量协议更稳。
- `String(localized:table:)` 和 provider metadata 不需要进入 package，避免把本地化资源和插件 UI 耦合进公共协议层。
- 不同供应商虽然声称 OpenAI-compatible，但 stream tool call delta 细节可能不同。adapter 必须保留配置 hook，而不是把某个 provider 的行为写死为全局默认。
- `Dictionary<String, Any>` 不利于测试和类型安全，但当前 provider 协议已经使用该形态。第一阶段可以保持兼容，后续再考虑 Encodable request body。
- 如果一次性迁移所有 provider，回归面较大。建议先迁移 OpenAI、DeepSeek、OpenRouter 三个代表，再批量处理剩余兼容 provider。

## 验证清单

- [ ] `swift test` 在 `Packages/LLMProviderKit` 通过。
- [ ] App target 编译通过。
- [ ] OpenAI 普通对话可用。
- [ ] OpenAI streaming 可用。
- [ ] DeepSeek 普通对话和 streaming 可用。
- [ ] OpenRouter 额外 headers 生效。
- [ ] tool calling 在普通响应中可用。
- [ ] tool calling 在 streaming 中可用。
- [ ] usage token 统计不回退。
- [ ] 迁移后无重复 `OpenAIResponse` / `DeepSeekResponse` / 同构 DTO 残留。

## 建议提交拆分

1. `docs: add llm provider kit plan`
2. `feat: add llm provider kit package`
3. `refactor: move llm provider core models to package`
4. `refactor: share openai compatible provider adapter`
5. `refactor: migrate openai compatible providers to kit`
6. `test: add llm provider kit coverage`

文档提交可以先单独落地，后续实现按阶段拆分，便于 review 和回归定位。
