import Foundation

/// 查询历史持久化存储。
///
/// - 内存中保留最近的 N 条（默认 500）；
/// - 写入 `UserDefaults`，按 (sql, configName, database) 去重，最新在前；
/// - **绝不记录** 含 `CREATE USER` / `ALTER USER` / `SET PASSWORD` 等敏感语句
///   （与 TablePro 一致，避免密码落盘）；
/// - 多语句执行时，每条语句独立记入历史。
public actor QueryHistoryStore {
    public static let shared = QueryHistoryStore()

    private let defaultsKey = "DatabaseManager.queryHistory"
    private let maxEntries = 500

    private var cache: [QueryHistoryEntry] = []

    public init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([QueryHistoryEntry].self, from: data) {
            cache = decoded
        }
    }

    // MARK: - Public

    /// 记录一条 SQL（trim 后非空才写入）。重复的 (sql, config, database) 去重，时间戳刷新。
    public func record(sql: String, configName: String, database: String) {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !Self.containsSensitiveContent(trimmed) else { return }

        cache.removeAll {
            $0.sql == trimmed && $0.configName == configName && $0.database == database
        }
        cache.insert(
            QueryHistoryEntry(sql: trimmed, configName: configName, database: database),
            at: 0
        )
        if cache.count > maxEntries {
            cache = Array(cache.prefix(maxEntries))
        }
        persist()
    }

    /// 最近 N 条（按时间倒序）。
    public func recent(limit: Int) -> [QueryHistoryEntry] {
        Array(cache.prefix(max(1, limit)))
    }

    /// 子串匹配：sql、连接名、数据库名任一包含即命中（大小写不敏感）。
    public func search(_ query: String) -> [QueryHistoryEntry] {
        let q = query.lowercased()
        guard !q.isEmpty else { return cache }
        return cache.filter {
            $0.sql.lowercased().contains(q) ||
            $0.configName.lowercased().contains(q) ||
            $0.database.lowercased().contains(q)
        }
    }

    public func delete(id: UUID) {
        cache.removeAll { $0.id == id }
        persist()
    }

    public func clear() {
        cache.removeAll()
        persist()
    }

    // MARK: - Private

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// 识别含用户密码操作的语句（保守匹配）。
    private static func containsSensitiveContent(_ sql: String) -> Bool {
        let upper = sql.uppercased()
        let patterns = ["CREATE USER", "ALTER USER", "DROP USER", "SET PASSWORD", "IDENTIFIED BY", "CREATE ROLE", "ALTER ROLE"]
        return patterns.contains { upper.contains($0) }
    }
}
