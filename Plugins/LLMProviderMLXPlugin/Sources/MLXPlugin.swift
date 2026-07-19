import Foundation
import LumiCoreKit
import SwiftUI

/// MLX 本地 LLM 供应商插件
public enum MLXPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "LLMProviderMLX",
        displayName: LumiPluginLocalization.string("MLX", bundle: .module),
        description: LumiPluginLocalization.string("Local LLM via Apple MLX", bundle: .module),
        order: 10,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "desktopcomputer",
    )

    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        [MLXProvider()]
    }
}
