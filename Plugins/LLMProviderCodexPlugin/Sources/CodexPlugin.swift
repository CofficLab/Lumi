import Foundation
import LumiCoreKit

/// Codex CLI LLM provider plugin.
///
/// The app still exposes a small Lumi-namespace adapter for runtime discovery;
/// this package owns the provider implementation and tests.
public actor CodexPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = CodexPlugin()
    public static let id = "LLMProviderCodex"
    public static let displayName = LumiPluginLocalization.string("Codex CLI", bundle: .module)
    public static let description = LumiPluginLocalization.string("通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）", bundle: .module)
    public static let iconName = "terminal"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 11 }

    private init() {}

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        CodexProvider.self
    }
}
