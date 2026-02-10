import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class DatabaseViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🗄️"
    nonisolated static let verbose = false

    @Published var configs: [DatabaseConfig] = []
    @Published var selectedConfig: DatabaseConfig?
    @Published var queryText: String = "SELECT * FROM sqlite_master;"
    @Published var queryResult: QueryResult?
    @Published var errorMessage: String?
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false

    private let manager = DatabaseManager.shared

    init() {
        if Self.verbose {
            os_log("\(Self.t)初始化数据库视图模型")
        }
        // Load mock config
        configs.append(DatabaseConfig(name: "Demo SQLite", type: .sqlite, database: ":memory:")) // In-memory DB
    }
    
    func connect(config: DatabaseConfig) async {
        if Self.verbose {
            os_log("\(self.t)连接数据库: \(config.name)")
        }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await manager.connect(config: config)
            selectedConfig = config
            isConnected = true

            if Self.verbose {
                os_log("\(self.t)数据库连接成功: \(config.name)")
            }

            // Create some demo data if in-memory
            if config.database == ":memory:" {
                try await initDemoData(configId: config.id)
            }
        } catch {
            os_log(.error, "\(self.t)数据库连接失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func disconnect() async {
        guard let config = selectedConfig else { return }
        if Self.verbose {
            os_log("\(self.t)断开数据库连接: \(config.name)")
        }
        await manager.disconnect(configId: config.id)
        isConnected = false
        selectedConfig = nil
        queryResult = nil
    }

    func executeQuery() async {
        guard let config = selectedConfig, let connection = await manager.getConnection(for: config.id) else {
            errorMessage = "未连接到数据库"
            os_log(.error, "\(self.t)执行查询失败: 未连接到数据库")
            return
        }

        if Self.verbose {
            os_log("\(self.t)执行查询: \(self.queryText.prefix(50))...")
        }

        isLoading = true
        errorMessage = nil

        do {
            if queryText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("SELECT") ||
               queryText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("PRAGMA") {
                let result = try await connection.query(queryText, params: nil)
                queryResult = result
                if Self.verbose {
                    os_log("\(self.t)查询成功，返回 \(result.rows.count) 行")
                }
            } else {
                let affected = try await connection.execute(queryText, params: nil)
                queryResult = QueryResult(columns: ["Result"], rows: [[.string("Success. Rows affected: \(affected)")]], rowsAffected: affected)
                if Self.verbose {
                    os_log("\(self.t)执行成功，影响 \(affected) 行")
                }
            }
        } catch {
            os_log(.error, "\(self.t)查询执行失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func initDemoData(configId: UUID) async throws {
        guard let connection = await manager.getConnection(for: configId) else { return }
        _ = try await connection.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, email TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: [.string("Alice"), .string("alice@example.com")])
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: [.string("Bob"), .string("bob@example.com")])
    }
}
