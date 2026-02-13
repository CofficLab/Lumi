import Foundation
import OSLog

// MARK: - LLM Provider Protocol

/// LLM 供应商协议
///
/// 所有 LLM 供应商必须遵循此协议，实现统一的配置和请求处理接口。
/// 添加新供应商时，只需创建遵循此协议的新类并注册到 ProviderRegistry。
protocol LLMProviderProtocol: Sendable {

    // MARK: - Basic Info

    /// 供应商唯一标识符
    static var id: String { get }

    /// 供应商显示名称
    static var displayName: String { get }

    /// 供应商图标名称（SF Symbol）
    static var iconName: String { get }

    /// 供应商描述
    static var description: String { get }

    // MARK: - Configuration

    /// API Key 的 UserDefaults 键名
    static var apiKeyStorageKey: String { get }

    /// 模型选择的 UserDefaults 键名
    static var modelStorageKey: String { get }

    /// 默认模型名称
    static var defaultModel: String { get }

    /// 可用模型列表
    static var availableModels: [String] { get }

    // MARK: - API

    /// API 基础 URL
    var baseURL: String { get }

    /// 构建 API 请求
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - apiKey: API 密钥
    /// - Returns: 配置好的 URLRequest
    func buildRequest(url: URL, apiKey: String) -> URLRequest

    /// 构建请求体
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
    /// - Parameter data: 响应数据
    /// - Returns: 包含内容和工具调用的元组
    /// - Throws: 解析错误
    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?)

    /// 获取用于日志的 emoji 标识
    static var logEmoji: String { get }
}
