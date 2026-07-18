import Foundation

/// LLM 模型可用性检测结果
public enum LumiModelAvailabilityResult: Sendable, Equatable {
    /// 模型可用
    case available
    /// 模型不可用，附带结构化失败信息
    case unavailable(LumiLLMFailureDetail)
}

/// 模型能力声明
public struct LumiModelCapabilities: Sendable, Equatable {
    /// 是否支持视觉输入（图片）
    public let supportsVision: Bool
    /// 是否支持工具调用
    public let supportsTools: Bool
    /// 是否支持文本转语音（TTS）
    public let supportsTTS: Bool

    public init(
        supportsVision: Bool,
        supportsTools: Bool,
        supportsTTS: Bool = false
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
    }
}

public struct LumiLLMProviderInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let defaultModel: String
    public let availableModels: [String]
    public let isLocal: Bool
    public let contextWindowSizes: [String: Int]
    /// 各模型的能力声明（key 为模型 ID）
    public let modelCapabilities: [String: LumiModelCapabilities]
    /// 各模型的展示名称（key 为模型 ID）；未命中时 UI 回退到原始 ID
    public let modelDisplayNames: [String: String]
    /// 供应商官网/控制台页面（用于设置页跳转）
    public let websiteURL: URL
    /// API Key 在 Keychain 中的存储键；本地供应商为 nil
    ///
    /// **仅供 Provider 内部使用（internal）**：外部代码（含设置页、可用性检测、迁移脚本）
    /// **禁止**直接读取此字段。API Key 的访问应通过 `LumiLLMProvider` 协议方法
    /// (`hasApiKey` / `getApiKey` / `setApiKey` / `removeApiKey`)，
    /// 由具体供应商决定存储策略。
    ///
    /// 之所以保留在 info 上，是因为：基类 `AnthropicCompatibleLumiProvider` /
    /// `OpenAICompatibleLumiProvider` 需要一个权威存储键来提供默认实现；
    /// 任何子类如果想用不同的存储策略，仍然可以 override 这几个协议方法。
    internal let apiKeyStorageKey: String?

    /// Provider 内部（含跨包基类）获取 API Key 存储键的唯一公开入口。
    /// 外部代码（设置页、可用性检测等）禁止直接读取，应通过协议方法访问。
    public var _apiKeyStorageKey: String? { apiKeyStorageKey }

    public init(
        id: String,
        displayName: String,
        description: String = "",
        defaultModel: String,
        availableModels: [String],
        isLocal: Bool = false,
        contextWindowSizes: [String: Int] = [:],
        modelCapabilities: [String: LumiModelCapabilities] = [:],
        modelDisplayNames: [String: String] = [:],
        websiteURL: URL,
        apiKeyStorageKey: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.availableModels = availableModels
        self.isLocal = isLocal
        self.contextWindowSizes = contextWindowSizes
        self.modelCapabilities = modelCapabilities
        self.modelDisplayNames = modelDisplayNames
        self.websiteURL = websiteURL
        // 本地供应商无需 API Key；远程供应商使用传入值或按 id 生成默认键
        if isLocal {
            self.apiKeyStorageKey = nil
        } else {
            self.apiKeyStorageKey = apiKeyStorageKey ?? "DevAssistant_ApiKey_\(id)"
        }
    }
}