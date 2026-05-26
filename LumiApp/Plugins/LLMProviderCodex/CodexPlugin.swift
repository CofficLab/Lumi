import Foundation

/// Codex CLI 供应商插件
///
/// 将本地安装的 Codex CLI 集成为 LLM 供应商。
/// 通过 `codex exec --json` 命令与 OpenAI 模型通信，
/// 使用 ChatGPT 账号认证（无需 API Key）。
actor CodexPlugin: SuperPlugin {
    static let shared = CodexPlugin()
    static let id = "LLMProviderCodex"
    static let displayName = "Codex CLI"
    static let description = "通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）"
    static let iconName = "terminal"
    static var category: PluginCategory { .llmProvider }
    static var order: Int { 11 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        CodexProvider.self
    }
}
