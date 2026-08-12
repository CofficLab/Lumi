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

    // MARK: - 表浏览状态（统一分页）

    /// 当前在主区打开的表/视图对象；nil 表示未打开（显示 SQL 编辑器）。
    @Published public var openTableObject: DatabaseObject?
    /// 当前页码（从 0 起）。
    @Published public var tablePage: Int = 0
    /// 每页行数。
    @Published public var tablePageSize: Int = 100
    /// 表的总行数（精确 COUNT，后台异步填充；nil 表示未知）。
    @Published public var tableRowCount: Int?
    /// 服务端排序（列名 + 方向）；nil 表示不排序。
    @Published public var tableOrderBy: (column: String, ascending: Bool)?

    /// 当前打开表的变更跟踪队列；无主键或未打开表时为 nil（不可编辑）。
    @Published public var changeManager: TableChangeManager?
    /// 是否正在展示「Preview SQL」面板。
    @Published public var showChangePreview: Bool = false

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

            // 为侧边栏对象树预加载可见分类（表/视图/例程），MySQL/PG 由此不再空白。
            await refreshSidebarObjects()

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

    /// 加载当前连接在侧边栏可见的对象分类（表/视图/例程…），结果写入 ``schemaCache``。
    /// MySQL/PG 首次连接后侧边栏不再为空，全靠这里填充。
    public func refreshSidebarObjects() async {
        guard let config = selectedConfig, config.type != .redis else { return }
        guard let connection = await manager.getConnection(for: config.id) else { return }
        let database: String? = config.type == .sqlite ? nil : config.database
        for kind in config.type.sidebarObjectKinds {
            _ = try? await schemaCache.objects(
                for: config,
                kind: kind,
                database: database,
                schema: nil,
                connection: connection
            )
        }
    }

    /// 统一打开一个数据库对象。表/视图进入分页浏览主区；其它对象暂不处理。
    public func openObject(_ object: DatabaseObject) async {
        guard let config = selectedConfig else { return }
        switch object.kind {
        case .table, .view, .materializedView:
            openTableObject = object
            tablePage = 0
            tableRowCount = nil
            tableOrderBy = nil
            changeManager = nil
            // 兼容旧 UI（空状态判断等）
            if config.type == .sqlite { selectedSQLiteTable = object.name }
            // 加载表结构以建立变更跟踪（需要主键）
            if let connection = await manager.getConnection(for: config.id),
               let schema = try? await schemaCache.tableSchema(for: object, config: config, connection: connection) {
                changeManager = TableChangeManager(table: object, schema: schema)
            }
            await loadTablePage()
        case .procedure, .function, .index, .trigger:
            // 例程/索引/触发器暂不在主区打开（留给后续结构 Tab）
            break
        }
    }

    /// 关闭表浏览，回到 SQL 编辑器。
    public func closeTableBrowser() {
        openTableObject = nil
        tableRowCount = nil
        queryResult = nil
    }

    /// 从表浏览切到 SQL 编辑器，但保留当前 queryText/queryResult（让用户可基于浏览语句继续编辑）。
    public func switchToQueryEditor() {
        openTableObject = nil
    }

    /// 加载当前页数据（`SELECT * FROM ... [ORDER BY ...] LIMIT pageSize OFFSET page*pageSize`）。
    /// 页码超出范围时自动钳制到最后一页。
    public func loadTablePage() async {
        guard let config = selectedConfig, let table = openTableObject else { return }
        guard config.type.capabilities.supportsPagination else { return }
        guard let connection = await manager.getConnection(for: config.id) else {
            errorMessage = "未连接到数据库"
            return
        }

        let tableExpr = Self.qualifiedName(for: table, type: config.type)
        var sql = "SELECT * FROM \(tableExpr)"
        if let order = tableOrderBy {
            let col = Self.quoteIdentifier(order.column, for: config.type)
            sql += " ORDER BY \(col) \(order.ascending ? "ASC" : "DESC")"
        }
        let offset = tablePage * tablePageSize
        sql += " LIMIT \(tablePageSize) OFFSET \(offset)"

        isLoading = true
        errorMessage = nil
        do {
            let result = try await connection.query(sql, params: nil)
            queryResult = result
            // 如果本页空且不是首页，回退到上一页（例如删除后）
            if result.rows.isEmpty, tablePage > 0 {
                tablePage = max(0, tablePage - 1)
                await loadTablePage()
                isLoading = false
                return
            }
            queryText = sql  // 让 SQL 编辑器可见当前浏览语句
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        // 后台拉取精确行数（不阻塞页面展示）
        if tableRowCount == nil {
            Task { await refreshTableRowCount() }
        }
    }

    /// 后台执行 `SELECT COUNT(*) FROM ...` 填充 ``tableRowCount``。
    public func refreshTableRowCount() async {
        guard let config = selectedConfig, let table = openTableObject else { return }
        guard config.type.capabilities.supportsPagination else { return }
        guard let connection = await manager.getConnection(for: config.id) else { return }
        let tableExpr = Self.qualifiedName(for: table, type: config.type)
        do {
            let result = try await connection.query("SELECT COUNT(*) FROM \(tableExpr)", params: nil)
            if let row = result.rows.first, let first = row.first {
                switch first {
                case .integer(let v): tableRowCount = v
                case .double(let v): tableRowCount = Int(v)
                case .string(let s): tableRowCount = Int(s)
                default: break
                }
            }
        } catch {
            // 行数查询失败不影响浏览
        }
    }

    public func nextPage() async {
        tablePage += 1
        await loadTablePage()
    }

    public func prevPage() async {
        guard tablePage > 0 else { return }
        tablePage -= 1
        await loadTablePage()
    }

    public func setPageSize(_ size: Int) async {
        tablePageSize = max(1, size)
        tablePage = 0
        await loadTablePage()
    }

    /// 点击表头排序：同一列循环 升→降→关。
    public func toggleSort(column: String) async {
        if let current = tableOrderBy, current.column == column {
            if current.ascending { tableOrderBy = (column, false) }
            else { tableOrderBy = nil }
        } else {
            tableOrderBy = (column, true)
        }
        tablePage = 0
        await loadTablePage()
    }

    // MARK: - 数据编辑（变更跟踪）

    /// 暂存一个单元格修改到变更队列。
    public func stageCellChange(column: String, newValue: DatabaseValue, rowValues: [DatabaseValue], columns: [String]) {
        changeManager?.stageCellUpdate(column: column, newValue: newValue, rowValues: rowValues, columns: columns)
        // changeManager 自身的 objectWillChange 不会传导到观察本 viewModel 的视图，手动通知。
        objectWillChange.send()
    }

    /// 暂存新增行的某列值。
    public func stageInsertCell(insertId: UUID, column: String, value: DatabaseValue) {
        changeManager?.setInsertColumn(insertId: insertId, column: column, value: value)
        objectWillChange.send()
    }

    /// 新增一个空行（返回临时 id）。
    @discardableResult
    public func addRow() -> UUID? {
        guard let id = changeManager?.addInsert() else { return nil }
        objectWillChange.send()
        return id
    }

    /// 移除一个未保存的新增行。
    public func removePendingInsert(_ insertId: UUID) {
        changeManager?.removeInsert(insertId)
        objectWillChange.send()
    }

    /// 切换某行的删除标记。
    public func toggleRowDeletion(rowValues: [DatabaseValue], columns: [String]) {
        changeManager?.toggleRowDeletion(rowValues: rowValues, columns: columns)
        objectWillChange.send()
    }

    public func undoChange() {
        changeManager?.undo()
        objectWillChange.send()
    }

    public func redoChange() {
        changeManager?.redo()
        objectWillChange.send()
    }

    /// 丢弃所有未保存的单元格修改。
    public func discardChanges() {
        changeManager?.discardAll()
        objectWillChange.send()
    }

    /// 当前待提交的 SQL 语句（DELETE → INSERT → UPDATE）。
    public var pendingChangeSQL: [String] {
        guard let config = selectedConfig, let cm = changeManager else { return [] }
        return cm.generatedAllStatements(for: config.type)
    }

    /// 在事务中应用全部待提交变更，成功后清空队列并刷新当前页。
    public func saveChanges() async {
        guard let config = selectedConfig, let cm = changeManager, cm.hasChanges else { return }
        guard let connection = await manager.getConnection(for: config.id) else {
            errorMessage = "未连接到数据库"
            return
        }
        let statements = cm.generatedAllStatements(for: config.type)
        isLoading = true
        errorMessage = nil
        do {
            let tx = try await connection.beginTransaction()
            do {
                for sql in statements {
                    _ = try await tx.execute(sql, params: nil)
                }
                try await tx.commit()
            } catch {
                try? await tx.rollback()
                throw error
            }
            cm.discardAll()
            objectWillChange.send()
            await loadTablePage()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// 按方言引用单个标识符（SQLite/PG 用双引号，MySQL 用反引号）。
    public nonisolated static func quoteIdentifier(_ name: String, for type: DatabaseType) -> String {
        guard let quote = type.capabilities.identifierQuoteCharacter else { return name }
        let escaped = name.replacingOccurrences(of: String(quote), with: String(quote) + String(quote))
        return "\(quote)\(escaped)\(quote)"
    }

    /// 构造带库/schema 限定的表名（MySQL: `db`.`t`；PG: "schema"."t"；SQLite: "t"）。
    public nonisolated static func qualifiedName(for object: DatabaseObject, type: DatabaseType) -> String {
        func q(_ s: String) -> String { quoteIdentifier(s, for: type) }
        switch type {
        case .mysql:
            if let db = object.database, !db.isEmpty { return "\(q(db)).\(q(object.name))" }
            return q(object.name)
        case .postgresql:
            if let schema = object.schema, !schema.isEmpty { return "\(q(schema)).\(q(object.name))" }
            return q(object.name)
        case .sqlite, .redis:
            return q(object.name)
        }
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
