import Foundation
import AppKit
import KernelLumi
import LumiUI
import SwiftUI
import LocalizationKit

/// 远程（云端）供应商设置页面
///
/// 展示非本地供应商列表，支持搜索、API Key 管理和模型查看。
struct RemoteProviderSettingsPage: View {
    @LumiTheme private var theme
    @Environment(\.locale) private var locale
    let kernel: KernelLumi

    @State private var selectedProviderID: String = ""
    @State private var apiKey: String = ""
    @State private var savedAPIKey: String = ""
    @State private var apiKeySaveError: String?
    @State private var isLoadingSettings: Bool = false
    @State private var stats: ModelUsageStatsSnapshot?
    @State private var providerUsage: [String: ProviderDailyTokenUsageSeries] = [:]
    @State private var loadingUsageProviderIDs: Set<String> = []
    @State private var usageCache: ProviderUsageCache?
    @State private var isShowingAddProvider = false

    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var selectedProviderInstance: (any LumiLLMProvider)? {
        llmProvider?.llmProvider(id: selectedProviderID)
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
            title: LumiPluginLocalization.string("Cloud Providers", bundle: .module, locale: locale),
            systemIcon: "cloud.fill",
            localizedProvidersKey: "%lld cloud providers",
            isLocalProvider: { !$0.isLocal },
            selectedProviderID: $selectedProviderID,
            headerAccessory: AnyView(headerActions)
        ) { provider in
            VStack(alignment: .leading, spacing: 32) {
                ProviderDailyTokenUsageCard(
                    provider: provider,
                    series: providerUsage[provider.id],
                    isLoading: loadingUsageProviderIDs.contains(provider.id)
                )

                if let customItem = kernel.settings?.allLLMProviderSettingsItems.first(where: { $0.providerID == provider.id }),
                   let instance = llmProvider?.llmProvider(id: provider.id) {
                    customItem.makeContent(for: instance)
                } else {
                    apiKeySection(provider: provider)
                    modelSection(provider: provider)
                }
            }
        }
        .onChange(of: selectedProviderID) { _, _ in
            loadAPIKey()
            loadProviderUsage()
        }
        .onAppear {
            loadAPIKey()
            loadProviderUsage()
            Task { @MainActor in
                // Defer the conversation-wide statistics aggregation until after
                // the provider settings page has rendered its loading state.
                await Task.yield()
                reloadStats()
            }
        }
        .sheet(isPresented: $isShowingAddProvider) {
            AddCustomProviderSheet(kernel: kernel)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            AppButton("添加供应商", systemImage: "plus", style: .primary, size: .small) {
                isShowingAddProvider = true
            }
            openDataDirectoryButton
        }
    }

    private var openDataDirectoryButton: some View {
        AppButton("Open Data Directory", systemImage: "folder", size: .small) {
            openDataDirectory()
        }
    }

    private func openDataDirectory() {
        guard let url = usageCache?.directory
            ?? kernel.storage?.pluginDataDirectory(for: "LLMProviderManager") else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }

    // MARK: - API Key Section

    private func apiKeySection(provider: LumiLLMProviderInfo) -> some View {
        AppSettingsSection(title: "API 密钥", subtitle: "配置你的访问凭证", spacing: 12) {
            AppSettingsSecureFieldRow(
                "API Key",
                placeholder: "输入 API Key",
                allowsReveal: true,
                allowsCopy: true,
                text: $apiKey
            )
            .id(provider.id)

            HStack(spacing: 8) {
                AppButton(
                    LumiPluginLocalization.string("Save API Key", bundle: .module, locale: locale),
                    systemImage: "checkmark",
                    style: .primary,
                    size: .small
                ) {
                    saveAPIKey()
                }
                .disabled(
                    apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || apiKey == savedAPIKey
                )

                if !savedAPIKey.isEmpty {
                    AppButton(
                        LumiPluginLocalization.string("Remove API Key", bundle: .module, locale: locale),
                        systemImage: "trash",
                        style: .destructive,
                        size: .small
                    ) {
                        removeAPIKey()
                    }
                }

                if !savedAPIKey.isEmpty, apiKey == savedAPIKey {
                    HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.success)
                    Text(String(localized: "Saved"))
                        .font(.appCaption)
                        .foregroundColor(theme.success)
                    }
                }
            }

            if let apiKeySaveError {
                Text(apiKeySaveError)
                    .font(.appCaption)
                    .foregroundStyle(theme.error)
                    .textSelection(.enabled)
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
            providers: llmProvider?.allLLMProviders().map { $0.providerInfo } ?? []
        )
    }

    private func loadProviderUsage() {
        let providerID = selectedProviderID
        guard !providerID.isEmpty,
              providerUsage[providerID] == nil,
              !loadingUsageProviderIDs.contains(providerID),
              let messageManager = kernel.messageManager
        else { return }

        let cache = usageCache ?? ProviderUsageCache(
            storageDirectory: kernel.storage?.pluginDataDirectory(for: "LLMProviderManager")
        )
        usageCache = cache
        loadingUsageProviderIDs.insert(providerID)
        Task {
            let series = await buildProviderUsageSeries(
                providerID: providerID,
                messageManager: messageManager,
                cache: cache
            )
            await MainActor.run {
                providerUsage[providerID] = series
                loadingUsageProviderIDs.remove(providerID)
            }
        }
    }

    private func buildProviderUsageSeries(
        providerID: String,
        messageManager: any MessageManaging,
        cache: ProviderUsageCache
    ) async -> ProviderDailyTokenUsageSeries {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = ModelUsageStatsService.defaultDailyUsageWindowDays
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return ProviderDailyTokenUsageSeries(providerID: providerID, points: [])
        }

        let dates = (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: startDay) }
        let cached = cache.load(providerID: providerID, days: Array(dates.dropLast()))
        var usages: [MessageTokenUsage] = []
        var cacheMisses: [MessageTokenUsage] = []

        for day in dates {
            let usage: MessageTokenUsage
            if day != today, let cachedUsage = cached[day] {
                usage = cachedUsage
            } else {
                usage = await messageManager.fetchTokenUsage(on: day, providerID: providerID, modelName: nil)
                if day != today {
                    cacheMisses.append(usage)
                }
            }
            usages.append(usage)
        }

        cache.save(cacheMisses, providerID: providerID)

        return ProviderDailyTokenUsageSeries.build(providerID: providerID, usages: usages)
    }

    // MARK: - API Key Operations

    private func loadAPIKey() {
        guard let instance = selectedProviderInstance else {
            apiKey = ""
            savedAPIKey = ""
            return
        }
        isLoadingSettings = true
        apiKey = instance.getApiKey()
        savedAPIKey = apiKey
        apiKeySaveError = nil
        DispatchQueue.main.async {
            isLoadingSettings = false
        }
    }

    private func saveAPIKey() {
        guard !isLoadingSettings,
              let instance = selectedProviderInstance
        else {
            return
        }
        do {
            try instance.saveAPIKey(apiKey)
            apiKey = instance.getApiKey()
            savedAPIKey = apiKey
            apiKeySaveError = nil
        } catch {
            apiKeySaveError = error.localizedDescription
        }
    }

    private func removeAPIKey() {
        guard let instance = selectedProviderInstance else { return }
        instance.removeApiKey()
        switch instance.apiKeyDiagnostic() {
        case .missing:
            apiKey = ""
            savedAPIKey = ""
            apiKeySaveError = nil
        case .configured:
            apiKeySaveError = LumiPluginLocalization.string(
                "The API Key could not be removed from macOS Keychain.",
                bundle: .module,
                locale: locale
            )
        case .inaccessible(let details):
            apiKeySaveError = details
        }
    }
}
