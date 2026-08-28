import Foundation

/// 供应商使用的 API 协议格式（决定请求/响应如何构建与解析）。
/// 含 `CaseIterable`，供筛选菜单枚举。
public enum LLMProviderAPIFormat: String, Sendable, Equatable, CaseIterable {
    case openAI
    case anthropic
    case responses
}

/// LLM 供应商的模型元数据。
///
/// 由各 LLM Provider 插件在注册时随 `LLMProviderInfo`
/// 一起贡献，供 ModelSelector 等 UI 展示与选中校验使用。
public struct LLMModelInfo: Sendable, Equatable {
    /// 模型唯一标识（作为选中值持久化，如 `gpt-4o`、`deepseek-chat`）。
    public let id: String

    /// 面向用户的展示名；缺省回退为 `id`。
    public let displayName: String

    /// 上下文窗口大小（token）；未知时为 `nil`。
    public let contextWindowSize: Int?

    /// 是否支持流式输出。
    public let supportsStreaming: Bool

    /// 是否支持视觉输入。
    public let supportsVision: Bool

    /// 是否支持工具调用。
    public let supportsTools: Bool

    public init(
        id: String,
        displayName: String? = nil,
        contextWindowSize: Int? = nil,
        supportsStreaming: Bool = true,
        supportsVision: Bool = false,
        supportsTools: Bool = true
    ) {
        self.id = id
        self.displayName = displayName ?? id
        self.contextWindowSize = contextWindowSize
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
    }
}

/// LLM 供应商元数据。
///
/// 描述一个可注册到
/// `LLMProviderManagerProviding` 的供应商（OpenAI / Anthropic / DeepSeek /
/// 本地模型等），供注册表排序、选中校验与 UI 列表使用。
public struct LLMProviderInfo: Sendable, Equatable {
    /// 供应商唯一标识（注册表 key，如 `openai`、`anthropic`）。
    public let id: String

    /// 面向用户的展示名（如 `OpenAI`）。
    public let displayName: String

    /// 一句话描述（设置页副标题）。
    public let description: String

    /// 默认模型 id；注册表在无持久化选中或选中失效时回退到它。
    public let defaultModel: String

    /// 该供应商支持的模型列表。
    public let models: [LLMModelInfo]

    /// 是否为本地模型（无需 API Key / 网络）。
    public let isLocal: Bool

    /// 供应商官网（设置页「访问官网」等场景）。
    public let websiteURL: URL?

    /// 供应商 API 协议格式。
    public let apiFormat: LLMProviderAPIFormat

    /// API Key 在 Keychain 中的存储 key（与旧版 Keychain 兼容）。
    public let apiKeyStorageKey: String

    public init(
        id: String,
        displayName: String,
        description: String = "",
        defaultModel: String,
        models: [LLMModelInfo],
        isLocal: Bool = false,
        websiteURL: URL? = nil,
        apiFormat: LLMProviderAPIFormat = .openAI,
        apiKeyStorageKey: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.models = models
        self.isLocal = isLocal
        self.websiteURL = websiteURL
        self.apiFormat = apiFormat
        self.apiKeyStorageKey = apiKeyStorageKey
    }

    /// 全部模型 id，按声明顺序。
    public var modelIDs: [String] { models.map(\.id) }

    /// 供应商是否声明了指定模型。
    public func contains(model: String) -> Bool {
        modelIDs.contains(model)
    }
}
