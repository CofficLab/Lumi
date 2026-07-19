import LumiKernel
import LumiUI
import SwiftUI

@available(macOS 14.0, *)
public enum MLXLumiPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.mlx",
        displayName: LumiPluginLocalization.string("MLX", bundle: .module),
        description: LumiPluginLocalization.string("Local MLX models for offline chat.", bundle: .module),
        order: 95,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "desktopcomputer",
    )

    @MainActor
    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        return [MLXLumiProvider()]
    }

    @MainActor
    public static func messageRenderers(context: any LumiChatContributionProviding) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("mlx-", for: "mlx")
        return [ModelNotDownloadedRenderer.item]
    }

    @MainActor
    public static func llmProviderSettingsViews(context: any LumiLLMProviderSettingsContributing) -> [LumiLLMProviderSettingsViewItem] {
        [
            LumiLLMProviderSettingsViewItem(providerID: "mlx") { _ in
                MLXLocalProviderSettingsView()
            },
        ]
    }
}
