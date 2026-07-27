import Foundation

public enum LumiModelVisionSupport {
    public static func supportsVision(
        providerInfos: [LumiLLMProviderInfo],
        routingMode: LumiModelRoutingMode,
        providerID: String?
    ) -> Bool {
        guard let providerID else { return false }
        guard let info = providerInfos.first(where: { $0.id == providerID }) else { return false }
        let modelID: String?
        switch routingMode {
        case .manual: modelID = nil
        case .auto: modelID = info.defaultModel
        }
        guard let model = modelID else { return false }
        return info.modelCapabilities[model]?.supportsVision ?? false
    }
}
