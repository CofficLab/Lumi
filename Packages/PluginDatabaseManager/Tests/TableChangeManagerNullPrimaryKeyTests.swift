import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 可空主键的 NULL 比较（回归 #568）。
///
/// SQLite 允许部分普通 PRIMARY KEY 列含 NULL（如未声明 NOT NULL 的 TEXT PRIMARY KEY）。
/// 旧实现对每个主键值都生成 `pk = 字面量`，NULL 主键变成 `pk = NULL`——SQL 里永不成立，
/// UPDATE/DELETE 命中 0 行，保存却报成功并清空暂存，编辑/删除静默失效。
/// 修复：NULL 主键用 `IS NULL`，非 NULL 仍用 `=`；保存时校验行级写入的影响行数，
/// 命中 0 行回滚并报错，不再假装成功。
@MainActor
@Suite("可空主键的 NULL 比较")
struct TableChangeManagerNullPrimaryKeyTests {

    private func makeManager(_ columns: [(name: String, type: String, pk: Bool)]) -> TableChangeManager {
        let table = DatabaseObject(kind: .table, name: "notes", schema: nil)
        let cols = columns.enumerated().map { idx, c in
            TableColumn(
                name: c.name,
                dataType: c.type,
                isNullable: true,
                isPrimaryKey: c.pk,
                defaultValue: nil,
                position: idx
            )
        }
        return TableChangeManager(table: table, schema: TableSchema(table: table, columns: cols))
    }

    private func notesManager() -> TableChangeManager {
        makeManager([(name: "id", type: "TEXT", pk: true), (name: "body", type: "TEXT", pk: false)])
    }

    // MARK: - SQL 生成

    @Test("NULL 主键的 UPDATE 用 IS NULL 而非 = NULL")
    func nullPrimaryKeyUpdateUsesIsNull() {
        let cm = notesManager()
        cm.stageCellUpdate(
            column: "body",
            newValue: .string("after"),
            rowValues: [.null, .string("before")],
            columns: ["id", "body"]
        )
        #expect(cm.generatedUpdateStatements(for: .sqlite) == ["UPDATE \"notes\" SET \"body\" = 'after' WHERE \"id\" IS NULL;"])
    }

    @Test("NULL 主键的 DELETE 用 IS NULL 而非 = NULL")
    func nullPrimaryKeyDeleteUsesIsNull() {
        let cm = notesManager()
        cm.toggleRowDeletion(rowValues: [.null, .string("before")], columns: ["id", "body"])
        #expect(cm.generatedDeleteStatements(for: .sqlite) == ["DELETE FROM \"notes\" WHERE \"id\" IS NULL;"])
    }

    @Test("非 NULL 主键仍用 = 字面量，不被改成 IS NULL")
    func nonNullPrimaryKeyStillUsesEquals() {
        let cm = notesManager()
        cm.stageCellUpdate(
            column: "body",
            newValue: .string("after"),
            rowValues: [.string("k1"), .string("b1")],
            columns: ["id", "body"]
        )
        cm.toggleRowDeletion(rowValues: [.string("k2"), .string("b2")], columns: ["id", "body"])
        #expect(cm.generatedUpdateStatements(for: .sqlite) == ["UPDATE \"notes\" SET \"body\" = 'after' WHERE \"id\" = 'k1';"])
        #expect(cm.generatedDeleteStatements(for: .sqlite) == ["DELETE FROM \"notes\" WHERE \"id\" = 'k2';"])
    }

    @Test("复合主键按值混用 IS NULL 与 =，且方言引号正确")
    func compositePrimaryKeyMixesNullAndEquals() {
        let cm = makeManager([
            (name: "a", type: "TEXT", pk: true),
            (name: "b", type: "TEXT", pk: true),
            (name: "val", type: "TEXT", pk: false),
        ])
        cm.stageCellUpdate(
            column: "val",
            newValue: .string("new"),
            rowValues: [.null, .string("x"), .string("old")],
            columns: ["a", "b", "val"]
        )
        #expect(cm.generatedUpdateStatements(for: .sqlite) == ["UPDATE \"notes\" SET \"val\" = 'new' WHERE \"a\" IS NULL AND \"b\" = 'x';"])
        #expect(cm.generatedUpdateStatements(for: .mysql) == ["UPDATE `notes` SET `val` = 'new' WHERE `a` IS NULL AND `b` = 'x';"])
    }

    @Test("行级写入判定只认 UPDATE/DELETE，INSERT/SELECT 不算")
    func isRowTargetingWriteDetectsUpdateAndDelete() {
        #expect(DatabaseViewModel.isRowTargetingWrite("UPDATE t SET x = 1 WHERE id IS NULL;"))
        #expect(DatabaseViewModel.isRowTargetingWrite("DELETE FROM t WHERE id IS NULL;"))
        #expect(DatabaseViewModel.isRowTargetingWrite("  update t set x = 1"))
        #expect(!DatabaseViewModel.isRowTargetingWrite("INSERT INTO t DEFAULT VALUES;"))
        #expect(!DatabaseViewModel.isRowTargetingWrite("SELECT * FROM t"))
    }

