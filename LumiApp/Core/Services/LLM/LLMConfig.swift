import Foundation

/// LLM 配置模型
///
/// 存储连接 LLM 供应商所需的配置信息。
/// 用于配置 AI 助手的提供商、模型和认证信息。
///
/// ## 使用示例
///
/// ```swift
/// // 配置 Anthropic Claude
/// let config = LLMConfig(
///     apiKey: "sk-ant-api03-...",
///     model: "claude-sonnet-4-20250514",
///     providerId: "anthropic"
/// )
///
/// // 配置 OpenAI GPT-4
/// let config = LLMConfig(
///     apiKey: "sk-...",
///     model: "gpt-4o",
///     providerId: "openai"
/// )
/// ```
struct LLMConfig: Codable, Sendable, Equatable {
    /// API 密钥
    var apiKey: String
    
    /// 模型名称
    var model: String
    
    /// 供应商 ID
    var providerId: String
    
    /// 温度参数
    ///
    /// 控制生成文本的随机性。
    /// - 较低值（如 0.0-0.3）：更确定、更保守的输出
    /// - 较高值（如 0.7-1.0）：更随机、更有创意的输出
    var temperature: Double?
    
    /// 最大生成 token 数
    ///
    /// 限制模型生成的最大 token 数量。
    /// 不同供应商有不同的默认值和上限。
    var maxTokens: Int?
    
    /// 默认配置
    ///
    /// 使用 Anthropic Claude 作为默认供应商。
    static let `default` = LLMConfig(
        apiKey: "",
        model: "claude-sonnet-4-20250514",
        providerId: "anthropic",
        temperature: nil,
        maxTokens: nil
    )

    /// 校验配置完整性，在发起请求前调用以便给出明确错误提示。
    /// - Throws: `LLMServiceError` 当必填项为空或参数超出合理范围时
    func validate() throws {
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMServiceError.apiKeyEmpty
        }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMServiceError.modelEmpty
        }
        if providerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMServiceError.providerIdEmpty
        }
        if let t = temperature, (t < 0 || t > 2) {
            throw LLMServiceError.temperatureOutOfRange(t)
        }
        if let m = maxTokens, m <= 0 {
            throw LLMServiceError.maxTokensInvalid(m)
        }
    }
}

