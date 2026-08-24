import Foundation
import KernelLumi
import LumiUI
import SwiftUI
import LocalizationKit

/// 本地供应商设置页面
///
/// 展示本地运行的供应商列表，支持搜索和模型查看（无需 API Key）。
struct LocalProviderSettingsPage: View {
    @LumiTheme private var theme
    @Environment(\.locale) private var locale
    let kernel: KernelLumi

    @State private var selectedProviderID: String = ""
    @State private var stats: ModelUsageStatsSnapshot?

    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var availabilityState: ModelAvailabilityState {
        (llmProvider as? LLMProviderManager)?.providerAvailabilityState ?? ModelAvailabilityState()
    }

    init(kernel: KernelLumi) {
        self.kernel = kernel
    }

    var body: some View {
        ProviderSettingsPage(
            kernel: kernel,
            title: LumiPluginLocalization.string("Local Providers", bundle: .module, locale: locale),
            systemIcon: "desktopcomputer",
            localizedProvidersKey: "%lld local providers",
            isLocalProvider: { $0.isLocal },
            selectedProviderID: $selectedProviderID,
            headerAccessory: nil
        ) { provider in
            VStack(alignment: .leading, spacing: 32) {
                if let customItem = kernel.settings?.allLLMProviderSettingsItems.first(where: { $0.providerID == provider.id }),
                   let instance = llmProvider?.llmProvider(id: provider.id) {
                    customItem.makeContent(for: instance)
                } else {
                    modelSection(provider: provider)
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                // Defer the conversation-wide statistics aggregation until after
                // the provider settings page has rendered its loading state.
                await Task.yield()
                reloadStats()
            }
        }
    }

    // MARK: - Model Section

    private func modelSection(provider: LumiLLMProviderInfo) -> some View {
        AppSettingsSection(title: "可用模型", spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(provider.availableModels.enumerated()), id: \.element.id) { index, modelInfo in
                    ProviderModelRow(
                        provider: provider,
                        model: modelInfo.id,
                        stat: stat(for: provider.id, modelName: modelInfo.id),
                        dailyUsage: dailyUsage(for: provider.id, modelName: modelInfo.id),
                        availability: availabilityState
                    )

                    if index < provider.availableModels.count - 1 {
                        AppSettingsDivider()
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    // MARK: - Stats

    private func stat(for providerID: String, modelName: String) -> ModelPerformanceStats? {
        stats?.detailedStats["\(providerID)|\(modelName)"]
    }

    private func dailyUsage(for providerID: String, modelName: String) -> ModelDailyTokenSeries? {
        stats?.dailyUsage["\(providerID)|\(modelName)"]
    }

    private func reloadStats() {
        guard let messageManager = kernel.messageManager,
              let conversationManaging = kernel.resolveService((any ConversationManaging).self)
        else { return }
        let messages = conversationManaging.conversations.flatMap { messageManager.messages(for: $0.id) }
        stats = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: llmProvider?.allLLMProviders().map { type(of: $0).info } ?? []
        )
    }
}
