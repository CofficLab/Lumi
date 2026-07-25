import Combine
import Foundation
import os
import SuperLogKit

// MARK: - Notification Names

private extension Notification.Name {
    static let selectedRemoteProviderIDDidChange = Notification.Name("LumiProviderState.SelectedRemoteProviderIDDidChange")
    static let selectedLocalProviderIDDidChange = Notification.Name("LumiProviderState.SelectedLocalProviderIDDidChange")
    static let selectedModelsDidChange = Notification.Name("LumiProviderState.SelectedModelsDidChange")
    static let routingModeDidChange = Notification.Name("LumiProviderState.RoutingModeDidChange")
    static let providerAvailabilityDidChange = Notification.Name("LumiProviderState.AvailabilityDidChange")
    static let providerStatusesDidChange = Notification.Name("LumiProviderState.StatusesDidChange")
}

@MainActor
public final class LumiProviderState: ObservableObject, SuperLog {
    nonisolated public static let emoji = "🤖"
    nonisolated static let verbose = false
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.provider")

    @Published public var selectedRemoteProviderID: String? {
        didSet {
            guard selectedRemoteProviderID != oldValue else { return }
            let value = selectedRemoteProviderID
            if Self.verbose { Self.logger.info("selectedRemoteProviderID → \(value ?? "nil")") }
            NotificationCenter.default.post(name: .selectedRemoteProviderIDDidChange, object: nil, userInfo: ["providerID": value as Any])
        }
    }

    @Published public var selectedLocalProviderID: String? {
        didSet {
            guard selectedLocalProviderID != oldValue else { return }
            let value = selectedLocalProviderID
            if Self.verbose { Self.logger.info("selectedLocalProviderID → \(value ?? "nil")") }
            NotificationCenter.default.post(name: .selectedLocalProviderIDDidChange, object: nil, userInfo: ["providerID": value as Any])
        }
    }

    @Published public private(set) var selectedModels: [String: String] = [:] {
        didSet {
            guard self.selectedModels != oldValue else { return }
            if Self.verbose { Self.logger.info("selectedModels → \(self.selectedModels)") }
            NotificationCenter.default.post(name: .selectedModelsDidChange, object: nil, userInfo: ["selectedModels": self.selectedModels])
        }
    }

    @Published public var routingMode: LumiModelRoutingMode = .manual {
        didSet {
            guard self.routingMode != oldValue else { return }
            if Self.verbose { Self.logger.info("routingMode → \(String(describing: self.routingMode))") }
            NotificationCenter.default.post(name: .routingModeDidChange, object: nil, userInfo: ["routingMode": self.routingMode])
        }
    }

    @Published public private(set) var availabilityResults: [String: LumiModelAvailabilityResult] = [:] {
        didSet {
            guard self.availabilityResults != oldValue else { return }
            if Self.verbose { Self.logger.info("availabilityResults.count → \(self.availabilityResults.count)") }
            NotificationCenter.default.post(name: .providerAvailabilityDidChange, object: nil, userInfo: ["availabilityResults": self.availabilityResults])
        }
    }

    @Published public private(set) var providerStatuses: [String: LumiLLMProviderStatus] = [:] {
        didSet {
            guard self.providerStatuses != oldValue else { return }
            if Self.verbose { Self.logger.info("providerStatuses.count → \(self.providerStatuses.count)") }
            NotificationCenter.default.post(name: .providerStatusesDidChange, object: nil, userInfo: ["providerStatuses": self.providerStatuses])
        }
    }

    @Published public private(set) var isProviderStateRestored: Bool = false

    public init() {}

    public func markRestored() { isProviderStateRestored = true }

    public func selectedModel(for providerID: String) -> String? { selectedModels[providerID] }

    public func setSelectedModel(_ modelID: String?, for providerID: String) {
        var models = selectedModels
        if let modelID { models[providerID] = modelID } else { models.removeValue(forKey: providerID) }
        selectedModels = models
    }

    public func restoreSelectedModels(_ models: [String: String]) { selectedModels = models }

    public func availabilityResult(for providerID: String) -> LumiModelAvailabilityResult? { availabilityResults[providerID] }
    public func setAvailabilityResult(_ result: LumiModelAvailabilityResult, for providerID: String) { availabilityResults[providerID] = result }
    public func restoreAvailabilityResults(_ results: [String: LumiModelAvailabilityResult]) { availabilityResults = results }

    public func providerStatus(for providerID: String) -> LumiLLMProviderStatus? { providerStatuses[providerID] }
    public func setProviderStatus(_ status: LumiLLMProviderStatus?, for providerID: String) {
        if let status { providerStatuses[providerID] = status } else { providerStatuses.removeValue(forKey: providerID) }
    }
    public func restoreProviderStatuses(_ statuses: [String: LumiLLMProviderStatus]) { providerStatuses = statuses }
}
