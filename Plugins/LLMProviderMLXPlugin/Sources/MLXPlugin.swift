import Foundation
import LumiCoreKit
import SwiftUI

/// MLX 本地 LLM 供应商插件
public enum MLXPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "desktopcomputer"

    public static let info = LumiPluginInfo(
        id: "LLMProviderMLX",
        displayName: LumiPluginLocalization.string("MLX", bundle: .module),
        description: LumiPluginLocalization.string("Local LLM via Apple MLX", bundle: .module),
        order: 10
    )

    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [MLXProvider()]
    }
}
