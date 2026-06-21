import LLMProviderCodexPlugin
import LLMProviderMLXPlugin
import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct LocalProviderSettingsPage: View {
    @ObservedObject var chatService: ChatService

    @State private var selectedProviderID = ""

    private let settingsStore = ProviderSettingsStore.shared

    private var localProviders: [LumiLLMProviderInfo] {
        chatService.providerInfos.filter(\.isLocal)
    }

    private var selectedProvider: LumiLLMProviderInfo? {
        localProviders.first { $0.id == selectedProviderID }
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(spacing: 0) {
                providerSelectorCard

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let selectedProvider {
                            providerDetail(for: selectedProvider)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .onAppear(perform: loadSelectedProviderID)
        .onChange(of: selectedProviderID) { _, newValue in
            settingsStore.saveSelectedLocalProviderID(newValue)
        }
    }

    private var providerSelectorCard: some View {
        AppCard {
            AppSettingsSection(
                title: "本地 LLM 供应商",
                subtitle: "在本地设备上运行 AI 模型",
                spacing: 12
            ) {
                if localProviders.isEmpty {
                    Text(String(localized: "No local providers available"))
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(localProviders) { provider in
                            AppSettingsProviderRow(
                                title: provider.displayName,
                                subtitle: provider.description,
                                isSelected: selectedProviderID == provider.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedProviderID = provider.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func providerDetail(for provider: LumiLLMProviderInfo) -> some View {
        let initialModel = resolvedDefaultModel(for: provider)

        switch provider.id {
        case "mlx":
            if #available(macOS 14.0, *) {
                MLXLocalProviderSettingsView(
                    initialDefaultModelID: initialModel
                ) { modelID in
                    settingsStore.saveLocalProviderModel(providerID: provider.id, modelID: modelID)
                }
            } else {
                unsupportedPlatformMessage
            }
        case "codex":
            CodexLocalProviderSettingsView(
                provider: provider,
                initialDefaultModelID: initialModel
            ) { modelID in
                settingsStore.saveLocalProviderModel(providerID: provider.id, modelID: modelID)
            }
        default:
            defaultLocalProviderDetail(for: provider, initialModel: initialModel)
        }
    }

    private func defaultLocalProviderDetail(for provider: LumiLLMProviderInfo, initialModel: String) -> some View {
        AppCard {
            AppSettingsSection(title: "可用模型", subtitle: "点击某个模型可设为默认", spacing: 12) {
                VStack(spacing: 0) {
                    ForEach(Array(provider.availableModels.enumerated()), id: \.element) { index, model in
                        AppSettingsModelRow(
                            model: model,
                            isDefault: initialModel == model,
                            supportsVision: provider.modelCapabilities[model]?.supportsVision,
                            supportsTools: provider.modelCapabilities[model]?.supportsTools,
                            supportsTTS: provider.modelCapabilities[model]?.supportsTTS
                        ) {
                            settingsStore.saveLocalProviderModel(providerID: provider.id, modelID: model)
                        }

                        if index < provider.availableModels.count - 1 {
                            AppSettingsDivider()
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
        }
    }

    private var unsupportedPlatformMessage: some View {
        AppCard {
            AppSettingsSection(title: "MLX", spacing: 8) {
                Text(String(localized: "MLX local models require macOS 14 or later."))
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadSelectedProviderID() {
        if let savedID = settingsStore.loadSelectedLocalProviderID(),
           localProviders.contains(where: { $0.id == savedID }) {
            selectedProviderID = savedID
        } else if let first = localProviders.first {
            selectedProviderID = first.id
        }
    }

    private func resolvedDefaultModel(for provider: LumiLLMProviderInfo) -> String {
        if let savedModel = settingsStore.loadLocalProviderModel(providerID: provider.id),
           provider.availableModels.contains(savedModel) {
            return savedModel
        }
        return provider.defaultModel
    }
}
