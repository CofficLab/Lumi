import Foundation
import Combine
import KitLLM
import ProviderLLMManager

/// 用户自定义云端供应商的一条模型配置。
public struct UserDefinedCloudModel: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let contextWindowSize: Int?
    public let supportsVision: Bool
    public let supportsTools: Bool

    public init(
        id: String,
        displayName: String? = nil,
        contextWindowSize: Int? = nil,
        supportsVision: Bool = false,
        supportsTools: Bool = true
    ) {
        self.id = id
        self.displayName = displayName ?? id
        self.contextWindowSize = contextWindowSize
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
    }

    var providerModel: LLMModelInfo {
        LLMModelInfo(
            id: id,
            displayName: displayName,
            contextWindowSize: contextWindowSize,
            supportsVision: supportsVision,
            supportsTools: supportsTools
        )
    }
}

/// 可保存到磁盘的用户自定义云端供应商配置。
///
/// API Key 不属于此结构，始终由 `VendorLLMProvider` 使用 Keychain 保存。
public struct UserDefinedCloudProviderConfiguration: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var displayName: String
    public var description: String
    public var baseURL: String
    public var apiFormatRawValue: String
    public var defaultModel: String
    public var models: [UserDefinedCloudModel]
    public var websiteURLString: String?

    public init(
        id: String,
        displayName: String,
        description: String = "",
        baseURL: String,
        apiFormat: LLMProviderAPIFormat = .openAI,
        defaultModel: String,
        models: [UserDefinedCloudModel],
        websiteURLString: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.baseURL = baseURL
        self.apiFormatRawValue = apiFormat.rawValue
        self.defaultModel = defaultModel
        self.models = models
        self.websiteURLString = websiteURLString
    }

    public var apiFormat: LLMProviderAPIFormat {
        LLMProviderAPIFormat(rawValue: apiFormatRawValue) ?? .openAI
    }

    public var websiteURL: URL? {
        guard let websiteURLString, !websiteURLString.isEmpty else { return nil }
        return URL(string: websiteURLString)
    }

    public var apiKeyStorageKey: String {
        "com.coffic.lumi.user-defined-llm.\(id)"
    }

    public func validated() throws -> UserDefinedCloudProviderConfiguration {
        var copy = self
        copy.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.defaultModel = defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !copy.id.isEmpty, !copy.displayName.isEmpty else {
            throw UserDefinedCloudProviderError.missingDisplayName
        }
        guard let url = URL(string: copy.baseURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw UserDefinedCloudProviderError.invalidBaseURL
        }
        guard !copy.models.isEmpty else {
            throw UserDefinedCloudProviderError.missingModel
        }
        guard Set(copy.models.map(\.id)).count == copy.models.count,
              copy.models.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw UserDefinedCloudProviderError.duplicateModel
        }
        if !copy.models.contains(where: { $0.id == copy.defaultModel }) {
            copy.defaultModel = copy.models[0].id
        }
        if copy.apiFormat == .responses {
            // The shared Responses implementation currently does not forward
            // tools, so it is still valid for plain text providers only.
            copy.models = copy.models.map {
                UserDefinedCloudModel(
                    id: $0.id,
                    displayName: $0.displayName,
                    contextWindowSize: $0.contextWindowSize,
                    supportsVision: $0.supportsVision,
                    supportsTools: false
                )
            }
        }
        return copy
    }
}

public enum UserDefinedCloudProviderError: LocalizedError, Equatable, Sendable {
    case missingDisplayName
    case invalidBaseURL
    case missingModel
    case duplicateModel
    case persistenceFailed

    public var errorDescription: String? {
        switch self {
        case .missingDisplayName: return "请输入供应商名称。"
        case .invalidBaseURL: return "请输入有效的 HTTP/HTTPS API 地址。"
        case .missingModel: return "请至少添加一个模型。"
        case .duplicateModel: return "模型 ID 不能为空且不能重复。"
        case .persistenceFailed: return "供应商配置保存失败。"
        }
    }
}

