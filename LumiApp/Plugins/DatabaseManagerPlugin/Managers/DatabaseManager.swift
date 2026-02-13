import Foundation

actor DatabaseManager {
    static let shared = DatabaseManager()
    
    private var drivers: [DatabaseType: DatabaseDriver] = [:]
    private var activeConnections: [UUID: DatabaseConnection] = [:] // Config ID -> Connection (Simplified for UI binding)
    private var pools: [UUID: ConnectionPool] = [:]
    
    init() {
        // Register default drivers
        let sqlite = SQLiteDriver()
        drivers[sqlite.type] = sqlite
        
        // Register extended drivers
        let mysql = MySQLDriver()
        drivers[mysql.type] = mysql
        
        let pg = PostgreSQLDriver()
        drivers[pg.type] = pg
        
        let redis = RedisDriver()
        drivers[redis.type] = redis
    }
    
    func register(driver: DatabaseDriver) {
        drivers[driver.type] = driver
    }
    
    func getDriver(for type: DatabaseType) throws -> DatabaseDriver {
        guard let driver = drivers[type] else {
            throw DatabaseError.driverNotFound(type)
        }
        return driver
    }
    
    // Direct connection for UI usage (Single session)
    func connect(config: DatabaseConfig) async throws -> DatabaseConnection {
        let driver = try getDriver(for: config.type)
        let connection = try await driver.connect(config: config)
        activeConnections[config.id] = connection
        return connection
    }
    
    func getConnection(for configId: UUID) -> DatabaseConnection? {
        return activeConnections[configId]
    }
    
    func disconnect(configId: UUID) async {
        if let connection = activeConnections[configId] {
            await connection.close()
            activeConnections.removeValue(forKey: configId)
        }
    }
    
    // Pool management
    func getPool(for config: DatabaseConfig) throws -> ConnectionPool {
        if let pool = pools[config.id] {
            return pool
        }
        let driver = try getDriver(for: config.type)
        let pool = ConnectionPool(config: config, driver: driver)
        pools[config.id] = pool
        return pool
    }
    
    /// 连接探测：建立临时连接并立即关闭，不缓存到活动连接
    func probe(config: DatabaseConfig) async throws {
        let driver = try getDriver(for: config.type)
        let connection = try await driver.connect(config: config)
        await connection.close()
    }
}
