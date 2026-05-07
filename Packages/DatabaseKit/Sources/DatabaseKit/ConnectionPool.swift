import Foundation

public final class ConnectionPool: @unchecked Sendable {
    private let config: DatabaseConfig
    private let driver: any DatabaseDriver
    private var connections: [any DatabaseConnection] = []

    public let maxConnections: Int

    public init(config: DatabaseConfig, driver: any DatabaseDriver, maxConnections: Int = 5) {
        self.config = config
        self.driver = driver
        self.maxConnections = maxConnections
    }

    public func acquire() async throws -> any DatabaseConnection {
        try await driver.connect(config: config)
    }

    public func release(_ connection: any DatabaseConnection) async {
        await connection.close()
    }

    public func shutdown() async {
        for connection in connections {
            await connection.close()
        }
        connections.removeAll()
    }
}
