import Foundation

public extension LumiPreviewFacade {
    /// Manages a small pool of warm host connections.
    actor HostProcessManager<Connection: Sendable> {
        public typealias Launcher = @Sendable (URL) async throws -> Connection
        public typealias RunningProbe = @Sendable (Connection) async -> Bool
        public typealias Terminator = @Sendable (Connection) async -> Void
        public typealias Identity = @Sendable (Connection) -> ObjectIdentifier

        private struct PooledConnection: Sendable {
            let connection: Connection
            var inUse: Bool
        }

        private let executableURL: URL
        private let maximumIdleConnections: Int
        private let launcher: Launcher
        private let isRunning: RunningProbe
        private let terminate: Terminator
        private let identity: Identity
        private var pool: [PooledConnection] = []

        public init(
            executableURL: URL,
            maximumIdleConnections: Int = 1,
            launcher: @escaping Launcher,
            isRunning: @escaping RunningProbe,
            terminate: @escaping Terminator,
            identity: @escaping Identity
        ) {
            self.executableURL = executableURL
            self.maximumIdleConnections = max(0, maximumIdleConnections)
            self.launcher = launcher
            self.isRunning = isRunning
            self.terminate = terminate
            self.identity = identity
        }

        public func warmup() async throws {
            await pruneStoppedConnections()
            let idleCount = pool.filter { !$0.inUse }.count
            guard idleCount < maximumIdleConnections else { return }
            let connection = try await launcher(executableURL)
            pool.append(PooledConnection(connection: connection, inUse: false))
        }

        public func acquire() async throws -> Connection {
            await pruneStoppedConnections()
            if let index = pool.firstIndex(where: { !$0.inUse }) {
                pool[index].inUse = true
                return pool[index].connection
            }
            let connection = try await launcher(executableURL)
            pool.append(PooledConnection(connection: connection, inUse: true))
            return connection
        }

        public func release(_ connection: Connection) async {
            let connectionID = identity(connection)
            guard let index = pool.firstIndex(where: { identity($0.connection) == connectionID }) else {
                await terminate(connection)
                return
            }
            pool[index].inUse = false
            await trimIdleConnections()
        }

        public func discard(_ connection: Connection) async {
            let connectionID = identity(connection)
            guard let index = pool.firstIndex(where: { identity($0.connection) == connectionID }) else {
                await terminate(connection)
                return
            }
            let removed = pool.remove(at: index)
            await terminate(removed.connection)
        }

        public func shutdown() async {
            let connections = pool.map(\.connection)
            pool.removeAll()
            for connection in connections {
                await terminate(connection)
            }
        }

        public var managedConnectionCount: Int {
            pool.count
        }

        public var idleConnectionCount: Int {
            pool.filter { !$0.inUse }.count
        }

        private func pruneStoppedConnections() async {
            var kept: [PooledConnection] = []
            for entry in pool {
                if await isRunning(entry.connection) {
                    kept.append(entry)
                }
            }
            pool = kept
        }

        private func trimIdleConnections() async {
            var idleSeen = 0
            var kept: [PooledConnection] = []
            var terminated: [Connection] = []

            for entry in pool {
                if entry.inUse {
                    kept.append(entry)
                } else if idleSeen < maximumIdleConnections {
                    idleSeen += 1
                    kept.append(entry)
                } else {
                    terminated.append(entry.connection)
                }
            }

            pool = kept
            for connection in terminated {
                await terminate(connection)
            }
        }
    }
}
