import LLMProviderManagerPlugin
import LumiKernel
import LumiUI
import SwiftUI

struct ModelSelectorView: View {
    @LumiTheme private var theme
    let chatService: any LumiChatServicing
    /// 外部注入的可用性状态;为 nil 时使用 view 自己的本地实例。
    let externalAvailability: ModelAvailabilityState?
    let onClose: () -> Void

    @StateObject private var localAvailability = ModelAvailabilityState()

    @State private var selectedTab: ModelSelectorTab = .frequent
    @State private var searchText = ""
    @State private var detailedStats: [String: ModelPerformanceStats] = [:]
    @State private var fastModels: [ModelFastModelEntry] = []
    @State private var dailyUsage: [String: ModelDailyTokenSeries] = [:]

    /// 当前正在使用的那一个 `ModelAvailabilityState` 实例
    /// (外部注入优先,否则 view 内部新建的本地实例)。
    private var availability: ModelAvailabilityState {
        externalAvailability ?? localAvailability
    }

    var body: some View {
        HStack(spacing: 0) {
            ModelSelectorSidebar(
                availability: availability,
                providers: chatService.providerInfos,
                selectedProviderID: chatService.providerID(for: conversationID),
                selectedTab: $selectedTab,
                dailyUsage: dailyUsage
            )
            .frame(width: 380)
            .background(theme.surface)

            ModelSelectorDivider(axis: .vertical)

            VStack(spacing: 0) {
                ModelSelectorSearchBar(
                    searchText: $searchText,
                    onCancel: onClose
                )

                ModelSelectorDivider(axis: .horizontal)

                content
            }
        }
        .frame(width: 780, height: 800)
        .appSurface(style: .custom(theme.elevatedSurface), cornerRadius: 12, borderColor: theme.appSubtleBorder)
        .onAppear {
            selectedTab = .current
            reloadStats()
            triggerInitialAvailabilityCheck()
        }
        .onChange(of: chatService.revision) { _, _ in
            reloadStats()
        }
    }

