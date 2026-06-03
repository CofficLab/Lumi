import Foundation
import LumiCoreKit

/// MegaLLM LLM 供应商插件
public actor MegaLLMPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = MegaLLMPlugin()
    public static let id = "LLMProviderMegaLLM"
    public static let displayName = "MegaLLM"
    public static let description = "MegaLLM Multi-Provider"
    public static let iconName = "server.rack"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        MegaLLMProvider.self
    }
}
