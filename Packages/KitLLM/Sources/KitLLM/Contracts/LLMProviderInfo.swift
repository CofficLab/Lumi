import Foundation

/// Lumi 内全局唯一的模型标识。
///
/// 供应商 API 使用的模型名可能在多个 Provider 中重复；持久化和选中态使用
/// provider + API model 的可逆编码，发送时再解析回供应商和原始模型名。
public struct LLMModelID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    private static let prefix = "lumi-model-v1:"
    private static let componentCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
    )

    public let providerID: String
    public let modelID: String

    public var rawValue: String {
        "\(Self.prefix)\(Self.encode(providerID)):\(Self.encode(modelID))"
    }

    public var description: String { rawValue }

    public init?(providerID: String, modelID: String) {
        guard !providerID.isEmpty, !modelID.isEmpty else { return nil }
        self.providerID = providerID
        self.modelID = modelID
    }

    public init?(rawValue: String) {
        guard rawValue.hasPrefix(Self.prefix) else { return nil }
        let components = rawValue.dropFirst(Self.prefix.count).split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 2,
              let providerID = Self.decode(String(components[0])),
              let modelID = Self.decode(String(components[1])),
              !providerID.isEmpty,
              !modelID.isEmpty else {
            return nil
        }
        self.providerID = providerID
        self.modelID = modelID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let parsed = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Lumi model ID")
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: componentCharacters) ?? value
    }

    private static func decode(_ value: String) -> String? {
        value.removingPercentEncoding
    }
}

/// 供应商使用的 API 协议格式（决定请求/响应如何构建与解析）。
/// 含 `CaseIterable`，供筛选菜单枚举。
public enum LLMProviderAPIFormat: String, Sendable, Equatable, CaseIterable {
    case openAI
    case anthropic
    case responses
}

/// 供应商的服务类型。
public enum LLMProviderType: String, Sendable, Equatable, CaseIterable {
    /// 由模型厂商直接提供的云服务。
    case cloudService
    /// 由第三方聚合、转发或代理模型请求的服务。
    case relay
    /// 本地运行的模型服务。
    case local

    public var displayName: String {
        switch self {
        case .cloudService: return "云服务商"
        case .relay: return "中转站"
        case .local: return "本地"
        }
    }

    public var systemImage: String {
        switch self {
        case .cloudService: return "cloud"
        case .relay: return "arrow.triangle.branch"
        case .local: return "cpu"
        }
    }
}

/// LLM 供应商的模型元数据。
///
/// 由各 LLM Provider 插件在注册时随 `LLMProviderInfo`
/// 一起贡献，供 ModelSelector 等 UI 展示与选中校验使用。
public struct LLMModelInfo: Sendable, Equatable {
    /// 供应商 API 模型名，如 `gpt-4o`、`deepseek-chat`；选中态使用全局 `LLMModelID`。
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

    /// 供应商类型；未显式指定时根据 `isLocal` 推导。
    public let providerType: LLMProviderType

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
        providerType: LLMProviderType? = nil,
        apiFormat: LLMProviderAPIFormat = .openAI,
        apiKeyStorageKey: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.models = models
        self.isLocal = isLocal
        self.providerType = providerType ?? (isLocal ? .local : .cloudService)
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
