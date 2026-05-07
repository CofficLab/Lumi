import Foundation

public actor DatabaseManager {
    public static let shared = DatabaseManager()

    private var drivers: [DatabaseType: any DatabaseDriver] = [:]
    private var activeConnections: [UUID: any DatabaseConnection] = [:]
    private var pools: [UUID: ConnectionPool] = [:]

    public init() {}

    public func register(driver: any DatabaseDriver) {
        drivers[driver.type] = driver
    }

    public func getDriver(for type: DatabaseType) throws -> any DatabaseDriver {
        guard let driver = drivers[type] else {
            throw DatabaseError.driverNotFound(type)
        }
        return driver
    }

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        let driver = try getDriver(for: config.type)
        let connection = try await driver.connect(config: config)
        activeConnections[config.id] = connection
        return connection
    }

    public func getConnection(for configId: UUID) -> (any DatabaseConnection)? {
        activeConnections[configId]
    }

    public func disconnect(configId: UUID) async {
        if let connection = activeConnections[configId] {
            await connection.close()
            activeConnections.removeValue(forKey: configId)
        }
    }

    public func getPool(for config: DatabaseConfig) throws -> ConnectionPool {
        if let pool = pools[config.id] {
            return pool
        }
        let driver = try getDriver(for: config.type)
        let pool = ConnectionPool(config: config, driver: driver)
        pools[config.id] = pool
        return pool
    }

    public func probe(config: DatabaseConfig) async throws {
        let driver = try getDriver(for: config.type)
        let connection = try await driver.connect(config: config)
        await connection.close()
    }
}
