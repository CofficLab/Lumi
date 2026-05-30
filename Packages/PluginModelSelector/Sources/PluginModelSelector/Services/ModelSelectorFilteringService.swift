import Foundation
import LumiCoreKit
import LLMKit

public enum ModelSelectorFilteringService {
    public static func normalizedSearchText(_ searchText: String) -> String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func matchesSearch(
        provider: LLMProviderInfo,
        model: String,
        searchText: String,
        displayName: String? = nil,
        series: String? = nil
    ) -> Bool {
        let keyword = normalizedSearchText(searchText)
        guard !keyword.isEmpty else { return true }

        return [
            model,
            displayName ?? "",
            series ?? "",
            provider.displayName,
            provider.id,
        ]
        .contains { $0.localizedCaseInsensitiveContains(keyword) }
    }

    public static func filteredProviders(
        from providers: [LLMProviderInfo],
        searchText: String,
        localModelInfosByProvider: [String: [LocalModelInfo]]
    ) -> [LLMProviderInfo] {
        let keyword = normalizedSearchText(searchText)
        guard !keyword.isEmpty else { return providers }

        return providers.filter { provider in
            hasVisibleModels(
                provider: provider,
                searchText: searchText,
                localModelInfosByProvider: localModelInfosByProvider
            )
        }
    }

    public static func hasVisibleModels(
        provider: LLMProviderInfo,
        searchText: String,
        localModelInfosByProvider: [String: [LocalModelInfo]]
    ) -> Bool {
        if matchesSearch(provider: provider, model: "", searchText: searchText) {
            return true
        }

        if provider.isLocal, let infos = localModelInfosByProvider[provider.id], !infos.isEmpty {
            return infos.contains { info in
                matchesSearch(
                    provider: provider,
                    model: info.id,
                    searchText: searchText,
                    displayName: info.displayName,
                    series: info.series
                )
            }
        }

        return provider.availableModels.contains { model in
            matchesSearch(provider: provider, model: model, searchText: searchText)
        }
    }

    public static func filteredLocalModelInfos(
        _ infos: [LocalModelInfo],
        provider: LLMProviderInfo,
        searchText: String
    ) -> [LocalModelInfo] {
        infos.filter {
            matchesSearch(
                provider: provider,
                model: $0.id,
                searchText: searchText,
                displayName: $0.displayName,
                series: $0.series
            )
        }
    }

    public static func filteredModels(
        for provider: LLMProviderInfo,
        searchText: String
    ) -> [String] {
        provider.availableModels.filter {
            matchesSearch(provider: provider, model: $0, searchText: searchText)
        }
    }

    public static func filteredFrequentModels(
        _ models: [FrequentModelEntry],
        searchText: String
    ) -> [FrequentModelEntry] {
        let keyword = normalizedSearchText(searchText)
        guard !keyword.isEmpty else { return models }

        return models.filter { entry in
            entry.modelName.localizedCaseInsensitiveContains(keyword)
                || entry.providerDisplayName.localizedCaseInsensitiveContains(keyword)
                || entry.providerId.localizedCaseInsensitiveContains(keyword)
        }
    }

    public static func filteredFastModels(
        _ models: [FastModelEntry],
        searchText: String
    ) -> [FastModelEntry] {
        let keyword = normalizedSearchText(searchText)
        guard !keyword.isEmpty else { return models }

        return models.filter { entry in
            entry.modelName.localizedCaseInsensitiveContains(keyword)
                || entry.providerDisplayName.localizedCaseInsensitiveContains(keyword)
                || entry.providerId.localizedCaseInsensitiveContains(keyword)
        }
    }

    public static func capabilityValues(
        provider: LLMProviderInfo,
        model: String,
        providerType: (any SuperLLMProvider.Type)?
    ) -> (supportsVision: Bool?, supportsTools: Bool?, supportsTTS: Bool?) {
        if provider.isLocal {
            return (nil, nil, nil)
        }

        guard let providerType,
              let caps = providerType.modelCapabilities[model] else {
            return (nil, nil, nil)
        }

        return (caps.supportsVision, caps.supportsTools, caps.supportsTTS)
    }
}
