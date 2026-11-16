@testable import DatabaseManagerPlugin
import Foundation
import Testing

/// 结构变更与未保存数据编辑的冲突（回归 #583）。
///
/// ## 回归背景
///
/// 数据页有未保存编辑时，`saveSchemaChanges` 应用 DDL 后虽刷新了结构，却因
/// `changeManager?.hasChanges == true` 跳过重建数据变更管理器，使其继续持有旧列快照。
/// 之后保存数据编辑会生成引用已重命名/删除列的 SQL（如 `UPDATE "t" SET "name" = ...`），
/// 数据库报 `no such column`，编辑无法提交。修复：结构变更若重命名/删除了暂存数据编辑
/// 所引用的列，明确阻止并要求用户先保存/放弃数据编辑，绝不静默用旧 schema 生成必失败的 SQL。
@MainActor
@Suite(.serialized)
struct DatabaseViewModelSchemaChangeConflictTests {

    private let columns = ["id", "name", "body"]
    private func row(_ id: Int, _ name: String, _ body: String) -> [DatabaseValue] {
        [.integer(id), .string(name), .string(body)]
    }

    private func makeSchema() -> (DatabaseObject, TableSchema) {
        let table = DatabaseObject(kind: .table, name: "t", schema: nil)
        let cols = [
            TableColumn(name: "id", dataType: "integer", isNullable: false, isPrimaryKey: true, defaultValue: nil, position: 0),
            TableColumn(name: "name", dataType: "text", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 1),
            TableColumn(name: "body", dataType: "text", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 2),
        ]
        return (table, TableSchema(table: table, columns: cols))
    }

