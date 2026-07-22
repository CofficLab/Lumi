import Combine
import Foundation
import os
import SuperLogKit

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
            NotificationCenter.postSelectedRemoteProviderIDDidChange(providerID: value)
        }
    }

    @Published public var selectedLocalProviderID: String? {
        didSet {
            guard selectedLocalProviderID != oldValue else { return }
            let value = selectedLocalProviderID
            if Self.verbose { Self.logger.info("selectedLocalProviderID → \(value ?? "nil")") }
            NotificationCenter.postSelectedLocalProviderIDDidChange(providerID: value)
        }
    }

    @Published public private(set) var selectedModels: [String: String] = [:] {
        didSet {
            guard self.selectedModels != oldValue else { return }
            if Self.verbose { Self.logger.info("selectedModels → \(self.selectedModels)") }
            NotificationCenter.postSelectedModelsDidChange(selectedModels: self.selectedModels)
        }
    }

    @Published public var routingMode: LumiModelRoutingMode = .manual {
        didSet {
            guard self.routingMode != oldValue else { return }
            if Self.verbose { Self.logger.info("routingMode → \(String(describing: self.routingMode))") }
            NotificationCenter.postRoutingModeDidChange(routingMode: self.routingMode)
        }
    }

    @Published public private(set) var availabilityResults: [String: LumiModelAvailabilityResult] = [:] {
        didSet {
            guard self.availabilityResults != oldValue else { return }
            if Self.verbose { Self.logger.info("availabilityResults.count → \(self.availabilityResults.count)") }
            NotificationCenter.postProviderAvailabilityDidChange(availabilityResults: self.availabilityResults)
        }
    }

    @Published public private(set) var providerStatuses: [String: LumiLLMProviderStatus] = [:] {
        didSet {
            guard self.providerStatuses != oldValue else { return }
            if Self.verbose { Self.logger.info("providerStatuses.count → \(self.providerStatuses.count)") }
            NotificationCenter.postProviderStatusesDidChange(providerStatuses: self.providerStatuses)
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

public extension NotificationCenter {
    private static let selectedRemoteProviderIDDidChange = Notification.Name("LumiProviderState.SelectedRemoteProviderIDDidChange")
    private static let selectedLocalProviderIDDidChange = Notification.Name("LumiProviderState.SelectedLocalProviderIDDidChange")
    private static let selectedModelsDidChange = Notification.Name("LumiProviderState.SelectedModelsDidChange")
    private static let routingModeDidChange = Notification.Name("LumiProviderState.RoutingModeDidChange")
    private static let providerAvailabilityDidChange = Notification.Name("LumiProviderState.AvailabilityDidChange")
    private static let providerStatusesDidChange = Notification.Name("LumiProviderState.StatusesDidChange")

    static func postSelectedRemoteProviderIDDidChange(providerID: String?) {
        NotificationCenter.default.post(name: selectedRemoteProviderIDDidChange, object: nil, userInfo: ["providerID": providerID as Any])
    }
    static func postSelectedLocalProviderIDDidChange(providerID: String?) {
        NotificationCenter.default.post(name: selectedLocalProviderIDDidChange, object: nil, userInfo: ["providerID": providerID as Any])
    }
    static func postSelectedModelsDidChange(selectedModels: [String: String]) {
        NotificationCenter.default.post(name: selectedModelsDidChange, object: nil, userInfo: ["selectedModels": selectedModels])
    }
    static func postRoutingModeDidChange(routingMode: LumiModelRoutingMode) {
        NotificationCenter.default.post(name: routingModeDidChange, object: nil, userInfo: ["routingMode": routingMode])
    }
    static func postProviderAvailabilityDidChange(availabilityResults: [String: LumiModelAvailabilityResult]) {
        NotificationCenter.default.post(name: providerAvailabilityDidChange, object: nil, userInfo: ["availabilityResults": availabilityResults])
    }
    static func postProviderStatusesDidChange(providerStatuses: [String: LumiLLMProviderStatus]) {
        NotificationCenter.default.post(name: providerStatusesDidChange, object: nil, userInfo: ["providerStatuses": providerStatuses])
    }
}
