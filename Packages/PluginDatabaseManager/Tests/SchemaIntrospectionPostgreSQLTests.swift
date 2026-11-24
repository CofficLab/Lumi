import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 记录下发 SQL 的假 PostgreSQL 连接：只捕获 query，不做真实网络往返。
private actor RecordingPGConnection: DatabaseConnection {
    private var queries: [String] = []

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        queries.append(sql)
        return QueryResult(columns: ["table_name"], rows: [[.string("users")]], rowsAffected: 0)
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        queries.append(sql)
        return 0
    }

    func beginTransaction() async throws -> any DatabaseTransaction {
        RecordingPGTransaction()
    }

    func close() async {}
    func isAlive() async -> Bool { true }

    func lastQuery() -> String? { queries.last }
}

/// 返回固定结果集的假连接：用于断言 describeTable 的 SQL 分支与列映射。
private actor ScriptedPGConnection: DatabaseConnection {
    private let result: QueryResult
    private var queries: [String] = []

    init(result: QueryResult) {
        self.result = result
    }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        queries.append(sql)
        return result
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        queries.append(sql)
        return 0
    }

    func beginTransaction() async throws -> any DatabaseTransaction {
        RecordingPGTransaction()
    }

    func close() async {}
    func isAlive() async -> Bool { true }

    func allQueries() -> [String] { queries }
}

private struct RecordingPGTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}

@Suite("PostgreSQL 对象列举默认 schema")
struct SchemaIntrospectionPostgreSQLTests {
    @Test("未指定 schema 时表/视图列举必须调用 current_schema() 函数，不得当成字符串字面量（#275）")
    func loadObjectsUsesCurrentSchemaFunctionWhenSchemaUnspecified() async throws {
        let connection = RecordingPGConnection()
        _ = try await PostgreSQLIntrospector().loadObjects(
            of: .table, in: connection, database: "app", schema: nil
        )
        let sql = try #require(await connection.lastQuery())
        // current_schema() 必须作为函数调用出现，不能带引号变成字符串 'current_schema()'。
        #expect(sql.contains("table_schema = current_schema()"))
        #expect(!sql.contains("table_schema = 'current_schema()'"))
    }

    @Test("未指定 schema 时函数/存储过程列举必须调用 current_schema() 函数（#275）")
    func loadRoutinesUsesCurrentSchemaFunctionWhenSchemaUnspecified() async throws {
        let connection = RecordingPGConnection()
        _ = try await PostgreSQLIntrospector().loadObjects(
            of: .function, in: connection, database: "app", schema: nil
        )
        let sql = try #require(await connection.lastQuery())
        #expect(sql.contains("n.nspname = current_schema()"))
        #expect(!sql.contains("n.nspname = 'current_schema()'"))
    }

    @Test("显式指定 schema 时仍按转义后的字符串字面量过滤，不退化为 current_schema()")
    func loadObjectsBindsExplicitSchemaAsLiteral() async throws {
        let connection = RecordingPGConnection()
        _ = try await PostgreSQLIntrospector().loadObjects(
            of: .table, in: connection, database: "app", schema: "public"
        )
        let sql = try #require(await connection.lastQuery())
        #expect(sql.contains("table_schema = 'public'"))
        #expect(!sql.contains("current_schema()"))
    }
}

@Suite("PostgreSQL 物化视图结构自省")
struct MaterializedViewDescribeTests {
    /// 模拟 pg_catalog 返回的两列物化视图行：
    /// (column_name, data_type, is_nullable, column_default, ordinal_position)。
    private static let mvRows: QueryResult = QueryResult(
        columns: ["column_name", "data_type", "is_nullable", "column_default", "ordinal_position"],
        rows: [
            [.string("region"), .string("text"), .string("YES"), .null, .integer(1)],
            [.string("amount"), .string("numeric(10,2)"), .string("NO"), .null, .integer(2)],
        ],
        rowsAffected: 0
    )

    @Test("物化视图 describeTable 必须查 pg_attribute/pg_class/pg_namespace，不得查 information_schema（#566）")
    func describeMaterializedViewUsesPgCatalog() async throws {
        let connection = ScriptedPGConnection(result: Self.mvRows)
        let object = DatabaseObject(kind: .materializedView, name: "daily_sales", database: "app", schema: "analytics")
        let schema = try await PostgreSQLIntrospector().describeTable(object, in: connection)

        let queries = await connection.allQueries()
        #expect(queries.count == 1)
        let sql = try #require(queries.first)
        #expect(sql.contains("pg_attribute"))
        #expect(sql.contains("pg_class"))
        #expect(sql.contains("pg_namespace"))
        #expect(sql.contains("relkind = 'm'"))
        #expect(sql.contains("n.nspname = 'analytics'"))
        #expect(sql.contains("c.relname = 'daily_sales'"))
        #expect(!sql.contains("information_schema"))

        // 返回的列按 pg_catalog 行映射出真实结构。
        #expect(schema.columns.count == 2)
        #expect(schema.columns[0].name == "region")
        #expect(schema.columns[0].dataType == "text")
        #expect(schema.columns[0].isNullable)
        #expect(!schema.columns[0].isPrimaryKey)
        #expect(schema.columns[0].position == 0)
        #expect(schema.columns[1].name == "amount")
        #expect(schema.columns[1].dataType == "numeric(10,2)")
        #expect(!schema.columns[1].isNullable)
        #expect(!schema.columns[1].isPrimaryKey)
        #expect(schema.columns[1].position == 1)
    }

    @Test("普通表 describeTable 仍走 information_schema.columns，不受物化视图分支影响")
    func describeOrdinaryTableStillUsesInformationSchema() async throws {
        let connection = ScriptedPGConnection(result: Self.mvRows)
        let object = DatabaseObject(kind: .table, name: "orders", database: "app", schema: "public")
        _ = try await PostgreSQLIntrospector().describeTable(object, in: connection)

        let queries = await connection.allQueries()
        let sql = try #require(queries.first)
        #expect(sql.contains("information_schema.columns"))
        #expect(!sql.contains("pg_attribute"))
    }
}