    // MARK: - SQLite 端到端

    @Test("NULL 主键行的 UPDATE 在真实 SQLite 上命中并修改该行")
    func nullPrimaryKeyUpdateActuallyModifiesRow() async throws {
        let path = NSTemporaryDirectory() + "/lumi-nullpk-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let connection = try await SQLiteDriver().connect(config: DatabaseConfig(name: "NullPK", type: .sqlite, database: path))
        _ = try await connection.execute("CREATE TABLE notes(id TEXT PRIMARY KEY, body TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO notes VALUES (NULL, 'before')", params: nil)

        let cm = notesManager()
        cm.stageCellUpdate(
            column: "body",
            newValue: .string("after"),
            rowValues: [.null, .string("before")],
            columns: ["id", "body"]
        )
        for sql in cm.generatedUpdateStatements(for: .sqlite) {
            let affected = try await connection.execute(sql, params: nil)
            #expect(affected == 1)
        }
        let result = try await connection.query("SELECT body FROM notes", params: nil)
        #expect(result.rows == [[.string("after")]])
        await connection.close()
    }

    @Test("NULL 主键行的 DELETE 在真实 SQLite 上命中并删除该行")
    func nullPrimaryKeyDeleteActuallyRemovesRow() async throws {
        let path = NSTemporaryDirectory() + "/lumi-nullpk-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let connection = try await SQLiteDriver().connect(config: DatabaseConfig(name: "NullPK", type: .sqlite, database: path))
        _ = try await connection.execute("CREATE TABLE notes(id TEXT PRIMARY KEY, body TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO notes VALUES (NULL, 'before')", params: nil)

        let cm = notesManager()
        cm.toggleRowDeletion(rowValues: [.null, .string("before")], columns: ["id", "body"])
        for sql in cm.generatedDeleteStatements(for: .sqlite) {
            let affected = try await connection.execute(sql, params: nil)
            #expect(affected == 1)
        }
        let count = try await connection.query("SELECT count(*) FROM notes", params: nil)
        #expect(count.rows.first?.first == .integer(0))
        await connection.close()
    }

    // MARK: - 保存影响行数守卫

    @Test("行级写入命中 0 行时回滚并报错，不清空暂存")
    func saveRollsBackWhenRowWriteAffectsNoRows() async throws {
        let (viewModel, transaction) = try await makeSaveSUT(affected: 0)
        await viewModel.saveChanges()
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.changeManager?.hasChanges == true)
        let rolledBack = await transaction.rolledBack
        let committed = await transaction.committed
        #expect(rolledBack)
        #expect(!committed)
    }

    @Test("行级写入命中 1 行时正常提交并清空暂存")
    func saveSucceedsWhenRowWriteAffectsOneRow() async throws {
        let (viewModel, transaction) = try await makeSaveSUT(affected: 1)
        await viewModel.saveChanges()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.changeManager?.hasChanges == false)
        let committed = await transaction.committed
        let rolledBack = await transaction.rolledBack
        #expect(committed)
        #expect(!rolledBack)
    }

    private func makeSaveSUT(affected: Int) async throws -> (DatabaseViewModel, SaveGuardTransaction) {
        let transaction = SaveGuardTransaction(affected: affected)
        let connection = SaveGuardConnection(transaction: transaction)
        let manager = DatabaseManagerCore()
        await manager.register(driver: SaveGuardDriver(type: .sqlite, connection: connection))
        let config = DatabaseConfig(name: "save-guard", type: .sqlite, database: "save-guard")
        _ = try await manager.connect(config: config)

        let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: manager)
        viewModel.selectedConfig = config
        let cm = notesManager()
        cm.stageCellUpdate(
            column: "body",
            newValue: .string("after"),
            rowValues: [.null, .string("before")],
            columns: ["id", "body"]
        )
        viewModel.changeManager = cm
        return (viewModel, transaction)
    }
}

// MARK: - 保存守卫假件

/// 影响行数可控的事务，记录提交/回滚与下发 SQL。
private actor SaveGuardTransaction: DatabaseTransaction {
    private let affected: Int
    private(set) var executedSQL: [String] = []
    private(set) var rolledBack = false
    private(set) var committed = false

    init(affected: Int) { self.affected = affected }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        executedSQL.append(sql)
        return affected
    }
    func commit() async throws { committed = true }
    func rollback() async throws { rolledBack = true }
}

private actor SaveGuardConnection: DatabaseConnection {
    private let transaction: SaveGuardTransaction
    init(transaction: SaveGuardTransaction) { self.transaction = transaction }
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: 0)
    }
    func beginTransaction() async throws -> any DatabaseTransaction { transaction }
    func close() async {}
    func isAlive() async -> Bool { true }
}

private actor SaveGuardDriver: DatabaseDriver {
    nonisolated let type: DatabaseType
    private let connection: SaveGuardConnection
    init(type: DatabaseType, connection: SaveGuardConnection) {
        self.type = type
        self.connection = connection
    }
    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection { connection }
}