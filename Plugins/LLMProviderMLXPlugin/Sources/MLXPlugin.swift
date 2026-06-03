import Foundation
import LumiCoreKit

/// MLX 本地 LLM 供应商插件
public actor MLXPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = MLXPlugin()
    public static let id = "LLMProviderMLX"
    public static let displayName = "MLX"
    public static let description = "Local LLM via Apple MLX"
    public static let iconName = "desktopcomputer"
    public static var order: Int { 10 }
    public static var category: PluginCategory { .llmProvider }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        MLXProvider.self
    }
}
