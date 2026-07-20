import Foundation
import LumiKernel
import SwiftUI

/// MLX 本地 LLM 供应商插件
public enum MLXPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "LLMProviderMLX",
        displayName: LumiPluginLocalization.string("MLX", bundle: .module),
        description: LumiPluginLocalization.string("Local LLM via Apple MLX", bundle: .module),
        order: 10,
        category: .llmProvider,
        policy: .disabled,
        stage: .beta,
        iconName: "desktopcomputer",
    )

    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        [MLXProvider()]
    }
}