/// 将用户配置适配到通用的 OpenAI/Anthropic/Responses Provider。
@MainActor
public final class UserDefinedCloudProvider: VendorLLMProvider {
    public let configuration: UserDefinedCloudProviderConfiguration

    public init(
        configuration: UserDefinedCloudProviderConfiguration,
        apiService: VendorAPIService = VendorAPIService()
    ) {
        self.configuration = configuration
        super.init(
            info: LLMProviderInfo(
                id: configuration.id,
                displayName: configuration.displayName,
                description: configuration.description,
                defaultModel: configuration.defaultModel,
                models: configuration.models.map(\.providerModel),
                websiteURL: configuration.websiteURL,
                providerType: .relay,
                apiFormat: configuration.apiFormat,
                apiKeyStorageKey: configuration.apiKeyStorageKey
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        guard configuration.apiFormat == .openAI else { return nil }
        return OpenAICompatibleProviderConfiguration(baseURL: configuration.baseURL)
    }

    public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
        guard configuration.apiFormat == .anthropic else { return nil }
        return AnthropicCompatibleProviderConfiguration(baseURL: configuration.baseURL)
    }

    public override var responsesEndpointURL: String {
        configuration.apiFormat == .responses ? configuration.baseURL : super.responsesEndpointURL
    }
}

/// 用户自定义云端供应商的磁盘配置与运行时注册协调器。
@MainActor
public final class UserDefinedCloudProviderStore: ObservableObject {
    @Published public private(set) var configurations: [UserDefinedCloudProviderConfiguration] = []

    public let fileURL: URL?
    private weak var manager: (any LLMManaging)?
    private var apiService: VendorAPIService?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL
        configurations = Self.load(from: fileURL)
    }

    public func attach(
        manager: any LLMManaging,
        apiService: VendorAPIService
    ) {
        self.manager = manager
        self.apiService = apiService
        for configuration in configurations {
            register(configuration)
        }
    }

    public func isCustomProvider(id: String) -> Bool {
        configurations.contains { $0.id == id }
    }

    public func upsert(_ configuration: UserDefinedCloudProviderConfiguration) throws {
        let validated = try configuration.validated()
        guard let manager, let apiService else {
            throw UserDefinedCloudProviderError.persistenceFailed
        }

        let provider = UserDefinedCloudProvider(configuration: validated, apiService: apiService)
        let previousConfigurations = configurations
        var nextConfigurations = configurations
        if let index = nextConfigurations.firstIndex(where: { $0.id == validated.id }) {
            nextConfigurations[index] = validated
        } else {
            nextConfigurations.append(validated)
        }
        do {
            try persist(nextConfigurations)
            try manager.register(provider)
            configurations = nextConfigurations
        } catch {
            try? persist(previousConfigurations)
            throw error
        }
    }

    public func remove(id: String) throws {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        let previousConfigurations = configurations
        var nextConfigurations = configurations
        nextConfigurations.remove(at: index)
        do {
            try persist(nextConfigurations)
            manager?.unregister(id: id)
            VendorAPIKeyTools.remove(storageKey: previousConfigurations[index].apiKeyStorageKey)
            configurations = nextConfigurations
        } catch {
            try? persist(previousConfigurations)
            throw error
        }
    }

    private func register(_ configuration: UserDefinedCloudProviderConfiguration) {
        guard let manager, let apiService else { return }
        let provider = UserDefinedCloudProvider(configuration: configuration, apiService: apiService)
        try? manager.register(provider)
    }

    private func persist(_ configurations: [UserDefinedCloudProviderConfiguration]) throws {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(configurations).write(to: fileURL, options: .atomic)
        } catch {
            throw UserDefinedCloudProviderError.persistenceFailed
        }
    }

    private static func load(from fileURL: URL?) -> [UserDefinedCloudProviderConfiguration] {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let values = try? JSONDecoder().decode([UserDefinedCloudProviderConfiguration].self, from: data) else {
            return []
        }
        return values.compactMap { try? $0.validated() }
    }
}