    /// 真实 SQLite 临时库：先独立建表 seeding，再让 viewModel 连接同一文件，
    /// 避免 viewModel.connect 二次连接关闭用于探针的连接。
    private func makeSUT() async throws -> (
        viewModel: DatabaseViewModel,
        connection: any DatabaseConnection,
        config: DatabaseConfig,
        path: String
    ) {
        let path = NSTemporaryDirectory() + "/lumi-583-\(UUID().uuidString).sqlite"
        let config = DatabaseConfig(name: "583", type: .sqlite, database: path)
        let seed = try await SQLiteDriver().connect(config: config)
        _ = try await seed.execute("CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT, body TEXT)", params: nil)
        _ = try await seed.execute("INSERT INTO t(id,name,body) VALUES(1,'Alice','x')", params: nil)
        await seed.close()

        let manager = DatabaseManagerCore()
        // 直接注册驱动，不走全局 bootstrap 去重：其 registered 集合按 ObjectIdentifier
        // 记录且永不剔除，前一个测试的 manager 释放后地址被复用时，新 manager 会被误判
        // 「已注册」而拿不到任何驱动，connect 抛错使连接为空（偶发崩溃）。register 幂等。
        await manager.register(driver: SQLiteDriver())
        let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: manager)
        await viewModel.connect(config: config)
        await viewModel.openObject(DatabaseObject(kind: .table, name: "t", schema: nil))
        guard let connection = await manager.getConnection(for: config.id) else {
            throw DatabaseError.connectionFailed("makeSUT: viewModel.connect 未建立连接")
        }
        return (viewModel, connection, config, path)
    }

    private func nameColumn(_ viewModel: DatabaseViewModel) -> TableColumn {
        viewModel.schemaChangeManager!.originalColumns.first { $0.name == "name" }!
    }

    // MARK: - referencedColumnNames 纯单元测试

    @Test("referencedColumnNames 汇集 UPDATE/INSERT/DELETE 引用的列与主键")
    func referencedColumnNamesCollectsUpdateInsertDeleteColumns() {
        let (table, schema) = makeSchema()
        let manager = TableChangeManager(table: table, schema: schema)

        manager.stageCellUpdate(column: "name", newValue: .string("Bob"), rowValues: row(1, "Alice", "x"), columns: columns)
        let insertId = manager.addInsert()
        manager.setInsertColumn(insertId: insertId, column: "body", value: .string("z"))
        manager.toggleRowDeletion(rowValues: row(2, "Carol", "y"), columns: columns)

        // UPDATE 引用 name + 主键 id；INSERT 引用 body；DELETE 引用主键 id。
        #expect(manager.referencedColumnNames == Set(["id", "name", "body"]))
    }

    // MARK: - 端到端：阻止会失效的结构变更

    @Test("重命名仍有未保存编辑的列被阻止，DDL 不执行（回归 #583）")
    func renameOfColumnWithPendingEditIsBlocked() async throws {
        let (viewModel, connection, _, path) = try await makeSUT()
        defer { try? FileManager.default.removeItem(atPath: path) }

        viewModel.changeManager?.stageCellUpdate(column: "name", newValue: .string("Bob"), rowValues: row(1, "Alice", "x"), columns: columns)
        #expect(viewModel.changeManager?.hasChanges == true)
        try viewModel.stageRenameColumn(nameColumn(viewModel), to: "title")

        await viewModel.saveSchemaChanges()

        #expect(viewModel.tableSchemaError != nil)
        // 结构变更与数据编辑都保留，等待用户先处理数据编辑。
        #expect(viewModel.schemaChangeManager?.hasChanges == true)
        #expect(viewModel.changeManager?.hasChanges == true)
        // DDL 未执行：列仍叫 name，数据未被改写。
        let probe = try await connection.query("SELECT name FROM t WHERE id = 1", params: nil)
        #expect(probe.rows.first?.first == .string("Alice"))
    }

    @Test("删除仍有未保存编辑的列被阻止，DDL 不执行（回归 #583）")
    func dropOfColumnWithPendingEditIsBlocked() async throws {
        let (viewModel, connection, _, path) = try await makeSUT()
        defer { try? FileManager.default.removeItem(atPath: path) }

        viewModel.changeManager?.stageCellUpdate(column: "name", newValue: .string("Bob"), rowValues: row(1, "Alice", "x"), columns: columns)
        try viewModel.stageDropColumn(nameColumn(viewModel))

        await viewModel.saveSchemaChanges()

        #expect(viewModel.tableSchemaError != nil)
        #expect(viewModel.schemaChangeManager?.hasChanges == true)
        #expect(viewModel.changeManager?.hasChanges == true)
        let probe = try await connection.query("SELECT name FROM t WHERE id = 1", params: nil)
        #expect(probe.rows.first?.first == .string("Alice"))
    }

    // MARK: - 端到端：不影响数据编辑的结构变更照常进行

    @Test("重命名未被编辑引用的列照常应用，且保留无关数据编辑")
    func renameOfUnreferencedColumnProceedsAndPreservesEdit() async throws {
        let (viewModel, connection, _, path) = try await makeSUT()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // 数据编辑只动 body，重命名 name 不影响它。
        viewModel.changeManager?.stageCellUpdate(column: "body", newValue: .string("y"), rowValues: row(1, "Alice", "x"), columns: columns)
        try viewModel.stageRenameColumn(nameColumn(viewModel), to: "title")

        await viewModel.saveSchemaChanges()

        #expect(viewModel.tableSchemaError == nil)
        #expect(viewModel.schemaChangeManager?.hasChanges == false)
        // 无关数据编辑被保留。
        #expect(viewModel.changeManager?.hasChanges == true)
        // DDL 已执行：列改名为 title。
        let probe = try await connection.query("SELECT title FROM t WHERE id = 1", params: nil)
        #expect(probe.rows.first?.first == .string("Alice"))
    }

    @Test("没有未保存数据编辑时重命名照常应用")
    func renameWithNoPendingDataEditProceeds() async throws {
        let (viewModel, connection, _, path) = try await makeSUT()
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(viewModel.changeManager?.hasChanges == false)
        try viewModel.stageRenameColumn(nameColumn(viewModel), to: "title")

        await viewModel.saveSchemaChanges()

        #expect(viewModel.tableSchemaError == nil)
        #expect(viewModel.schemaChangeManager?.hasChanges == false)
        let probe = try await connection.query("SELECT title FROM t WHERE id = 1", params: nil)
        #expect(probe.rows.first?.first == .string("Alice"))
    }
}