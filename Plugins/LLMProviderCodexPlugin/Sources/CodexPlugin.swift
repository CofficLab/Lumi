import Foundation
import LumiCoreKit
import SwiftUI

/// Codex CLI LLM provider plugin.
///
/// The app still exposes a small Lumi-namespace adapter for runtime discovery;
/// this package owns the provider implementation and tests.
public enum CodexPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "terminal"

    public static let info = LumiPluginInfo(
        id: "LLMProviderCodex",
        displayName: LumiPluginLocalization.string("Codex CLI", bundle: .module),
        description: LumiPluginLocalization.string("通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）", bundle: .module),
        order: 11
    )

    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [CodexProvider.self as! any LumiLLMProvider]
    }
}
