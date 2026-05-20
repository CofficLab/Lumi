import Foundation

struct AvailabilitySummary: Equatable {
    let availableModelCount: Int
    let totalModelCount: Int
    let isChecking: Bool

    var hasAvailableModels: Bool {
        availableModelCount > 0
    }

    var displayText: String? {
        guard totalModelCount > 0 else { return nil }
        return "\(availableModelCount)/\(totalModelCount)"
    }
}

enum AvailabilityService {
    static func summary(store: LLMAvailabilityStore) -> AvailabilitySummary {
        let total = store.providers.reduce(0) { $0 + $1.models.count }
        return AvailabilitySummary(
            availableModelCount: store.availablePairs.count,
            totalModelCount: total,
            isChecking: store.isCheckingAll
        )
    }

    static func providerCountText(providerId: String, store: LLMAvailabilityStore) -> String? {
        guard let provider = store.providers.first(where: { $0.providerId == providerId }),
              !provider.models.isEmpty else {
            return nil
        }
        return "\(provider.availableModels.count)/\(provider.models.count)"
    }

    static func filteredProviders(
        from providers: [LLMProviderAvailability],
        searchText: String
    ) -> [LLMProviderAvailability] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return providers }

        return providers.filter { provider in
            provider.displayName.localizedCaseInsensitiveContains(keyword) ||
                provider.models.contains { model in
                    model.modelId.localizedCaseInsensitiveContains(keyword)
                }
        }
    }

    @MainActor
    static func initializeIfNeeded(llmVM: AppLLMVM) {
        let store = LLMAvailabilityStore.shared
        store.initialize(from: llmVM)

        let checker = LLMAvailabilityChecker(llmService: llmVM.llmService)
        Task.detached {
            await checker.checkAll()
        }
    }

    @MainActor
    static func refresh(llmVM: AppLLMVM) async {
        let checker = LLMAvailabilityChecker(llmService: llmVM.llmService)
        await checker.checkAll()
    }

    @MainActor
    static func recheckProvider(
        _ provider: LLMProviderAvailability,
        llmVM: AppLLMVM
    ) async {
        let checker = LLMAvailabilityChecker(llmService: llmVM.llmService)
        for model in provider.models {
            await checker.checkModel(providerId: provider.providerId, modelId: model.modelId)
        }
    }
}
