import Foundation
import PluginLLMProviderCodex

/// Codex CLI 供应商插件
///
/// 将本地安装的 Codex CLI 集成为 LLM 供应商。
/// 通过 `codex exec --json` 命令与 OpenAI 模型通信，
/// 使用 ChatGPT 账号认证（无需 API Key）。
actor CodexPlugin: SuperPlugin {
    static let shared = CodexPlugin()
    static let id = PluginLLMProviderCodex.CodexPlugin.id
    static let displayName = PluginLLMProviderCodex.CodexPlugin.displayName
    static let description = PluginLLMProviderCodex.CodexPlugin.description
    static let iconName = PluginLLMProviderCodex.CodexPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderCodex.CodexPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderCodex.CodexProvider.self
    }
}
