import Foundation

/// Agent plan storage configuration persisted outside of the plan files.
final class AgentPlanStoragePluginLocalStore: @unchecked Sendable {
    static let shared = AgentPlanStoragePluginLocalStore()

    static let defaultRetentionDays = 30

    var retentionDays: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: "AgentPlanStorage.retentionDays")
            return value > 0 ? value : Self.defaultRetentionDays
        }
        set {
            UserDefaults.standard.set(max(1, newValue), forKey: "AgentPlanStorage.retentionDays")
        }
    }

    private init() {}
}
