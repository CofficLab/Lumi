import LumiCoreKit
import LumiUI
import SwiftUI

@available(macOS 14.0, *)
public enum MLXLumiPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "desktopcomputer"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.mlx",
        displayName: LumiPluginLocalization.string("MLX", bundle: .module),
        description: LumiPluginLocalization.string("Local MLX models for offline chat.", bundle: .module),
        order: 95
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [MLXLumiProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        [ModelNotDownloadedRenderer.item]
    }

    @MainActor
    public static func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem] {
        [
            LumiLLMProviderSettingsViewItem(providerID: "mlx") { _ in
                MLXLocalProviderSettingsView()
            },
        ]
    }
}
