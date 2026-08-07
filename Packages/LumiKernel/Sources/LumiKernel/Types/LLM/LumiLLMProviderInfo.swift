import Foundation

/// LLM 模型可用性检测结果
public enum LumiModelAvailabilityResult: Sendable, Equatable {
    case available
    case unavailable(LumiLLMFailureDetail)
}

/// 模型能力声明
public struct LumiModelCapabilities: Sendable, Equatable, Hashable {
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let supportsTTS: Bool
    public let supportsThinking: Bool

    public init(
        supportsVision: Bool,
        supportsTools: Bool,
        supportsTTS: Bool = false,
        supportsThinking: Bool = false
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
        self.supportsThinking = supportsThinking
    }
}

/// 单个 LLM 模型的完整配置信息
///
/// 将模型 ID、显示名称、上下文窗口大小、能力声明集中到一个结构体中，
/// 避免在 provider 定义中维护多个平行字典。
public struct LumiModelInfo: Sendable, Equatable, Identifiable, Hashable {
    /// 模型 ID（即发送给 API 的 model 字段值）
    public let id: String

    /// 人类可读的显示名称（nil 则消费端应使用 id 展示）
    public let displayName: String?

    /// 上下文窗口大小（token 数），nil 表示未指定
    public let contextWindowSize: Int?

    /// 模型能力声明，nil 表示未声明
    public let capabilities: LumiModelCapabilities?

    public init(
        id: String,
        displayName: String? = nil,
        contextWindowSize: Int? = nil,
        capabilities: LumiModelCapabilities? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.contextWindowSize = contextWindowSize
        self.capabilities = capabilities
    }
}

public struct LumiLLMProviderInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let defaultModel: String
    public let availableModels: [LumiModelInfo]
    public let isLocal: Bool
    public let websiteURL: URL
    internal let apiKeyStorageKey: String?

    public var _apiKeyStorageKey: String? { apiKeyStorageKey }

    /// 根据模型 ID 快速查找模型配置
    public func modelInfo(for id: String) -> LumiModelInfo? {
        availableModels.first(where: { $0.id == id })
    }

    /// 模型 ID 列表（便捷属性，供只需 ID 的消费端使用）
    public var modelIDs: [String] {
        availableModels.map(\.id)
    }

    public init(
        id: String,
        displayName: String,
        description: String = "",
        defaultModel: String,
        availableModels: [LumiModelInfo],
        isLocal: Bool = false,
        websiteURL: URL,
        apiKeyStorageKey: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.availableModels = availableModels
        self.isLocal = isLocal
        self.websiteURL = websiteURL
        if isLocal {
            self.apiKeyStorageKey = nil
        } else {
            self.apiKeyStorageKey = apiKeyStorageKey ?? "DevAssistant_ApiKey_\(id)"
        }
    }
}
