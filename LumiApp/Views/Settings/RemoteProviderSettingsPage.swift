import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct RemoteProviderSettingsPage: View {
    @LumiTheme private var theme
    @ObservedObject var chatService: ChatService

    @State private var selectedProviderID = ""
    @State private var apiKey = ""
    @State private var selectedModel = ""
    @State private var isLoadingSettings = false

    private let settingsStore = ProviderSettingsStore.shared

    private var remoteProviders: [LumiLLMProviderInfo] {
        chatService.providerInfos.filter { !$0.isLocal }
    }

    private var selectedProvider: LumiLLMProviderInfo? {
        remoteProviders.first { $0.id == selectedProviderID }
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            HStack(alignment: .top, spacing: 24) {
                providerSidebar
                    .frame(maxWidth: 320, alignment: .topLeading)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if selectedProvider != nil {
                            configurationCard
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedProviderID) { _, _ in
            loadSettings()
            settingsStore.saveSelectedRemoteProviderID(selectedProviderID)
        }
        .onChange(of: apiKey) { _, _ in
            saveAPIKey()
        }
    }

    private var providerSidebar: some View {
        AppCard {
            AppSettingsSection(
                title: "云端 LLM 供应商",
                subtitle: "选择你想使用的 AI 服务提供商",
                spacing: 12
            ) {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(remoteProviders) { provider in
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
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var configurationCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 32) {
                apiKeySection
                modelSection
            }
        }
    }

    private var apiKeySection: some View {
        AppSettingsSection(title: "API 密钥", subtitle: "配置你的访问凭证", spacing: 12) {
            AppSettingsSecureFieldRow(
                "API Key",
                placeholder: "输入 API Key",
                text: $apiKey
            )

            if !apiKey.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.success)
                    Text("已保存")
                        .font(.appCaption)
                        .foregroundColor(theme.success)
                }
            }
        }
    }

    private var modelSection: some View {
        AppSettingsSection(title: "可用模型", subtitle: "点击某个模型可设为默认", spacing: 12) {
            VStack(spacing: 0) {
                let models = selectedProvider?.availableModels ?? []
                ForEach(Array(models.enumerated()), id: \.element) { index, model in
                    AppSettingsModelRow(
                        model: model,
                        isDefault: selectedModel == model
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedModel = model
                            settingsStore.saveRemoteProviderModel(
                                providerID: selectedProviderID,
                                modelID: model
                            )
                        }
                    }

                    if index < models.count - 1 {
                        AppSettingsDivider()
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private func onAppear() {
        loadSelectedProviderID()
        loadSettings()
    }

    private func loadSelectedProviderID() {
        if let savedID = settingsStore.loadSelectedRemoteProviderID(),
           remoteProviders.contains(where: { $0.id == savedID }) {
            selectedProviderID = savedID
        } else if let first = remoteProviders.first {
            selectedProviderID = first.id
        }
    }

    private func loadSettings() {
        guard let storageKey = LumiLLMProviderKeys.apiKeyStorageKey(forProviderID: selectedProviderID) else {
            apiKey = ""
            return
        }

        isLoadingSettings = true
        apiKey = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        loadSelectedModel()
        DispatchQueue.main.async {
            isLoadingSettings = false
        }
    }

    private func saveAPIKey() {
        guard !isLoadingSettings,
              let storageKey = LumiLLMProviderKeys.apiKeyStorageKey(forProviderID: selectedProviderID)
        else {
            return
        }
        LumiAPIKeyStore.shared.set(apiKey, forKey: storageKey)
    }

    private func loadSelectedModel() {
        guard !selectedProviderID.isEmpty else { return }

        if let savedModel = settingsStore.loadRemoteProviderModel(providerID: selectedProviderID),
           selectedProvider?.availableModels.contains(savedModel) == true {
            selectedModel = savedModel
        } else if let defaultModel = selectedProvider?.defaultModel {
            selectedModel = defaultModel
        } else if let firstModel = selectedProvider?.availableModels.first {
            selectedModel = firstModel
        }
    }
}
