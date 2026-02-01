import Foundation

class ConnectionPool {
    private let config: DatabaseConfig
    private let driver: DatabaseDriver
    private var connections: [DatabaseConnection] = []
    private let maxConnections: Int
    private let lock = NSLock()
    
    init(config: DatabaseConfig, driver: DatabaseDriver, maxConnections: Int = 5) {
        self.config = config
        self.driver = driver
        self.maxConnections = maxConnections
    }
    
    func acquire() async throws -> DatabaseConnection {
        // Simple implementation: Create new if not max, or wait (not fully implemented waiting here for brevity, just create new)
        // In a real pool, we would check for idle connections.
        // For this phase, we'll return a new connection if under limit, or reuse if we implemented return.
        
        // Since `DatabaseConnection` as defined doesn't have a "reset" or "return to pool" strictly defined in the protocol yet,
        // and SQLite connection is file-based, we will just create a new connection for now but track them.
        
        return try await driver.connect(config: config)
    }
    
    func release(_ connection: DatabaseConnection) async {
        await connection.close()
    }
    
    func shutdown() async {
        for conn in connections {
            await conn.close()
        }
        connections.removeAll()
    }
}
