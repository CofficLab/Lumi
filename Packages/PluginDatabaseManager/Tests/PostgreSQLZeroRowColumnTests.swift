import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 针对真实 PostgreSQL 的列元数据验证：需要环境变量 LUMI_PG_TEST_HOST
/// 指向可连接的实例（端口/账号可选覆盖），未设置时整组跳过。
@Suite("PostgreSQL zero-row column metadata", .serialized)
struct PostgreSQLZeroRowColumnTests {
    private static let env = ProcessInfo.processInfo.environment

    private static func makeConnection() async throws -> PGConnection {
        try await PGConnection(
            host: env["LUMI_PG_TEST_HOST"]!,
            port: Int(env["LUMI_PG_TEST_PORT"] ?? "5432")!,
            username: env["LUMI_PG_TEST_USER"] ?? "postgres",
            password: env["LUMI_PG_TEST_PASSWORD"],
            database: env["LUMI_PG_TEST_DATABASE"] ?? "postgres"
        )
    }

    /// #278：零行 SELECT 也必须带回列名（来自 RowDescription），并且
    /// 列名探针不再重跑用户 SQL、不再让整个查询失败。
    @Test(.enabled(if: env["LUMI_PG_TEST_HOST"] != nil))
    func zeroRowSelectCarriesColumnMetadata() async throws {
        let conn = try await Self.makeConnection()
        defer { Task { await conn.close() } }

        let zeroRow = try await conn.query("SELECT 1 AS n WHERE false", params: nil)
        #expect(zeroRow.columns == ["n"])
        #expect(zeroRow.rows.isEmpty)
        #expect(zeroRow.rowsAffected == 0)
    }

    /// 常规带行结果不受影响：列名与行内容一一对应。
    @Test(.enabled(if: env["LUMI_PG_TEST_HOST"] != nil))
    func regularSelectStillDecodesColumnsAndRows() async throws {
        let conn = try await Self.makeConnection()
        defer { Task { await conn.close() } }

        let result = try await conn.query("SELECT 42 AS answer, 'ok' AS label", params: nil)
        #expect(result.columns == ["answer", "label"])
        #expect(result.rows.count == 1)
        #expect(result.rows[0].count == 2)
    }
}
