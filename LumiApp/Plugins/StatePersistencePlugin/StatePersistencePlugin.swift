import MagicKit

actor StatePersistencePlugin: SuperPlugin {
    static let id = "StatePersistencePlugin"
    static let displayName = "State Persistence"
    static let description = "Unified plugin-owned key-value persistence"
    static let iconName = "internaldrive"
    static let isConfigurable = false
    static let enable = true
    static var order: Int { 1 }

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}
}
