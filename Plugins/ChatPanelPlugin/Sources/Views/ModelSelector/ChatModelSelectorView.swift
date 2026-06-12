import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatModelSelectorView: View {
    @LumiTheme private var theme

    let chatService: any LumiChatServicing
    let conversationID: UUID?
    let onChange: () -> Void
    let onClose: () -> Void

    @State private var selectedTab: ChatModelSelectorTab = .current
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            ChatModelSelectorSidebar(
                providers: chatService.providerInfos,
                selectedProviderID: chatService.selectedProviderID,
                selectedTab: $selectedTab
            )
            .frame(width: 380)
            .background(theme.surface)

            ChatDivider(axis: .vertical)

            VStack(spacing: 0) {
                ChatModelSelectorSearchBar(
                    searchText: $searchText,
                    onCancel: onClose
                )

                ChatDivider(axis: .horizontal)

                content
            }
        }
        .frame(width: 780, height: 800)
        .appSurface(style: .custom(theme.elevatedSurface), cornerRadius: 12, borderColor: theme.appSubtleBorder)
        .onAppear {
            selectedTab = .current
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .current:
            if let provider = currentProvider {
                providerList([provider], emptyTitle: "No Matching Models")
            } else {
                AppEmptyState(icon: "tray", title: "No Provider Selected")
            }
        case .frequent:
            rankedModelList(title: "Frequent Models", ranked: frequentModels)
        case .fast:
            rankedModelList(title: "Recently Used", ranked: frequentModels)
        case .auto:
            autoRoutingView
        case .availability:
            ChatAvailabilityView(chatService: chatService)
        case .all:
            providerList(filteredProviders(chatService.providerInfos), emptyTitle: "No Providers")
        case .provider(let providerID):
            if let provider = chatService.providerInfos.first(where: { $0.id == providerID }) {
                providerList([provider], emptyTitle: "No Matching Models")
            } else {
                AppEmptyState(icon: "tray", title: "No Provider Selected")
            }
        }
    }

    @ViewBuilder
    private func providerList(_ providers: [LumiLLMProviderInfo], emptyTitle: String) -> some View {
        let visibleProviders = providers.filter { hasVisibleModels($0) }

        if visibleProviders.isEmpty {
            AppEmptyState(icon: "magnifyingglass", title: emptyTitle)
        } else {
            List {
                ForEach(visibleProviders) { provider in
                    Section(header: sectionHeader(for: provider)) {
                        ForEach(filteredModels(for: provider), id: \.self) { model in
                            ChatModelSelectorModelRow(
                                provider: provider,
                                model: model,
                                isSelected: chatService.providerID(for: conversationID) == provider.id
                                    && chatService.modelName(for: conversationID) == model
                                    && chatService.routingMode == .manual,
                                onSelect: {
                                    chatService.setRoutingMode(.manual)
                                    chatService.selectProvider(id: provider.id, model: model, for: conversationID)
                                    onChange()
                                    onClose()
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
            Toggle(
                "Enable automatic routing",
                isOn: Binding(
                    get: { chatService.routingMode == .auto },
                    set: { enabled in
                        chatService.setRoutingMode(enabled ? .auto : .manual)
                        onChange()
                    }
                )
            )
            .toggleStyle(.switch)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Text(verbatim: LumiPluginLocalization.string("Lumi will choose a provider and model based on tools, message size, and availability.", bundle: .module))
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
            AppEmptyState(icon: "clock.arrow.circlepath", title: "No Usage History")
        } else {
            List {
                Section(title) {
                    ForEach(ranked, id: \.model) { entry in
                        ChatModelSelectorModelRow(
                            provider: entry.provider,
                            model: entry.model,
                            isSelected: chatService.providerID(for: conversationID) == entry.provider.id
                                && chatService.modelName(for: conversationID) == entry.model,
                            onSelect: {
                                chatService.setRoutingMode(.manual)
                                chatService.selectProvider(id: entry.provider.id, model: entry.model, for: conversationID)
                                onChange()
                                onClose()
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

    private func filteredProviders(_ providers: [LumiLLMProviderInfo]) -> [LumiLLMProviderInfo] {
        guard !normalizedSearch.isEmpty else {
            return providers
        }

        return providers.filter { provider in
            provider.displayName.localizedCaseInsensitiveContains(searchText)
                || provider.id.localizedCaseInsensitiveContains(searchText)
                || provider.availableModels.contains { $0.localizedCaseInsensitiveContains(searchText) }
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

        return provider.availableModels.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sectionHeader(for provider: LumiLLMProviderInfo) -> some View {
        HStack {
            Text(provider.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.textPrimary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
