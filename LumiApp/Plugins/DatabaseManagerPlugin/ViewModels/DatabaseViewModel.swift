import Foundation
import Combine
import MagicKit

@MainActor
class DatabaseViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🗄️"
    nonisolated static let verbose: Bool = false
    @Published var configs: [DatabaseConfig] = []
    @Published var selectedConfig: DatabaseConfig?
    @Published var queryText: String = "SELECT * FROM sqlite_master;"
    @Published var queryResult: QueryResult?
    @Published var errorMessage: String?
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var redisKeys: [String] = []
    @Published var sqliteTables: [String] = []

    private let manager = DatabaseManager.shared

    init() {
        if Self.verbose {
            DatabaseManagerPlugin.logger.info("\(Self.t)初始化数据库视图模型")
        }
        // Load mock config
        configs.append(DatabaseConfig(name: "Demo SQLite", type: .sqlite, database: ":memory:")) // In-memory DB
    }
    
    func connect(config: DatabaseConfig) async {
        if Self.verbose {
            DatabaseManagerPlugin.logger.info("\(self.t)连接数据库: \(config.name)")
        }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await manager.connect(config: config)
            selectedConfig = config
            isConnected = true
            
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
                await loadSQLiteTables()
            }

            if Self.verbose {
                DatabaseManagerPlugin.logger.info("\(self.t)数据库连接成功: \(config.name)")
            }

            // Create some demo data if in-memory
            if config.database == ":memory:" {
                try await initDemoData(configId: config.id)
            }
        } catch {
            DatabaseManagerPlugin.logger.error("\(self.t)数据库连接失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func disconnect() async {
        guard let config = selectedConfig else { return }
        if Self.verbose {
            DatabaseManagerPlugin.logger.info("\(self.t)断开数据库连接: \(config.name)")
        }
        await manager.disconnect(configId: config.id)
        isConnected = false
        selectedConfig = nil
        queryResult = nil
    }

    func executeQuery() async {
        guard let config = selectedConfig, let connection = await manager.getConnection(for: config.id) else {
            errorMessage = "未连接到数据库"
            DatabaseManagerPlugin.logger.error("\(self.t)执行查询失败: 未连接到数据库")
            return
        }

        if Self.verbose {
            DatabaseManagerPlugin.logger.info("\(self.t)执行查询: \(self.queryText.prefix(50))...")
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
                        DatabaseManagerPlugin.logger.info("\(self.t)查询成功，返回 \(result.rows.count) 行")
                    }
                } else {
                    let affected = try await connection.execute(queryText, params: nil)
                    queryResult = QueryResult(columns: ["Result"], rows: [[.string("Success. Rows affected: \(affected)")]], rowsAffected: affected)
                    if Self.verbose {
                        DatabaseManagerPlugin.logger.info("\(self.t)执行成功，影响 \(affected) 行")
                    }
                }
            }
        } catch {
            DatabaseManagerPlugin.logger.error("\(self.t)查询执行失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    /// 加载 Redis 键列表（使用 SCAN 分段加载的简化版）
    func loadRedisKeys() async {
        guard let config = selectedConfig, config.type == .redis else { return }
        guard let connection = await manager.getConnection(for: config.id) else { return }
        do {
            let result = try await connection.query("SCAN 0 MATCH * COUNT 100", params: nil)
            // rows 是 [["key1"], ["key2"], ...]
            let keys = result.rows.compactMap { row -> String? in
                if let first = row.first {
                    switch first {
                    case .string(let s): return s
                    default: return first.description
                    }
                }
                return nil
            }
            redisKeys = keys
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 打开指定 Redis 键（设置查询并执行 GET）
    func openRedisKey(_ key: String) async {
        queryText = "GET \(key)"
        await executeQuery()
    }
    
    /// 加载 SQLite 表列表
    func loadSQLiteTables() async {
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 打开指定 SQLite 表
    func openSQLiteTable(_ name: String) async {
        queryText = "SELECT * FROM \"\(name)\" LIMIT 50;"
        await executeQuery()
    }
    
    private func initDemoData(configId: UUID) async throws {
        guard let connection = await manager.getConnection(for: configId) else { return }
        _ = try await connection.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, email TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: [.string("Alice"), .string("alice@example.com")])
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: [.string("Bob"), .string("bob@example.com")])
    }
}
