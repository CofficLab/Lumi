import Foundation

public extension NotificationCenter {
    static func postSelectedRemoteProviderIDDidChange(providerID: String?) {
        NotificationCenter.default.post(name: .lumiSelectedRemoteProviderIDDidChange, object: nil, userInfo: ["providerID": providerID as Any])
    }

    static func postSelectedLocalProviderIDDidChange(providerID: String?) {
        NotificationCenter.default.post(name: .lumiSelectedLocalProviderIDDidChange, object: nil, userInfo: ["providerID": providerID as Any])
    }

    static func postSelectedModelsDidChange(selectedModels: [String: String]) {
        NotificationCenter.default.post(name: .lumiSelectedModelsDidChange, object: nil, userInfo: ["selectedModels": selectedModels])
    }

    static func postRoutingModeDidChange(routingMode: LumiModelRoutingMode) {
        NotificationCenter.default.post(name: .lumiRoutingModeDidChange, object: nil, userInfo: ["routingMode": routingMode])
    }

    static func postProviderAvailabilityDidChange(availabilityResults: [String: LumiModelAvailabilityResult]) {
        NotificationCenter.default.post(name: .lumiProviderAvailabilityDidChange, object: nil, userInfo: ["availabilityResults": availabilityResults])
    }

    static func postProviderStatusesDidChange(providerStatuses: [String: LumiLLMProviderStatus]) {
        NotificationCenter.default.post(name: .lumiProviderStatusesDidChange, object: nil, userInfo: ["providerStatuses": providerStatuses])
    }
}
