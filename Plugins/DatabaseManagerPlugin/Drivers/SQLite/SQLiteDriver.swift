import Foundation

final class SQLiteDriver: DatabaseDriver, Sendable {
    var type: DatabaseType { .sqlite }
    
    func connect(config: DatabaseConfig) async throws -> DatabaseConnection {
        guard !config.database.isEmpty else {
            throw DatabaseError.invalidConfiguration("Database path is required for SQLite")
        }
        return try SQLiteConnection(path: config.database)
    }
}
