import Foundation
import SuperLogKit
import Combine

@MainActor
public class DatabaseViewModel: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🗄️"
    public nonisolated static let verbose: Bool = false
    @Published var configs: [DatabaseConfig] = []
    @Published var selectedConfig: DatabaseConfig?
    @Published var queryText: String = "SELECT * FROM sqlite_master;"
    @Published var queryResult: QueryResult?
    @Published var errorMessage: String?
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var redisKeys: [String] = []
    @Published var sqliteTables: [String] = []
    @Published var selectedSQLiteTable: String?
    /// 侧边栏当前展示的内容：数据浏览（Tables/Keys）或连接列表。
    @Published public var sidebarMode: DatabaseSidebarMode = .browser

    /// 结构元数据缓存（表/列/索引等），侧边栏对象树与结构 Tab 共用。
    public let schemaCache = SchemaCacheService()

    /// 右侧 Inspector 是否可见（结构详情 / ER 图 / EXPLAIN 等将放在这里）。
    @Published public var inspectorVisible: Bool = false

    public func toggleInspector() {
        inspectorVisible.toggle()
    }

    private let manager = DatabaseManagerCore.shared
    nonisolated(unsafe) private var connectedConfigId: UUID?
    /// 是否已尝试过自动重连（每次启动只自动连一次）。
    private var didAutoConnect = false

    public convenience init() {
        self.init(loadSavedConfigs: true)
    }

    /// 测试专用初始化：`loadSavedConfigs == false` 时跳过从 UserDefaults 读取已存配置，
    /// 始终使用一份独立的内存 demo 连接，避免并行测试共享进程级 UserDefaults 串扰。
    public init(loadSavedConfigs: Bool) {
        Task {
            await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        }
        if Self.verbose {
            if DatabaseManagerPlugin.verbose {
                            DatabaseManagerPlugin.logger.info("\(Self.t)初始化数据库视图模型")
            }
        }
        // 恢复上次保存的连接；首次使用时保留一个内存 demo 连接
        let savedConfigs = loadSavedConfigs ? DatabaseConnectionStore.loadConfigs() : []
        if savedConfigs.isEmpty {
            let demoConfig = DatabaseConfig(name: "Demo SQLite", type: .sqlite, database: ":memory:")
            configs = [demoConfig]
        } else {
            configs = savedConfigs
        }
        for config in configs {
            Task {
                await DatabaseAgentConnectionRegistry.shared.upsert(config)
            }
        }
    }

    deinit {
        let configId = connectedConfigId
        Task { [manager, configId] in
            guard let configId else { return }
            await manager.disconnect(configId: configId)
        }
    }

    public func addConfig(_ config: DatabaseConfig) {
        configs.append(config)
        DatabaseConnectionStore.saveConfigs(configs)
        Task {
            await DatabaseAgentConnectionRegistry.shared.upsert(config)
        }
    }

    /// 编辑已存在的连接配置（保留 id）。若表单里密码留空，沿用已存密码，避免误清空。
    /// 若当前正连着该连接，则用新配置断开重连。
    public func updateConfig(_ config: DatabaseConfig) {
        guard let index = configs.firstIndex(where: { $0.id == config.id }) else { return }
        var updated = config
        if (updated.password?.isEmpty ?? true) {
            updated.password = configs[index].password
        }
        let wasConnected = (selectedConfig?.id == config.id && isConnected)
        configs[index] = updated
        DatabaseConnectionStore.saveConfigs(configs)
        Task { await DatabaseAgentConnectionRegistry.shared.upsert(updated) }

        if wasConnected {
            Task {
                await disconnect()
                await connect(config: updated)
            }
        } else if selectedConfig?.id == config.id {
            // 未连接但已选中：同步选中引用，让侧边栏/UI 立即反映新名称等
            selectedConfig = updated
        }
    }

    /// 移除一个已保存的连接。如果删除的是当前连接，先断开再删除。
    public func removeConfig(_ config: DatabaseConfig) {
        if selectedConfig?.id == config.id {
            Task { await disconnect() }
        }
        configs.removeAll { $0.id == config.id }
        DatabaseConnectionStore.deletePassword(for: config.id)
        DatabaseConnectionStore.saveConfigs(configs)
        Task {
            await DatabaseAgentConnectionRegistry.shared.remove(id: config.id)
        }
    }

    /// 仅在首次进入数据库 UI 时尝试一次自动重连上次使用的连接。
    /// 显式断开后 `lastSelectedConfigID` 会被清空，因此断开过的连接不会自动连回来。
    public func autoConnectIfNeeded() {
        guard !didAutoConnect, !isConnected else { return }
        didAutoConnect = true
        guard let lastID = DatabaseConnectionStore.lastSelectedConfigID,
              let config = configs.first(where: { $0.id == lastID }) else { return }
        Task { await connect(config: config) }
    }
    
    public func connect(config: DatabaseConfig) async {
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        await DatabaseAgentConnectionRegistry.shared.upsert(config)
        if Self.verbose {
            if DatabaseManagerPlugin.verbose {
                            DatabaseManagerPlugin.logger.info("\(self.t)连接数据库: \(config.name)")
            }
        }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await manager.connect(config: config)
            let previousConfigId = selectedConfig?.id
            selectedConfig = config
            connectedConfigId = config.id
            isConnected = true
            queryResult = nil
            redisKeys = []
            sqliteTables = []
            selectedSQLiteTable = nil
            // 切换连接时清掉旧连接的结构缓存
            schemaCache.invalidate(configId: config.id)
            // 记住这次连接，下次自动重连
            DatabaseConnectionStore.lastSelectedConfigID = config.id
            
            // 根据类型设置默认查询/命令
            switch config.type {
            case .postgresql:
                queryText = "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"
            case .mysql:
                queryText = "SHOW TABLES;"
            case .redis:
                queryText = "SCAN 0 MATCH * COUNT 50"
                await loadRedisKeys()
            case .sqlite:
                if config.database == ":memory:" {
                    try await initDemoData(configId: config.id)
                }
                await loadSQLiteTables()
            }

            if let previousConfigId, previousConfigId != config.id {
                await manager.disconnect(configId: previousConfigId)
            }

            if Self.verbose {
                if DatabaseManagerPlugin.verbose {
                                    DatabaseManagerPlugin.logger.info("\(self.t)数据库连接成功: \(config.name)")
                }
            }
        } catch {
            if DatabaseManagerPlugin.verbose {
                            DatabaseManagerPlugin.logger.error("\(self.t)数据库连接失败: \(error.localizedDescription)")
            }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func disconnect() async {
        guard let config = selectedConfig else { return }
        if Self.verbose {
            if DatabaseManagerPlugin.verbose {
                            DatabaseManagerPlugin.logger.info("\(self.t)断开数据库连接: \(config.name)")
            }
        }
        await manager.disconnect(configId: config.id)
        isConnected = false
        selectedConfig = nil
        connectedConfigId = nil
        queryResult = nil
        redisKeys = []
        sqliteTables = []
        selectedSQLiteTable = nil
        schemaCache.invalidate(configId: config.id)
        // 显式断开后，下次不再自动重连这个连接
        DatabaseConnectionStore.lastSelectedConfigID = nil
    }

    public func executeQuery() async {
        guard let config = selectedConfig, let connection = await manager.getConnection(for: config.id) else {
            errorMessage = "未连接到数据库"
            if DatabaseManagerPlugin.verbose {
                            DatabaseManagerPlugin.logger.error("\(self.t)执行查询失败: 未连接到数据库")
            }
            return
        }

        if Self.verbose {
            if DatabaseManagerPlugin.verbose {
                            DatabaseManagerPlugin.logger.info("\(self.t)执行查询: \(self.queryText.prefix(50))...")
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            let upper = queryText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if selectedConfig?.type == .redis {
                // Redis：GET/SCAN 类命令走 query，其余走 execute
                if upper.hasPrefix("GET") || upper.hasPrefix("SCAN") || upper.hasPrefix("HGET") || upper.hasPrefix("LRANGE") || upper.hasPrefix("SMEMBERS") || upper.hasPrefix("ZRANGE") {
                    let result = try await connection.query(queryText, params: nil)
                    queryResult = result
                } else {
                    let affected = try await connection.execute(queryText, params: nil)
                    queryResult = QueryResult(columns: ["Result"], rows: [[.string("Success. Rows affected: \(affected)")]], rowsAffected: affected)
                }
            } else {
                // SQL：SELECT/PRAGMA 走 query，其余走 execute
                if upper.hasPrefix("SELECT") || upper.hasPrefix("PRAGMA") || upper.hasPrefix("SHOW") || upper.hasPrefix("DESCRIBE") {
                    let result = try await connection.query(queryText, params: nil)
                    queryResult = result
                    if Self.verbose {
                        if DatabaseManagerPlugin.verbose {
                                                    DatabaseManagerPlugin.logger.info("\(self.t)查询成功，返回 \(result.rows.count) 行")
                        }
                    }
                } else {
                    let affected = try await connection.execute(queryText, params: nil)
                    queryResult = QueryResult(columns: ["Result"], rows: [[.string("Success. Rows affected: \(affected)")]], rowsAffected: affected)
                    if Self.verbose {
                        if DatabaseManagerPlugin.verbose {
                                                    DatabaseManagerPlugin.logger.info("\(self.t)执行成功，影响 \(affected) 行")
                        }
                    }
                }
            }
        } catch {
            if DatabaseManagerPlugin.verbose {
                            DatabaseManagerPlugin.logger.error("\(self.t)查询执行失败: \(error.localizedDescription)")
            }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    /// 加载 Redis 键列表（循环 SCAN 直到游标归零，带安全上限避免巨型键空间卡死）。
    public func loadRedisKeys() async {
        guard let config = selectedConfig, config.type == .redis else { return }
        guard let connection = await manager.getConnection(for: config.id) else { return }
        guard let redis = connection as? RedisConnection else {
            errorMessage = "Redis 连接类型异常"
            return
        }
        do {
            var cursor = "0"
            var keys: [String] = []
            /// 单次加载的安全上限，避免在生产键空间（数百万键）里无止境扫描。
            let safetyCap = 10_000
            repeat {
                let step = try await redis.scanKeys(cursor: cursor, match: "*", count: 200)
                keys.append(contentsOf: step.keys)
                cursor = step.nextCursor
            } while cursor != "0" && keys.count < safetyCap
            redisKeys = keys
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 打开指定 Redis 键（设置查询并执行 GET）
    public func openRedisKey(_ key: String) async {
        queryText = "GET \(key)"
        await executeQuery()
    }
    
    /// 加载 SQLite 表列表
    public func loadSQLiteTables() async {
        guard let config = selectedConfig, config.type == .sqlite else { return }
        guard let connection = await manager.getConnection(for: config.id) else { return }
        do {
            let result = try await connection.query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;", params: nil)
            let names = result.rows.compactMap { row -> String? in
                if let first = row.first {
                    switch first {
                    case .string(let s): return s
                    default: return first.description
                    }
                }
                return nil
            }
            sqliteTables = names
            if let selectedSQLiteTable, !names.contains(selectedSQLiteTable) {
                self.selectedSQLiteTable = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 打开指定 SQLite 表
    public func openSQLiteTable(_ name: String) async {
        selectedSQLiteTable = name
        queryText = "SELECT * FROM \(quotedSQLiteIdentifier(name)) LIMIT 50;"
        await executeQuery()
    }

    private func quotedSQLiteIdentifier(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    
    private func initDemoData(configId: UUID) async throws {
        guard let connection = await manager.getConnection(for: configId) else { return }
        _ = try await connection.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, email TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: [.string("Alice"), .string("alice@example.com")])
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: [.string("Bob"), .string("bob@example.com")])
    }
}
