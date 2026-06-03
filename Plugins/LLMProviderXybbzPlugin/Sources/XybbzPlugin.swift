import Foundation
import LumiCoreKit

/// Xybbz LLM 供应商插件
public actor XybbzPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = XybbzPlugin()
    public static let id = "LLMProviderXybbz"
    public static let displayName = "Xybbz"
    public static let description = "Xybbz LLM Gateway"
    public static let iconName = "server.rack"
    public static var order: Int { 11 }
    public static var category: PluginCategory { .llmProvider }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        XybbzProvider.self
    }
}
