import Foundation

/// LLM 模型可用性检测结果
public enum LumiModelAvailabilityResult: Sendable, Equatable {
    case available
    case unavailable(LumiLLMFailureDetail)
}

/// 模型能力声明
public struct LumiModelCapabilities: Sendable, Equatable {
    public let supportsVision: Bool
    public let supportsTools: Bool
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
    public let modelCapabilities: [String: LumiModelCapabilities]
    public let modelDisplayNames: [String: String]
    public let websiteURL: URL
    internal let apiKeyStorageKey: String?

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
        if isLocal {
            self.apiKeyStorageKey = nil
        } else {
            self.apiKeyStorageKey = apiKeyStorageKey ?? "DevAssistant_ApiKey_\(id)"
        }
    }
}
