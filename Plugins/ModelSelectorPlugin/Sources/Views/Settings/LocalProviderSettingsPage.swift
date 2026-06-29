import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct LocalProviderSettingsPage: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: ChatService

    let providerSettingsViews: [LumiLLMProviderSettingsViewItem]

    @State private var selectedProviderID = ""
    @State private var searchText = ""
    @State private var stats: ModelUsageStatsSnapshot?

    private let settingsStore = ProviderSettingsStore.shared

    init(
        chatService: ChatService,
        providerSettingsViews: [LumiLLMProviderSettingsViewItem]
    ) {
        _chatService = ObservedObject(wrappedValue: chatService)
        self.providerSettingsViews = providerSettingsViews
    }

    private var localProviders: [LumiLLMProviderInfo] {
        chatService.providerInfos.filter(\.isLocal)
    }

    private var selectedProvider: LumiLLMProviderInfo? {
        localProviders.first { $0.id == selectedProviderID }
    }

    private var filteredProviders: [LumiLLMProviderInfo] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return localProviders }
        return localProviders.filter { provider in
            provider.displayName.localizedCaseInsensitiveContains(keyword)
                || provider.description.localizedCaseInsensitiveContains(keyword)
                || provider.id.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                headerStats

                HStack(spacing: 0) {
                    providerListPane
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    providerDetailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 520, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            loadSelectedProviderID()
            reloadStats()
        }
        .onChange(of: chatService.revision) { _, _ in
            reloadStats()
        }
        .onChange(of: filteredProviders.map(\.id)) { _, ids in
            guard ids.contains(selectedProviderID) else {
                selectedProviderID = ids.first ?? ""
                return
            }
        }
        .onChange(of: selectedProviderID) { _, newValue in
            settingsStore.saveSelectedLocalProviderID(newValue)
        }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label("\(localProviders.count) 个本地供应商", systemImage: "desktopcomputer")
            Text("\(selectedProvider?.availableModels.count ?? 0) 个模型")
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var providerListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(text: $searchText, placeholder: "搜索供应商")
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredProviders) { provider in
                        providerListRow(provider)
                    }

                    if filteredProviders.isEmpty {
                        AppEmptyState(icon: "magnifyingglass", title: "未找到供应商")
                            .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func providerListRow(_ provider: LumiLLMProviderInfo) -> some View {
        let isSelected = selectedProviderID == provider.id
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProviderID = provider.id
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "desktopcomputer")
                    .font(.appBody)
                    .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.displayName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(provider.description.isEmpty ? provider.id : provider.description)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var providerDetailPane: some View {
        if let selectedProvider {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    providerHeader(for: selectedProvider)
                    providerDetail(for: selectedProvider)
                    Spacer(minLength: 0)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(icon: "desktopcomputer", title: "选择一个供应商")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    private func providerHeader(for provider: LumiLLMProviderInfo) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appAccentSoftFill)
                )

            VStack(alignment: .leading, spacing: 7) {
                Text(provider.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(provider.description.isEmpty ? provider.id : provider.description)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func providerDetail(for provider: LumiLLMProviderInfo) -> some View {
        if let customView = providerSettingsViews.first(where: { $0.providerID == provider.id }) {
            customView.makeContent(for: provider)
        } else {
            defaultLocalProviderDetail(for: provider)
        }
    }

    private func defaultLocalProviderDetail(for provider: LumiLLMProviderInfo) -> some View {
        AppSettingsSection(title: "可用模型", spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(provider.availableModels.enumerated()), id: \.element) { index, model in
                    ModelSettingsRow(
                        model: model,
                        supportsVision: provider.modelCapabilities[model]?.supportsVision,
                        supportsTools: provider.modelCapabilities[model]?.supportsTools,
                        supportsTTS: provider.modelCapabilities[model]?.supportsTTS,
                        stat: stat(for: provider.id, modelName: model),
                        dailyUsage: dailyUsage(for: provider.id, modelName: model)
                    )

                    if index < provider.availableModels.count - 1 {
                        AppSettingsDivider()
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private func reloadStats() {
        let messages = chatService.conversations.flatMap { chatService.messages(for: $0.id) }
        stats = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: chatService.providerInfos
        )
    }

    private func stat(for providerID: String, modelName: String) -> ModelPerformanceStats? {
        stats?.detailedStats["\(providerID)|\(modelName)"]
    }

    private func dailyUsage(for providerID: String, modelName: String) -> ModelDailyTokenSeries? {
        stats?.dailyUsage["\(providerID)|\(modelName)"]
    }

    private func loadSelectedProviderID() {
        if let savedID = settingsStore.loadSelectedLocalProviderID(),
           localProviders.contains(where: { $0.id == savedID }) {
            selectedProviderID = savedID
        } else if let first = localProviders.first {
            selectedProviderID = first.id
        }
    }
}
