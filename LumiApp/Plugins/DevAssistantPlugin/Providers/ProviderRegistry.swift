import Foundation
import OSLog
import MagicKit

// MARK: - Provider Registry

@MainActor
class ProviderRegistry: SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = true

    static let shared = ProviderRegistry()

    private init() {
        if Self.verbose {
            os_log("\(self.t)供应商注册表已初始化")
        }
    }

    // MARK: - Registered Provider Types

    private(set) var providerTypes: [any LLMProviderProtocol.Type] = []
    private var providerInstances: [String: any LLMProviderProtocol] = [:]

    // MARK: - Registration

    func register<T: LLMProviderProtocol>(_ providerType: T.Type) {
        providerTypes.append(providerType)
        if Self.verbose {
            os_log("\(self.t)已注册供应商: \(providerType.displayName) (ID: \(providerType.id))")
        }
    }

    func register(_ providerTypes: [any LLMProviderProtocol.Type]) {
        for type in providerTypes {
            register(type)
        }
    }

    func registerAllProviders() {
        register([
            AnthropicProvider.self,
            OpenAIProvider.self,
            DeepSeekProvider.self,
            ZhipuProvider.self,
            AliyunProvider.self,
        ])

        if Self.verbose {
            os_log("\(self.t)已注册 \(self.providerTypes.count) 个供应商")
        }
    }

    // MARK: - Queries

    func providerType(forId id: String) -> (any LLMProviderProtocol.Type)? {
        for type in providerTypes {
            if type.id == id {
                return type
            }
        }
        return nil
    }

    func allProviders() -> [ProviderInfo] {
        providerTypes.map { type in
            ProviderInfo(
                id: type.id,
                displayName: type.displayName,
                iconName: type.iconName,
                description: type.description,
                availableModels: type.availableModels,
                defaultModel: type.defaultModel
            )
        }
    }

    func createProvider(id: String) -> (any LLMProviderProtocol)? {
        // Return cached instance if available
        if let cached = providerInstances[id] {
            return cached
        }

        // Create new instance based on type
        let instance: any LLMProviderProtocol
        switch id {
        case AnthropicProvider.id:
            instance = AnthropicProvider()
        case OpenAIProvider.id:
            instance = OpenAIProvider()
        case DeepSeekProvider.id:
            instance = DeepSeekProvider()
        case ZhipuProvider.id:
            instance = ZhipuProvider()
        case AliyunProvider.id:
            instance = AliyunProvider()
        default:
            os_log(.error, "\(self.t)未知的供应商 ID: \(id)")
            return nil
        }

        providerInstances[id] = instance
        return instance
    }
}

// MARK: - Provider Info

struct ProviderInfo: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let iconName: String
    let description: String
    let availableModels: [String]
    let defaultModel: String
}

// MARK: - Provider Registration Extension

protocol ProviderRegistrant {
    static func register(to registry: ProviderRegistry)
}
