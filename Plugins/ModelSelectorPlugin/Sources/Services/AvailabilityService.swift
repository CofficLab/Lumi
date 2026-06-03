import Foundation
import LumiCoreKit

public struct AvailabilitySummary: Equatable {
    public let availableModelCount: Int
    public let totalModelCount: Int
    public let isChecking: Bool

    public var hasAvailableModels: Bool {
        availableModelCount > 0
    }

    public var displayText: String? {
        guard totalModelCount > 0 else { return nil }
        return "\(availableModelCount)/\(totalModelCount)"
    }
}

public enum LLMProviderUsageStatus: Equatable {
    case active
    case idle
    case checking
    case unavailable(String?)
    case unknown

    public var title: String {
        switch self {
        case .active:
            return String(localized: "In Use", bundle: .module)
        case .idle:
            return String(localized: "Idle", bundle: .module)
        case .checking:
            return String(localized: "Checking", bundle: .module)
        case .unavailable:
            return String(localized: "Unavailable", bundle: .module)
        case .unknown:
            return String(localized: "Unknown", bundle: .module)
        }
    }

    public var helpText: String {
        switch self {
        case .active:
            return String(localized: "Current selected provider", bundle: .module)
        case .idle:
            return String(localized: "Provider has available models", bundle: .module)
        case .checking:
            return String(localized: "Checking provider availability", bundle: .module)
        case .unavailable(let reason):
            return reason ?? String(localized: "Provider has no available models", bundle: .module)
        case .unknown:
            return String(localized: "Availability has not been checked", bundle: .module)
        }
    }
}

public enum AvailabilityService {
    @MainActor
    public static func summary(store: LLMAvailabilityStore) -> AvailabilitySummary {
        let total = store.providers.reduce(0) { $0 + $1.models.count }
        return AvailabilitySummary(
            availableModelCount: store.availablePairs.count,
            totalModelCount: total,
            isChecking: store.isCheckingAll
        )
    }

    @MainActor
    public static func providerCountText(providerId: String, store: LLMAvailabilityStore) -> String? {
        guard let provider = store.providers.first(where: { $0.providerId == providerId }),
              !provider.models.isEmpty else {
            return nil
        }
        return "\(provider.availableModels.count)/\(provider.models.count)"
    }

    @MainActor
    public static func providerUsageStatus(
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

    public static func filteredProviders(
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
    public static func initializeIfNeeded(llmVM: AppLLMVM) {
        let store = LLMAvailabilityStore.shared
        store.initialize(from: llmVM)
    }

    @MainActor
    public static func refresh(llmVM: AppLLMVM) async {
        LLMAvailabilityStore.shared.initialize(from: llmVM)
    }

    @MainActor
    public static func recheckProvider(
        _ provider: LLMProviderAvailability,
        llmVM: AppLLMVM
    ) async {
        LLMAvailabilityStore.shared.initialize(from: llmVM)
    }
}
