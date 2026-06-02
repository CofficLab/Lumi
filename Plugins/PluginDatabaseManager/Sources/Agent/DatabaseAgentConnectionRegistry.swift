import Foundation

public actor DatabaseAgentConnectionRegistry {
    public static let shared = DatabaseAgentConnectionRegistry()

    private var configsById: [UUID: DatabaseConfig] = [:]

    private init() {}

    public func upsert(_ config: DatabaseConfig) {
        configsById[config.id] = config
    }

    public func remove(id: UUID) {
        configsById.removeValue(forKey: id)
    }

    public func config(id: UUID) -> DatabaseConfig? {
        configsById[id]
    }

    public func allConfigs() -> [DatabaseConfig] {
        configsById.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
