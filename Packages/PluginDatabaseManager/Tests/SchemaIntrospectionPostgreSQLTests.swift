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