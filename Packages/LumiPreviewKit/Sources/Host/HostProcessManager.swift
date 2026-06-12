import Foundation

public extension LumiPreviewFacade {
    /// 宿主进程连接池管理器。
    ///
    /// 维护一个可复用的宿主进程连接池，通过预热、获取、释放和丢弃机制
    /// 管理连接的生命周期。支持连接保活和自动清理已停止的进程。
    ///
    /// 使用泛型 `Connection` 抽象具体连接类型，使其可复用于不同通信协议。
    ///
    /// 典型流程：
    /// 1. `warmup()` — 预启动空闲连接
    /// 2. `acquire()` — 获取一个可用连接
    /// 3. 使用连接进行预览操作
    /// 4. `release(_:)` — 归还连接供后续复用
    /// 5. `discard(_:)` — 连接异常时销毁
    /// 6. `shutdown()` — 关闭所有连接
    actor HostProcessManager<Connection: Sendable> {
        /// 启动新连接的闭包。
        public typealias Launcher = @Sendable (URL) async throws -> Connection
        /// 检查连接是否仍在运行的探针。
        public typealias RunningProbe = @Sendable (Connection) async -> Bool
        /// 终止连接的闭包。
        public typealias Terminator = @Sendable (Connection) async -> Void
        /// 获取连接唯一标识的闭包。
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

        /// 创建连接池管理器。
        ///
        /// - Parameters:
        ///   - executableURL: 宿主进程可执行文件路径。
        ///   - maximumIdleConnections: 最大空闲连接数，默认 1。
        ///   - launcher: 启动新连接的闭包。
        ///   - isRunning: 检查连接是否仍在运行的探针。
        ///   - terminate: 终止连接的闭包。
        ///   - identity: 获取连接唯一标识的闭包。
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

        /// 预热：清理已停止的连接，按需启动新的空闲连接。
        public func warmup() async throws {
            await pruneStoppedConnections()
            let idleCount = pool.filter { !$0.inUse }.count
            guard idleCount < maximumIdleConnections else { return }
            let connection = try await launcher(executableURL)
            pool.append(PooledConnection(connection: connection, inUse: false))
        }

        /// 获取一个可用连接。优先复用空闲连接，无可用时启动新进程。
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

        /// 归还连接到池中，标记为可复用。超出上限的空闲连接会被自动终止。
        public func release(_ connection: Connection) async {
            let connectionID = identity(connection)
            guard let index = pool.firstIndex(where: { identity($0.connection) == connectionID }) else {
                await terminate(connection)
                return
            }
            pool[index].inUse = false
            await trimIdleConnections()
        }

        /// 丢弃异常连接，从池中移除并立即终止。
        public func discard(_ connection: Connection) async {
            let connectionID = identity(connection)
            guard let index = pool.firstIndex(where: { identity($0.connection) == connectionID }) else {
                await terminate(connection)
                return
            }
            let removed = pool.remove(at: index)
            await terminate(removed.connection)
        }

        /// 关闭所有连接并清空连接池。
        public func shutdown() async {
            let connections = pool.map(\.connection)
            pool.removeAll()
            for connection in connections {
                await terminate(connection)
            }
        }

        /// 池中总连接数（包括使用中和空闲的）。
        public var managedConnectionCount: Int {
            pool.count
        }

        /// 池中空闲连接数。
        public var idleConnectionCount: Int {
            pool.filter { !$0.inUse }.count
        }

        /// 清理已停止的连接。
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
