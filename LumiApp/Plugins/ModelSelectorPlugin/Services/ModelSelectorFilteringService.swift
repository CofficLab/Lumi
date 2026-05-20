import Foundation
import LLMKit

enum ModelSelectorFilteringService {
    static func normalizedSearchText(_ searchText: String) -> String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matchesSearch(
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

    static func filteredProviders(
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

    static func hasVisibleModels(
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

    static func filteredLocalModelInfos(
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

    static func filteredModels(
        for provider: LLMProviderInfo,
        searchText: String
    ) -> [String] {
        provider.availableModels.filter {
            matchesSearch(provider: provider, model: $0, searchText: searchText)
        }
    }

    static func filteredFrequentModels(
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

    static func filteredFastModels(
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

    static func capabilityValues(
        provider: LLMProviderInfo,
        model: String,
        providerType: (any SuperLLMProvider.Type)?
    ) -> (supportsVision: Bool?, supportsTools: Bool?) {
        if provider.isLocal {
            return (nil, nil)
        }

        guard let providerType,
              let caps = providerType.modelCapabilities[model] else {
            if ChatInputPlugin.verbose {
                ChatInputPlugin.logger.error("🌐 远程模型缺少能力声明: provider=\(provider.id), model=\(model)")
            }
            return (nil, nil)
        }

        return (caps.supportsVision, caps.supportsTools)
    }
}
