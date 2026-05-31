import Foundation
import Testing
@testable import PluginModelSelector

@Test func frequentModelFilteringDropsMissingProvidersBeforeEmptyState() {
    let entries = [
        FrequentModelEntry(
            id: "missing/gpt-4",
            providerId: "missing",
            providerDisplayName: "Missing",
            modelName: "gpt-4",
            useCount: 3,
            lastUsedAt: Date()
        ),
        FrequentModelEntry(
            id: "openai/gpt-5",
            providerId: "openai",
            providerDisplayName: "OpenAI",
            modelName: "gpt-5",
            useCount: 4,
            lastUsedAt: Date()
        ),
    ]

    let filtered = ModelSelectorFilteringService.filteredFrequentModels(
        entries,
        availableProviderIds: ["openai"],
        searchText: ""
    )

    #expect(filtered.map(\.id) == ["openai/gpt-5"])
}

@Test func fastModelFilteringDropsMissingProvidersBeforeSearch() {
    let entries = [
        FastModelEntry(
            id: "missing/fast-model",
            providerId: "missing",
            providerDisplayName: "Missing",
            modelName: "fast-model",
            avgTPS: 120,
            sampleCount: 2
        ),
        FastModelEntry(
            id: "local/fast-model",
            providerId: "local",
            providerDisplayName: "Local",
            modelName: "fast-model",
            avgTPS: 110,
            sampleCount: 3
        ),
    ]

    let filtered = ModelSelectorFilteringService.filteredFastModels(
        entries,
        availableProviderIds: ["local"],
        searchText: "missing"
    )

    #expect(filtered.isEmpty)
}
