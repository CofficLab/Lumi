import Foundation

actor DatabaseAgentConnectionRegistry {
    static let shared = DatabaseAgentConnectionRegistry()

    private var configsById: [UUID: DatabaseConfig] = [:]

    private init() {}

    func upsert(_ config: DatabaseConfig) {
        configsById[config.id] = config
    }

    func remove(id: UUID) {
        configsById.removeValue(forKey: id)
    }

    func config(id: UUID) -> DatabaseConfig? {
        configsById[id]
    }

    func allConfigs() -> [DatabaseConfig] {
        configsById.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
