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

enum LLMProviderUsageStatus: Equatable {
    case active
    case idle
    case checking
    case unavailable(String?)
    case unknown

    var title: String {
        switch self {
        case .active:
            return String(localized: "In Use", table: "LLMAvailability")
        case .idle:
            return String(localized: "Idle", table: "LLMAvailability")
        case .checking:
            return String(localized: "Checking", table: "LLMAvailability")
        case .unavailable:
            return String(localized: "Unavailable", table: "LLMAvailability")
        case .unknown:
            return String(localized: "Unknown", table: "LLMAvailability")
        }
    }

    var helpText: String {
        switch self {
        case .active:
            return String(localized: "Current selected provider", table: "LLMAvailability")
        case .idle:
            return String(localized: "Provider has available models", table: "LLMAvailability")
        case .checking:
            return String(localized: "Checking provider availability", table: "LLMAvailability")
        case .unavailable(let reason):
            return reason ?? String(localized: "Provider has no available models", table: "LLMAvailability")
        case .unknown:
            return String(localized: "Availability has not been checked", table: "LLMAvailability")
        }
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

    static func providerUsageStatus(
        providerId: String,
        selectedProviderId: String,
        store: LLMAvailabilityStore
    ) -> LLMProviderUsageStatus {
        guard let provider = store.providers.first(where: { $0.providerId == providerId }),
              !provider.models.isEmpty else {
            return .unknown
        }

        if provider.models.contains(where: { $0.status == .checking }) {
            return .checking
        }

        if provider.hasAvailableModels {
            return providerId == selectedProviderId ? .active : .idle
        }

        let unavailableReasons = provider.models.compactMap { model -> String? in
            if case .unavailable(let reason) = model.status {
                return reason
            }
            return nil
        }

        if unavailableReasons.count == provider.models.count {
            return .unavailable(unavailableReasons.first)
        }

        return .unknown
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
