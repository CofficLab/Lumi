import Foundation
import KitLLM
import ProviderLLMManager

/// LLM 供应商「提案」：工具产出、卡片消费的结构化载荷。
///
/// ## 为什么是提案而不是已生效的供应商
///
/// `add_llm_provider` 工具**不做任何持久化与注册**。它只把 LLM 给出的
/// 供应商信息整理成一份可校验、可编辑的提案，由用户在消息里确认后
/// 才真正落库。
///
/// 原因有三：
/// 1. LLM 给出的 baseURL、模型名经常有偏差，直接落库会留下一个用不了的供应商；
/// 2. 供应商配置决定了后续请求发往哪里，属于安全敏感项，应由用户确认；
/// 3. API Key 只能由卡片直接写入 Keychain，一旦经过对话就会进入对话记录
///    并被发回给模型端点。
struct LLMProviderProposal: Codable, Equatable, Sendable {

    /// 供应商唯一标识（注册表 key）。
    var id: String

    /// 面向用户的展示名。
    var displayName: String

    /// 供应商备注说明。
    var providerDescription: String

    /// API 根地址。
    var baseURL: String

    /// 协议格式的原始值（`LLMProviderAPIFormat.rawValue`）。
    var apiFormatRawValue: String

    /// 默认模型 id。
    var defaultModel: String

    /// 供应商提供的模型列表。
    var models: [UserDefinedCloudModel]

    /// 供应商官网地址。
    var websiteURLString: String?

    init(
        id: String,
        displayName: String,
        providerDescription: String = "",
        baseURL: String,
        apiFormat: LLMProviderAPIFormat = .openAI,
        defaultModel: String,
        models: [UserDefinedCloudModel],
        websiteURLString: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.providerDescription = providerDescription
        self.baseURL = baseURL
        self.apiFormatRawValue = apiFormat.rawValue
        self.defaultModel = defaultModel
        self.models = models
        self.websiteURLString = websiteURLString
    }

    /// 协议格式；原始值非法时退化为 OpenAI 兼容。
    var apiFormat: LLMProviderAPIFormat {
        LLMProviderAPIFormat(rawValue: apiFormatRawValue) ?? .openAI
    }

    /// 供应商官网地址。
    var websiteURL: URL? {
        guard let websiteURLString, !websiteURLString.isEmpty else { return nil }
        return URL(string: websiteURLString)
    }

    /// 转换为可落库的供应商配置。
    ///
    /// 注意：返回的是**未校验**配置，落库前必须经过 `validated()`。
    func makeConfiguration() -> UserDefinedCloudProviderConfiguration {
        UserDefinedCloudProviderConfiguration(
            id: id,
            displayName: displayName,
            description: providerDescription,
            baseURL: baseURL,
            apiFormat: apiFormat,
            defaultModel: defaultModel,
            models: models,
            websiteURLString: websiteURLString
        )
    }

    /// 提案的展示摘要（用于工具返回文本与卡片标题）。
    var summary: String {
        "\(displayName) · \(apiFormat.rawValue) · \(baseURL)"
    }
}
