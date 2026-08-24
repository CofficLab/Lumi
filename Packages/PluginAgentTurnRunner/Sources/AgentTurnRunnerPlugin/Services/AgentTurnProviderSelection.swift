import Foundation

/// Provider/model snapshot used for one continuous Agent Turn execution.
///
/// Conversation-bound settings are authoritative. The global selection is only
/// a fallback for legacy conversations that have no usable provider binding.
/// Once resolved, the runner keeps this snapshot for every tool-loop iteration
/// so selecting another conversation cannot change an in-flight turn.
struct AgentTurnProviderSelection: Equatable, Sendable {
    let providerID: String
    let model: String?

    static func resolve(
        conversationProviderID: String?,
        conversationModel: String?,
        selectedProviderID: String?,
        selectedModel: String?,
        availableProviderIDs: Set<String>,
        fallbackProviderID: String
    ) -> Self {
        if let conversationProviderID = normalized(conversationProviderID),
           availableProviderIDs.contains(conversationProviderID) {
            return Self(
                providerID: conversationProviderID,
                model: normalized(conversationModel)
            )
        }

        if let selectedProviderID = normalized(selectedProviderID),
           availableProviderIDs.contains(selectedProviderID) {
            return Self(
                providerID: selectedProviderID,
                model: normalized(selectedModel)
            )
        }

        return Self(providerID: fallbackProviderID, model: nil)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
