import Foundation

public actor ConnectionPool {
    private let config: DatabaseConfig
    private let driver: any DatabaseDriver
    private var idleConnections: [any DatabaseConnection] = []
    private var idleConnectionIds: Set<ObjectIdentifier> = []
    private var managedConnectionIds: Set<ObjectIdentifier> = []
    private var activeConnectionCount = 0
    private var waiters: [CheckedContinuation<any DatabaseConnection, Error>] = []
    private var isShutdown = false

    public nonisolated let maxConnections: Int

    public init(config: DatabaseConfig, driver: any DatabaseDriver, maxConnections: Int = 5) {
        self.config = config
        self.driver = driver
        self.maxConnections = max(1, maxConnections)
    }

    public func acquire() async throws -> any DatabaseConnection {
        guard !isShutdown else {
            throw DatabaseError.connectionFailed("Connection pool is shut down")
        }

        while let connection = idleConnections.popLast() {
            idleConnectionIds.remove(connectionId(connection))
            if await connection.isAlive() {
                return connection
            }
            await connection.close()
            managedConnectionIds.remove(connectionId(connection))
            activeConnectionCount -= 1
        }

        if activeConnectionCount < maxConnections {
            activeConnectionCount += 1
            do {
                let connection = try await driver.connect(config: config)
                managedConnectionIds.insert(connectionId(connection))
                return connection
            } catch {
                activeConnectionCount -= 1
                throw error
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func release(_ connection: any DatabaseConnection) async {
        let id = connectionId(connection)
        guard managedConnectionIds.contains(id) else {
            await connection.close()
            return
        }

        guard !idleConnectionIds.contains(id) else {
            return
        }

        guard !isShutdown else {
            await connection.close()
            managedConnectionIds.remove(id)
            activeConnectionCount = max(0, activeConnectionCount - 1)
            return
        }

        guard await connection.isAlive() else {
            await connection.close()
            managedConnectionIds.remove(id)
            activeConnectionCount = max(0, activeConnectionCount - 1)
            resumeNextWaiterIfPossible()
            return
        }

        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume(returning: connection)
            return
        }

        idleConnections.append(connection)
        idleConnectionIds.insert(id)
    }

    public func shutdown() async {
        isShutdown = true

        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume(throwing: DatabaseError.connectionFailed("Connection pool is shut down"))
        }

        let connections = idleConnections
        idleConnections.removeAll()
        for connection in connections {
            let id = connectionId(connection)
            idleConnectionIds.remove(id)
            managedConnectionIds.remove(id)
        }
        activeConnectionCount = max(0, activeConnectionCount - connections.count)

        for connection in connections {
            await connection.close()
        }
    }

    private func resumeNextWaiterIfPossible() {
        guard !waiters.isEmpty, !isShutdown, activeConnectionCount < maxConnections else {
            return
        }

        activeConnectionCount += 1
        let waiter = waiters.removeFirst()
        Task {
            do {
                let connection = try await driver.connect(config: config)
                connectionCreated(connection)
                waiter.resume(returning: connection)
            } catch {
                connectionCreationFailed()
                waiter.resume(throwing: error)
            }
        }
    }

    private func connectionCreationFailed() {
        activeConnectionCount = max(0, activeConnectionCount - 1)
        resumeNextWaiterIfPossible()
    }

    private func connectionCreated(_ connection: any DatabaseConnection) {
        managedConnectionIds.insert(connectionId(connection))
    }

    private nonisolated func connectionId(_ connection: any DatabaseConnection) -> ObjectIdentifier {
        ObjectIdentifier(connection)
    }
}
