import Foundation
import LumiCoreKit

/// Codex CLI LLM provider plugin.
///
/// The app still exposes a small Lumi-namespace adapter for runtime discovery;
/// this package owns the provider implementation and tests.
public actor CodexPlugin: SuperPlugin {
    public static let shared = CodexPlugin()
    public static let id = "LLMProviderCodex"
    public static let displayName = "Codex CLI"
    public static let description = "通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）"
    public static let iconName = "terminal"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 11 }

    private init() {}

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        CodexProvider.self
    }
}
