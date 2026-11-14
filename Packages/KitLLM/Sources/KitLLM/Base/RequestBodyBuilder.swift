import Foundation

/// 请求体的离主线程构建器（Issue #1269）。
///
/// ## 为什么需要它
///
/// `VendorLLMProvider` 是 `@MainActor`，它的流式/非流式入口此前都在
/// 主线程上同步完成整个请求体的构建：遍历全部历史消息、Base64 编码历史
/// 图片、逐条解析历史工具调用参数，最后再把整个 body 序列化成 JSON。
///
/// 这些工作量与历史长度成正比，却完全占住了主线程——而真正的网络 I/O
/// 是异步的。于是「等模型回复」这段时间里，滚动、输入、渲染全部被堵住。
///
/// ## 为什么必须是 `Task.detached`
///
/// 实测（Debug 构建）从 `@MainActor` 调用方触发时的线程归属：
///
/// | 调用方式 | 执行线程 |
/// |---|---|
/// | 直接调用 `nonisolated` 静态函数 | **主线程** |
/// | `Task { … }`（继承 actor 上下文） | **主线程** |
/// | `Task.detached { … }` | 后台线程 ✅
///
/// `nonisolated` 只表示「这个函数不要求 actor 隔离」，**不代表它会自动
/// 换线程**；`Task {}` 又会继承当前 actor 上下文。只有 `Task.detached`
/// 才是真正脱离当前执行上下文的。
///
/// ## 为什么直接返回 `Data`
///
/// 请求体是 `[String: Any]`，其中的图片 base64、嵌套数组与字典都是
/// `Any`。Swift 6 严格并发不允许把 `Any` 跨并发域传递（`Any` 不满足
/// `Sendable`），而请求体本身又必须**整体**在后台线程上构建——逐块搬运
/// 等于把工作又搬回主线程。
///
/// 因此每个入口在后台线程内**一次性完成构建与序列化**，只把 `Data`
/// 带回来：`Data` 是 `Sendable`，跨线程传递零成本。
enum RequestBodyBuilder {

    /// 在后台线程构建并序列化 OpenAI 兼容协议的流式请求体。
    static func openAIStreamingBody(
        messages: [LLMMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        config: LLMConfig,
        configuration: OpenAICompatibleProviderConfiguration
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
            let body = try adapter.buildStreamingRequestBody(
                messages: messages,
                model: model,
                tools: tools,
                systemPrompt: "",
                config: config
            )
            return try Self.encode(body)
        }.value
    }

    /// 在后台线程构建并序列化 OpenAI 兼容协议的非流式请求体。
    static func openAIBody(
        messages: [LLMMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        config: LLMConfig,
        configuration: OpenAICompatibleProviderConfiguration
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
            var body = try adapter.buildRequestBody(
                messages: messages,
                model: model,
                tools: tools,
                systemPrompt: ""
            )
            OpenAICompatibleGenerationOptionsApplier.apply(
                config: config,
                model: model,
                additionalReasoningEfforts: configuration.additionalReasoningEfforts,
                to: &body
            )
            return try Self.encode(body)
        }.value
    }

    /// 在后台线程构建并序列化 Anthropic 兼容协议的流式请求体。
    static func anthropicStreamingBody(
        messages: [LLMMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        config: LLMConfig,
        configuration: AnthropicCompatibleProviderConfiguration
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
            let body = try adapter.buildStreamingRequestBody(
                messages: messages,
                model: model,
                tools: tools,
                systemPrompt: "",
                config: config
            )
            return try Self.encode(body)
        }.value
    }

    /// 在后台线程构建并序列化 Anthropic 兼容协议的非流式请求体。
    static func anthropicBody(
        messages: [LLMMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        config: LLMConfig,
        configuration: AnthropicCompatibleProviderConfiguration
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
            var body = try adapter.buildRequestBody(
                messages: messages,
                model: model,
                tools: tools,
                systemPrompt: ""
            )
            AnthropicCompatibleGenerationOptionsApplier.apply(
                config: config,
                model: model,
                defaultMaxTokens: configuration.defaultMaxTokens,
                to: &body
            )
            return try Self.encode(body)
        }.value
    }

    /// 序列化请求体。
    ///
    /// 排序键选项与既有实现保持一致（`VendorAPIService` 也用 `.sortedKeys`），
    /// 因此请求内容与修复前完全相同。
    private static func encode(_ body: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }
}
