import Foundation

// MARK: - Provider State Notification Names

private extension Notification.Name {
    static let selectedRemoteProviderIDDidChange = Notification.Name("LumiProviderState.SelectedRemoteProviderIDDidChange")
    static let selectedLocalProviderIDDidChange = Notification.Name("LumiProviderState.SelectedLocalProviderIDDidChange")
    static let selectedModelsDidChange = Notification.Name("LumiProviderState.SelectedModelsDidChange")
    static let routingModeDidChange = Notification.Name("LumiProviderState.RoutingModeDidChange")
    static let providerAvailabilityDidChange = Notification.Name("LumiProviderState.AvailabilityDidChange")
    static let providerStatusesDidChange = Notification.Name("LumiProviderState.StatusesDidChange")
}

// MARK: - Provider State NotificationCenter Extensions

public extension NotificationCenter {
    static func postSelectedRemoteProviderIDDidChange(providerID: String?) {
        NotificationCenter.default.post(name: .selectedRemoteProviderIDDidChange, object: nil, userInfo: ["providerID": providerID as Any])
    }

    static func postSelectedLocalProviderIDDidChange(providerID: String?) {
        NotificationCenter.default.post(name: .selectedLocalProviderIDDidChange, object: nil, userInfo: ["providerID": providerID as Any])
    }

    static func postSelectedModelsDidChange(selectedModels: [String: String]) {
        NotificationCenter.default.post(name: .selectedModelsDidChange, object: nil, userInfo: ["selectedModels": selectedModels])
    }

    static func postRoutingModeDidChange(routingMode: LumiModelRoutingMode) {
        NotificationCenter.default.post(name: .routingModeDidChange, object: nil, userInfo: ["routingMode": routingMode])
    }

    static func postProviderAvailabilityDidChange(availabilityResults: [String: LumiModelAvailabilityResult]) {
        NotificationCenter.default.post(name: .providerAvailabilityDidChange, object: nil, userInfo: ["availabilityResults": availabilityResults])
    }

    static func postProviderStatusesDidChange(providerStatuses: [String: LumiLLMProviderStatus]) {
        NotificationCenter.default.post(name: .providerStatusesDidChange, object: nil, userInfo: ["providerStatuses": providerStatuses])
    }
}
