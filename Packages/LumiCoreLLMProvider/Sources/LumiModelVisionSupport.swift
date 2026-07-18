import Foundation
import LumiCoreMessage

public enum LumiModelVisionSupport {
    /// Returns whether image attachments are allowed for the current model selection.
    ///
    /// - Auto routing: always `true` (router picks a model at send time).
    /// - Missing capability metadata: `true` (do not block unknown models).
    /// - Explicit `supportsVision == false`: `false`.
    public static func supportsVision(
        providerInfos: [LumiLLMProviderInfo],
        routingMode: LumiModelRoutingMode,
        providerID: String?,
        model: String?
    ) -> Bool {
        guard routingMode != .auto else { return true }

        guard let providerID,
              let provider = providerInfos.first(where: { $0.id == providerID }),
              let model,
              let capabilities = provider.modelCapabilities[model]
        else {
            return true
        }

        return capabilities.supportsVision
    }
}
