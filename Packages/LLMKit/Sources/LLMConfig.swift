import Foundation

/// LLM 配置模型
///
/// 存储连接 LLM 供应商所需的配置信息（供应商与模型）。
/// API Key 由 `SuperLLMProvider` 各自管理，不再包含在此结构中。
///
/// ## 使用示例
///
/// ```swift
/// let config = LLMConfig(
///     model: "claude-sonnet-4-20250514",
///     providerId: "anthropic"
/// )
/// ```
public struct LLMConfig: Codable, Sendable, Equatable {
    /// 模型名称
    public var model: String

    /// 供应商 ID
    public var providerId: String

    /// 温度参数
    ///
    /// 控制生成文本的随机性。
    /// - 较低值（如 0.0-0.3）：更确定、更保守的输出
    /// - 较高值（如 0.7-1.0）：更随机、更有创意的输出
    public var temperature: Double?

    /// 最大生成 token 数
    ///
    /// 限制模型生成的最大 token 数量。
    /// 不同供应商有不同的默认值和上限。
    public var maxTokens: Int?

    /// 默认配置
    ///
    /// 使用 Anthropic Claude 作为默认供应商。
    public static let `default` = LLMConfig(
        model: "claude-sonnet-4-20250514",
        providerId: "anthropic",
        temperature: nil,
        maxTokens: nil
    )

    public init(
        model: String,
        providerId: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.providerId = providerId
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    /// 校验配置完整性，在发起请求前调用以便给出明确错误提示。
    /// - Throws: `LLMServiceError` 当必填项为空或参数超出合理范围时
    public func validate() throws {
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
