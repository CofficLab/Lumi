import Foundation
import OSLog

// MARK: - LLM Provider Protocol

/// LLM 供应商协议
///
/// 定义 LLM 供应商必须实现的接口，用于统一不同供应商的接入方式。
/// 添加新的 LLM 供应商时，只需：
/// 1. 创建遵循此协议的新结构体/类
/// 2. 在 ProviderRegistry 中注册该供应商
///
/// ## 协议要求
///
/// 供应商需要提供：
/// - **基本信息**: ID、名称、图标、描述
/// - **配置键名**: 用于 UserDefaults 存储的键
/// - **模型信息**: 默认模型和可用模型列表
/// - **API 接口**: 构建请求、解析响应
///
/// ## 实现示例
///
/// ```swift
/// struct MyProvider: LLMProviderProtocol {
///     static let id = "myprovider"
///     static let displayName = "My Provider"
///     static let iconName = "sparkles"
///     static let description = "My custom LLM provider"
///
///     static let apiKeyStorageKey = "DevAssistant_ApiKey_MyProvider"
///     static let modelStorageKey = "DevAssistant_Model_MyProvider"
///     static let defaultModel = "my-model"
///     static let availableModels = ["my-model", "my-model-v2"]
///
///     var baseURL: String { "https://api.myprovider.com/v1/chat" }
///     
///     func buildRequest(url: URL, apiKey: String) -> URLRequest { ... }
///     func buildRequestBody(...) throws -> [String: Any] { ... }
///     func parseResponse(data: Data) throws -> (String, [ToolCall]?) { ... }
///     
///     static var logEmoji: String { "✨" }
/// }
/// ```
protocol LLMProviderProtocol: Sendable {

    // MARK: - Basic Info

    /// 供应商唯一标识符
    ///
    /// 用于在系统中识别供应商。
    /// 建议使用小写英文单词，如 "anthropic", "openai", "deepseek"。
    static var id: String { get }

    /// 供应商显示名称
    ///
    /// 用于 UI 显示，如设置面板中的下拉选项。
    static var displayName: String { get }

    /// 供应商图标名称（SF Symbol）
    ///
    /// 用于 UI 显示，与显示名称对应。
    static var iconName: String { get }

    /// 供应商描述
    ///
    /// 简短描述供应商的特点和优势。
    static var description: String { get }

    // MARK: - Configuration

    /// API Key 的 UserDefaults 键名
    ///
    /// 用于持久化存储 API Key。
    /// 建议格式：`DevAssistant_ApiKey_{ProviderID}`
    static var apiKeyStorageKey: String { get }

    /// 模型选择的 UserDefaults 键名
    ///
    /// 用于持久化存储用户选择的模型。
    /// 建议格式：`DevAssistant_Model_{ProviderID}`
    static var modelStorageKey: String { get }

    /// 默认模型名称
    ///
    /// 用户未选择模型时使用的默认模型。
    static var defaultModel: String { get }

    /// 可用模型列表
    ///
    /// 用户可选择的所有模型。
    /// 建议按版本/性能排序，最新的/最好的放在前面。
    static var availableModels: [String] { get }

    // MARK: - API

    /// API 基础 URL
    ///
    /// 完整的 API 端点地址。
    var baseURL: String { get }

    /// 构建 API 请求
    ///
    /// 配置 URLRequest，包括：
    /// - HTTP 方法（通常为 POST）
    /// - 请求头（认证信息、Content-Type 等）
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - apiKey: API 密钥
    /// - Returns: 配置好的 URLRequest
    func buildRequest(url: URL, apiKey: String) -> URLRequest

    /// 构建请求体
    ///
    /// 将消息列表转换为供应商 API 所需的格式。
    /// 需要处理：
    /// - 系统消息
    /// - 用户/助手消息
    /// - 工具调用（Tool Calls）
    /// - 图片附件（如支持）
    ///
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - model: 模型名称
    ///   - tools: 可用工具列表
    ///   - systemPrompt: 系统提示词
    /// - Returns: 请求体字典
    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any]

    /// 解析 API 响应
    ///
    /// 将供应商 API 返回的数据解析为标准格式。
    /// 需要提取：
    /// - 文本内容
    /// - 工具调用（如果有）
    ///
    /// - Parameter data: 响应数据
    /// - Returns: 包含内容和工具调用的元组
    /// - Throws: 解析错误
    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?)

    /// 解析流式响应数据块
    ///
    /// 将 SSE (Server-Sent Events) 格式的数据块解析为文本片段。
    /// 用于流式响应时逐步显示内容。
    ///
    /// - Parameter data: 单个 SSE 数据块
    /// - Returns: 解析出的文本片段，如果数据块不包含内容则返回 nil
    /// - Throws: 解析错误
    func parseStreamChunk(data: Data) throws -> StreamChunk?

    /// 构建流式请求体
    ///
    /// 在普通请求体基础上添加流式参数（如 stream: true）
    ///
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - model: 模型名称
    ///   - tools: 可用工具列表
    ///   - systemPrompt: 系统提示词
    /// - Returns: 请求体字典
    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any]

    /// 获取用于日志的 emoji 标识
    ///
    /// 用于日志输出时区分不同供应商的日志。
    static var logEmoji: String { get }
}

// MARK: - Stream Event Type

/// 流式事件类型
enum StreamEventType: String, Sendable {
    case messageStart = "message_start"
    case messageDelta = "message_delta"
    case messageStop = "message_stop"
    case contentBlockStart = "content_block_start"
    case contentBlockDelta = "content_block_delta"
    case contentBlockStop = "content_block_stop"
    case thinkingDelta = "thinking_delta"
    case textDelta = "text_delta"
    case inputJsonDelta = "input_json_delta"
    case signatureDelta = "signature_delta"
    case ping = "ping"
    case unknown
}

// MARK: - Stream Chunk

/// 流式响应数据块
struct StreamChunk: Sendable {
    /// 文本内容片段
    let content: String?
    /// 是否结束
    let isDone: Bool
    /// 工具调用（如果有）
    let toolCalls: [ToolCall]?
    /// 错误信息（如果有）
    let error: String?
    /// 工具调用参数的 JSON 分片（用于流式传输）
    let partialJson: String?
    /// 事件类型
    let eventType: StreamEventType?
    /// 原始事件数据（用于调试和展示）
    let rawEvent: String?

    init(
        content: String? = nil,
        isDone: Bool = false,
        toolCalls: [ToolCall]? = nil,
        error: String? = nil,
        partialJson: String? = nil,
        eventType: StreamEventType? = nil,
        rawEvent: String? = nil
    ) {
        self.content = content
        self.isDone = isDone
        self.toolCalls = toolCalls
        self.error = error
        self.partialJson = partialJson
        self.eventType = eventType
        self.rawEvent = rawEvent
    }
}