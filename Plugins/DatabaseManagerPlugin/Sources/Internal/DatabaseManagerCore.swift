import Foundation

public actor DatabaseManagerCore {
    public static let shared = DatabaseManagerCore()

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
        if let existingConnection = activeConnections[config.id] {
            await existingConnection.close()
        }
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

    public func disconnectAll() async {
        let connections = activeConnections.values
        activeConnections.removeAll()

        for connection in connections {
            await connection.close()
        }
    }

    public func getPool(for config: DatabaseConfig, maxConnections: Int = 5) throws -> ConnectionPool {
        if let pool = pools[config.id] {
            return pool
        }
        let driver = try getDriver(for: config.type)
        let pool = ConnectionPool(config: config, driver: driver, maxConnections: maxConnections)
        pools[config.id] = pool
        return pool
    }

    public func shutdownPool(configId: UUID) async {
        guard let pool = pools.removeValue(forKey: configId) else {
            return
        }

        await pool.shutdown()
    }

    public func shutdownAllPools() async {
        let pools = pools.values
        self.pools.removeAll()

        for pool in pools {
            await pool.shutdown()
        }
    }

    public func probe(config: DatabaseConfig) async throws {
        let driver = try getDriver(for: config.type)
        let connection = try await driver.connect(config: config)
        await connection.close()
    }

    public func shutdown() async {
        await disconnectAll()
        await shutdownAllPools()
    }
}
