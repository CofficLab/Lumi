import Foundation
import OSLog

/// LLM 供应商协议
///
/// 定义 LLM 供应商必须实现的接口，用于统一不同供应商的接入方式。
protocol SuperLLMProvider: Sendable {

    /// 供应商实例构造函数
    ///
    /// 要求所有供应商类型都提供一个无参构造方法，以便注册表
    /// 可以通过类型元数据创建实例。
    init()

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

    /// API Key 的安全存储键名
    ///
    /// 用于在安全存储（如 Keychain）中持久化存储 API Key。
    /// 建议格式：`DevAssistant_ApiKey_{ProviderID}`
    static var apiKeyStorageKey: String { get }

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
}
