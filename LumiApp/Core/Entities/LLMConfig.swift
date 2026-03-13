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
///
/// ## 供应商 ID 映射
///
/// | providerId | 供应商 | 默认模型 |
/// |------------|--------|----------|
/// | "anthropic" | Anthropic (Claude) | claude-sonnet-4-20250514 |
/// | "openai" | OpenAI (GPT) | gpt-4o |
/// | "deepseek" | DeepSeek | deepseek-chat |
/// | "zhipu" | 智谱 AI | glm-4 |
/// | "aliyun" | 阿里云 | qwen-turbo |
struct LLMConfig: Codable, Sendable, Equatable {
    /// API 密钥
    ///
    /// 用于认证 LLM 服务的密钥。
    /// ⚠️ 注意：应安全存储，避免硬编码或提交到代码仓库。
    /// 建议存储在 Keychain 中。
    var apiKey: String
    
    /// 模型名称
    ///
    /// 要使用的具体模型。
    /// 不同供应商有不同的模型命名：
    /// - Anthropic: claude-sonnet-4-20250514, claude-3-5-sonnet-20241022
    /// - OpenAI: gpt-4o, gpt-4-turbo, gpt-3.5-turbo
    /// - DeepSeek: deepseek-chat
    /// - 智谱: glm-4, glm-4-flash
    var model: String
    
    /// 供应商 ID
    ///
    /// LLM 供应商的唯一标识符。
    /// 用于在 ProviderRegistry 中查找对应的供应商实现。
    var providerId: String
    
    /// 供应商计划 ID（可选）
    ///
    /// 某些供应商（如阿里云）支持多个 Plan。
    /// 对于不支持 Plan 的供应商，该字段为 nil。
    /// 对于阿里云，如果未设置则等价于使用默认 Plan（当前为 Coding Plan）。
    var planId: String? = nil
    
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
}