    private var conversationID: UUID? {
        chatService.selectedConversationID
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .current:
            if let provider = currentProvider {
                providerList([provider], emptyTitle: "No Matching Models")
            } else {
                AppEmptyState(
                    icon: "tray",
                    title: LumiPluginLocalization.string("No Provider Selected")
                )
            }
        case .frequent:
            rankedModelList(title: "Frequent Models", ranked: frequentModels)
        case .fast:
            fastModelList
        case .auto:
            autoRoutingView
        case .all:
            providerList(filteredProviders(chatService.providerInfos), emptyTitle: "No Providers")
        case .provider(let providerID):
            if let provider = chatService.providerInfos.first(where: { $0.id == providerID }) {
                providerList([provider], emptyTitle: "No Matching Models")
            } else {
                AppEmptyState(
                    icon: "tray",
                    title: LumiPluginLocalization.string("No Provider Selected")
                )
            }
        }
    }

    @ViewBuilder
    private func providerList(_ providers: [LumiLLMProviderInfo], emptyTitle: String) -> some View {
        let visibleProviders = providers.filter { hasVisibleModels($0) }

        if visibleProviders.isEmpty {
            AppEmptyState(
                icon: "magnifyingglass",
                title: LumiPluginLocalization.string(emptyTitle)
            )
        } else {
            List {
                ForEach(visibleProviders) { provider in
                    Section {
                        ProviderSummaryCard(
                            availability: availability,
                            provider: provider,
                            isChecking: availability.isChecking(providerId: provider.id),
                            onRefresh: { checkProviderAvailability(provider) },
                            statusMessage: resolvedProviderStatus(for: provider)?.message,
                            statusMessageColor: providerStatusColor(for: resolvedProviderStatus(for: provider)?.level ?? .info),
                            dailyUsage: dailyUsage,
                            providerInstance: chatService.provider(forID: provider.id),
                            onAPIKeySaved: { checkProviderAvailability(provider) }
                        )

                        ForEach(filteredModels(for: provider), id: \.self) { model in
                            ModelCard(
                                provider: provider,
                                model: model,
                                isSelected: chatService.providerID(for: conversationID) == provider.id
                                    && chatService.modelName(for: conversationID) == model
                                    && chatService.routingMode == .manual,
                                stat: detailedStat(providerID: provider.id, modelName: model),
                                dailyUsage: dailyUsage(for: provider.id, modelName: model),
                                availability: availability,
                                onSelect: {
                                    selectModel(providerID: provider.id, model: model)
                                }
                            )
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(theme.background)
        }
    }

    private var currentProvider: LumiLLMProviderInfo? {
        guard let selectedProviderID = chatService.providerID(for: conversationID) else {
            return chatService.providerInfos.first
        }
        return chatService.providerInfos.first { $0.id == selectedProviderID }
    }

    private var autoRoutingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(
                    get: { chatService.routingMode == .auto },
                    set: { enabled in
                        chatService.setRoutingMode(enabled ? .auto : .manual)
                    }
                )
            ) {
                Text(verbatim: LumiPluginLocalization.string("Enable automatic routing"))
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Text(verbatim: LumiPluginLocalization.string(
                "Lumi will choose a provider and model based on tools, message size, and availability."
            ))
            .font(.appCaption)
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
    }

    private var frequentModels: [(provider: LumiLLMProviderInfo, model: String, count: Int)] {
        var counts: [String: Int] = [:]
        for conversation in chatService.conversations {
            for message in chatService.messages(for: conversation.id) where message.role == .assistant {
                guard let providerID = message.providerID, let model = message.modelName else { continue }
                counts["\(providerID)|\(model)", default: 0] += 1
            }
        }

        return counts.compactMap { key, count in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let provider = chatService.providerInfos.first(where: { $0.id == parts[0] })
            else {
                return nil
            }
            return (provider, parts[1], count)
        }
        .sorted { $0.count > $1.count }
    }

    @ViewBuilder
    private func rankedModelList(
        title: String,
        ranked: [(provider: LumiLLMProviderInfo, model: String, count: Int)]
    ) -> some View {
        if ranked.isEmpty {
            AppEmptyState(
                icon: "clock.arrow.circlepath",
                title: LumiPluginLocalization.string("No Usage History")
            )
        } else {
            List {
                Section(LumiPluginLocalization.string(title)) {
                    ForEach(ranked.indices, id: \.self) { index in
                        let entry = ranked[index]
                        ModelCard(
                            provider: entry.provider,
                            model: entry.model,
                            isSelected: chatService.providerID(for: conversationID) == entry.provider.id
                                && chatService.modelName(for: conversationID) == entry.model,
                            stat: detailedStat(providerID: entry.provider.id, modelName: entry.model),
                            dailyUsage: dailyUsage(for: entry.provider.id, modelName: entry.model),
                            availability: availability,
                            onSelect: {
                                selectModel(providerID: entry.provider.id, model: entry.model)
                            }
                        )
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(theme.background)
        }
    }

    @ViewBuilder
    private var fastModelList: some View {
        if fastModels.isEmpty {
            AppEmptyState(
                icon: "bolt.fill",
                title: LumiPluginLocalization.string("No Fast Models"),
                description: LumiPluginLocalization.string(
                    " Models with higher TPS will appear here"
                )
            )
        } else {
            List {
                Section(LumiPluginLocalization.string("Fast Models")) {
                    ForEach(fastModels.indices, id: \.self) { index in
                        let entry = fastModels[index]
                        ModelCard(
                            provider: entry.provider,
                            model: entry.model,
                            isSelected: chatService.providerID(for: conversationID) == entry.provider.id
                                && chatService.modelName(for: conversationID) == entry.model,
                            stat: detailedStat(providerID: entry.provider.id, modelName: entry.model),
                            dailyUsage: dailyUsage(for: entry.provider.id, modelName: entry.model),
                            availability: availability,
                            onSelect: {
                                selectModel(providerID: entry.provider.id, model: entry.model)
                            }
                        )
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(theme.background)
        }
    }

    private func detailedStat(providerID: String, modelName: String) -> ModelPerformanceStats? {
        detailedStats["\(providerID)|\(modelName)"]
    }

    private func dailyUsage(for providerID: String, modelName: String) -> ModelDailyTokenSeries? {
        dailyUsage["\(providerID)|\(modelName)"]
    }

    private func resolvedProviderStatus(for provider: LumiLLMProviderInfo) -> LumiLLMProviderStatus? {
        ModelSelectorStatusResolver.resolve(provider: provider, chatService: chatService)
    }

    private func providerStatusColor(for level: LumiLLMProviderStatus.Level) -> Color {
        switch level {
        case .info:
            theme.textSecondary
        case .warning:
            theme.warning
        case .error:
            theme.error
        }
    }

    private func selectModel(providerID: String, model: String) {
        chatService.setRoutingMode(.manual)
        chatService.selectProvider(id: providerID, model: model, for: conversationID)
        onClose()
    }

    private func filteredProviders(_ providers: [LumiLLMProviderInfo]) -> [LumiLLMProviderInfo] {
        guard !normalizedSearch.isEmpty else {
            return providers
        }

        return providers.filter { provider in
            provider.displayName.localizedCaseInsensitiveContains(searchText)
                || provider.id.localizedCaseInsensitiveContains(searchText)
                || provider.availableModels.contains {
                    $0.localizedCaseInsensitiveContains(searchText)
                        || (provider.modelDisplayNames[$0] ?? "").localizedCaseInsensitiveContains(searchText)
                }
        }
    }

    private func hasVisibleModels(_ provider: LumiLLMProviderInfo) -> Bool {
        !filteredModels(for: provider).isEmpty
    }

    private func filteredModels(for provider: LumiLLMProviderInfo) -> [String] {
        guard !normalizedSearch.isEmpty else {
            return provider.availableModels
        }

        if provider.displayName.localizedCaseInsensitiveContains(searchText)
            || provider.id.localizedCaseInsensitiveContains(searchText) {
            return provider.availableModels
        }

        return provider.availableModels.filter {
            $0.localizedCaseInsensitiveContains(searchText)
                || (provider.modelDisplayNames[$0] ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Availability orchestration

    private func checkProviderAvailability(_ provider: LumiLLMProviderInfo) {
        guard let instance = chatService.provider(forID: provider.id) else { return }
        Task { await availability.checkProvider(provider, providerInstance: instance) }
    }

    private func triggerInitialAvailabilityCheck() {
        let items: [(info: LumiLLMProviderInfo, instance: any LumiLLMProvider)] =
            chatService.providerInfos.compactMap { info in
                guard let instance = chatService.provider(forID: info.id) else { return nil }
                return (info, instance)
            }
        guard !items.isEmpty else { return }

        // 先同步标记所有模型为"检查中"状态,避免首帧渲染时显示成"不可用"
        availability.markAllPending(items.map { $0.info })

        Task { await availability.checkAll(items) }
    }

    private func reloadStats() {
        let messages = chatService.conversations.flatMap { chatService.messages(for: $0.id) }
        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: chatService.providerInfos
        )
        detailedStats = snapshot.detailedStats
        fastModels = snapshot.fastModels
        dailyUsage = snapshot.dailyUsage
    }
}
