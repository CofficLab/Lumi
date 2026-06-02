import Foundation
import DatabaseKit

public typealias DatabaseManager = DatabaseKit.DatabaseManager

public enum DatabaseDriverBootstrap {
    private actor State {
        private var registered = false

        func beginRegistration() -> Bool {
            guard !registered else { return false }
            registered = true
            return true
        }
    }

    private static let state = State()

    public static func registerBuiltinsIfNeeded(on manager: DatabaseManager = .shared) async {
        guard await state.beginRegistration() else { return }
        await manager.register(driver: SQLiteDriver())
        await manager.register(driver: MySQLDriver())
        await manager.register(driver: PostgreSQLDriver())
        await manager.register(driver: RedisDriver())
    }
}
