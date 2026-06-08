import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatModelSelectorView: View {
    @LumiTheme private var theme

    let chatService: any LumiChatServicing
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
            AppEmptyState(
                icon: "clock.arrow.circlepath",
                title: "No Frequent Models",
                description: "Model usage ranking will appear here after chat history is restored."
            )
        case .fast:
            AppEmptyState(
                icon: "bolt.fill",
                title: "No Fast Models",
                description: "Model performance ranking will appear here after telemetry is restored."
            )
        case .auto:
            AppEmptyState(
                icon: "wand.and.sparkles",
                title: "Auto",
                description: "Automatic model routing is not enabled in the new chat core yet."
            )
        case .availability:
            AppEmptyState(
                icon: "network",
                title: "Availability",
                description: "Provider availability checks will be connected as a separate service."
            )
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
                                isSelected: chatService.selectedProviderID == provider.id && chatService.selectedModel == model,
                                onSelect: {
                                    chatService.selectProvider(id: provider.id, model: model)
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
        guard let selectedProviderID = chatService.selectedProviderID else {
            return chatService.providerInfos.first
        }
        return chatService.providerInfos.first { $0.id == selectedProviderID }
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
