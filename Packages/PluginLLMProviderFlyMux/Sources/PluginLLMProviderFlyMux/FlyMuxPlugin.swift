import Foundation
import LumiCoreKit

/// FlyMux LLM 供应商插件
public actor FlyMuxPlugin: SuperPlugin {
    public static let shared = FlyMuxPlugin()
    public static let id = "LLMProviderFlyMux"
    public static let displayName = "FlyMux"
    public static let description = "FlyMux LLM Proxy"
    public static let iconName = "antenna.radiowaves.left.and.right"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        FlyMuxProvider.self
    }
}
