@testable import DatabaseManagerPlugin
import Foundation
import KernelCore
import ProviderEditor
import PluginCodeEditorHost
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderExternalFile
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import ProviderToolManager
import Testing

@MainActor
struct DatabaseManagerV2PluginTests {
    @Test("V2 plugin restores workspace, SQL grammar, and SQLite external-file routing")
    func restoresDatabaseWorkspace() async throws {
        let kernel = KernelCoreContainer()
        let content = DefaultContentViewProviding()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        let externalFiles = DefaultExternalFileOpening()
        let tools = DefaultToolManagerProviding()
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)
        try kernel.registerProvider((any ExternalFileOpening).self, externalFiles)
        try kernel.registerProvider((any ToolbarProviding).self, DefaultToolbarProviding())
        try kernel.registerProvider((any ToolManagerProviding).self, tools)
        let editorHost = CodeEditorHostPlugin()
        try editorHost.onBoot(kernel: kernel)
        let editor = try #require(kernel.resolveProvider(EditorProviding.self))

        let plugin = DatabaseManagerPlugin()
        try plugin.onBoot(kernel: kernel)

        let sqlDocument = EditorDocumentSummary(
            id: .makeUnique(),
            uri: URL(fileURLWithPath: "/tmp/query.sql"),
            languageID: "sql",
            revision: 0,
            isDirty: false,
            isReadOnly: false,
            largeFileMode: .normal
        )
        #expect(editor.extensions.availability(for: .syntax, document: sqlDocument).isAvailable)

        try await plugin.onDisable(kernel: kernel)
        #expect(editor.extensions.availability(for: .syntax, document: sqlDocument).state == .noProvider)
        try await plugin.onEnable(kernel: kernel)
        #expect(editor.extensions.availability(for: .syntax, document: sqlDocument).isAvailable)

        #expect(externalFiles.open(URL(fileURLWithPath: "/tmp/lumi-v2.sqlite")))
        #expect(!externalFiles.open(URL(fileURLWithPath: "/tmp/lumi-v2.txt")))
        #expect(tools.tool(named: DatabaseListConnectionsV2Tool.toolName) != nil)
        #expect(tools.tool(named: DatabaseDescribeSchemaV2Tool.toolName) != nil)
        #expect(tools.tool(named: DatabaseReadonlyQueryV2Tool.toolName) != nil)
        #expect(tools.tool(named: DatabaseSampleTableV2Tool.toolName) != nil)
        #expect(activityBar.activeItemID == "\(plugin.id).entry")
        #expect(railView.tabs.map(\.id) == [DatabaseManagerPlugin.railTabID])
        #expect(railView.visibleTabID == DatabaseManagerPlugin.railTabID)
        #expect(railView.activeTabID == DatabaseManagerPlugin.railTabID)
        #expect(!chat.isVisible)
        #expect(rootView.isContentHeaderViewHidden)
        try plugin.onShutdown(kernel: kernel)
        #expect(editor.extensions.availability(for: .syntax, document: sqlDocument).state == .noProvider)
        try editorHost.onShutdown(kernel: kernel)
        #expect(chat.isVisible)
        #expect(railView.tabs.isEmpty)
        #expect(railView.visibleTabID == nil)
        #expect(rootView.isContentHeaderViewHidden == false)
        #expect(!externalFiles.open(URL(fileURLWithPath: "/tmp/lumi-v2.sqlite")))
        #expect(tools.tool(named: DatabaseListConnectionsV2Tool.toolName) == nil)
    }
}

@Suite struct DatabaseConnectionDraftTests {
    private func sqliteDraft(path: String) -> DatabaseConnectionDraft {
        DatabaseConnectionDraft(
            name: "Local",
            type: .sqlite,
            host: "",
            portText: "",
            database: "",
            username: "",
            password: "",
            sqlitePath: path
        )
    }

    @Test func sqlitePathIsStoredVerbatim() throws {
        // 首尾空格可以是合法文件名的一部分，不能裁剪，否则会打开/新建另一个数据库。
        let config = try sqliteDraft(path: "/tmp/lumi db.sqlite ").makeConfig()
        #expect(config.database == "/tmp/lumi db.sqlite ")
    }

    @Test func sqlitePathRejectsWhitespaceOnlyInput() {
        #expect(throws: DatabaseConnectionDraftError.missingSQLitePath) {
            _ = try sqliteDraft(path: "  \n ").makeConfig()
        }
    }
}

@Suite("Redis handshake")
struct RedisHandshakeTests {
    @Test("Redis 握手错误响应会转换为连接错误")
    func errorResponseFailsHandshake() {
        #expect(throws: DatabaseError.self) {
            try RedisConnection.validateHandshake(
                .error("WRONGPASS invalid username-password pair"),
                context: "Redis 认证失败"
            )
        }
        #expect(throws: DatabaseError.self) {
            try RedisConnection.validateHandshake(
                .error("NOAUTH Authentication required."),
                context: "Redis 连接失败"
            )
        }
    }

    @Test("Redis 握手成功响应不抛错")
    func successResponsePassesHandshake() throws {
        try RedisConnection.validateHandshake(.simpleString("OK"), context: "Redis 认证失败")
        try RedisConnection.validateHandshake(.simpleString("PONG"), context: "Redis 连接失败")
    }
}

@Suite("Redis RESP parsing")
struct RedisRESPParsingTests {
    @Test("CR 位于缓冲区末尾时返回不完整")
    func trailingCRIsIncomplete() throws {
        #expect(try RedisRESPCodec.parseComplete(Data("+OK\r".utf8)) == nil)
        #expect(try RedisRESPCodec.parseComplete(Data("$3\r".utf8)) == nil)
        #expect(try RedisRESPCodec.parseComplete(Data("*1\r".utf8)) == nil)
    }

    @Test("CR 后跟非法字节仍报格式错误")
    func CRFollowedByNonLFTimesOut() {
        #expect(throws: DatabaseError.self) {
            _ = try RedisRESPCodec.parseComplete(Data("+OK\rX".utf8))
        }
    }

    @Test("下一块补全 LF 后可解析")
    func splitCRLFCompletesAfterNextChunk() throws {
        #expect(try RedisRESPCodec.parseComplete(Data("+OK\r\n".utf8)) == .simpleString("OK"))
        #expect(try RedisRESPCodec.parseComplete(Data("$3\r\nfoo\r\n".utf8)) == .bulkString(Data("foo".utf8)))
    }
}

@Suite("SQLite RETURNING")
struct SQLiteReturningTests {
    @Test("SQLite DML RETURNING 产生结果行时不报告失败")
    func executeAcceptsReturningRows() async throws {
        let path = NSTemporaryDirectory() + "/lumi-returning-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let connection = try await SQLiteDriver().connect(config: DatabaseConfig(
            name: "Returning",
            type: .sqlite,
            database: path
        ))
        _ = try await connection.execute(
            "CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)",
            params: nil
        )

        // RETURNING 走 query 时应带回结果行。
        let inserted = try await connection.query(
            "INSERT INTO t(name) VALUES('first') RETURNING id",
            params: nil
        )
        #expect(inserted.columns == ["id"])
        #expect(inserted.rows == [[.integer(1)]])

        // 即使走 execute，也不能把 SQLITE_ROW 当成失败。
        let affected = try await connection.execute(
            "UPDATE t SET name = 'second' RETURNING id",
            params: nil
        )
        #expect(affected == 1)

        // 写入只发生一次：INSERT 与 UPDATE 都未重复执行。
        let count = try await connection.query("SELECT count(*) FROM t", params: nil)
        #expect(count.rows.first?.first == .integer(1))
        await connection.close()
    }

    @Test("DML RETURNING 识别为读路径，字面量中的 RETURNING 不误判")
    @MainActor
    func returningStatementsUseQueryPath() {
        #expect(DatabaseViewModel.isReadStatement(
            "INSERT INTO t(name) VALUES('first') RETURNING id",
            type: .sqlite
        ))
        #expect(DatabaseViewModel.isReadStatement(
            "UPDATE t SET name = 'second' RETURNING id",
            type: .sqlite
        ))
        #expect(DatabaseViewModel.isReadStatement(
            "DELETE FROM t RETURNING id",
            type: .sqlite
        ))
        #expect(!DatabaseViewModel.isReadStatement(
            "INSERT INTO t(name) VALUES('RETURNING')",
            type: .sqlite
        ))
    }
}

@Suite("SQLite WITH (CTE)")
struct SQLiteWithQueryTests {
    @Test("WITH 查询识别为读路径，注释前缀与大小写不影响判定")
    @MainActor
    func withQueryUsesReadPath() {
        // issue #276 的复现语句：只读 CTE 必须走 query。
        #expect(DatabaseViewModel.isReadStatement(
            "WITH x AS (SELECT 1 AS n) SELECT n FROM x;",
            type: .sqlite
        ))
        // 注释前缀不能被误判成写入。
        #expect(DatabaseViewModel.isReadStatement(
            "-- leading comment\nWITH x AS (SELECT 1 AS n) SELECT n FROM x",
            type: .sqlite
        ))
        #expect(DatabaseViewModel.isReadStatement(
            "/* block */ with x as (select 1 as n) select n from x",
            type: .sqlite
        ))
        // 普通写入（无 RETURNING）仍走 execute，不被 WITH 改动误伤。
        #expect(!DatabaseViewModel.isReadStatement(
            "INSERT INTO t(name) VALUES('first')",
            type: .sqlite
        ))
    }

    @Test("WITH 查询经 query 路径返回真实结果行")
    @MainActor
    func withQueryReturnsRowsEndToEnd() async throws {
        let path = NSTemporaryDirectory() + "/lumi-with-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let connection = try await SQLiteDriver().connect(config: DatabaseConfig(
            name: "With",
            type: .sqlite,
            database: path
        ))

        let sql = "WITH x AS (SELECT 1 AS n) SELECT n FROM x;"
        // 生产 executeQuery 依据 isReadStatement 选择 query；这里锁定该判定为读。
        #expect(DatabaseViewModel.isReadStatement(sql, type: .sqlite))

        let result = try await connection.query(sql, params: nil)
        #expect(result.columns == ["n"])
        #expect(result.rows == [[.integer(1)]])
        await connection.close()
    }
}

@Suite("Redis read-command routing")
struct RedisReadCommandRoutingTests {
    @Test("Redis 只读命令识别为读路径（含 KEYS/TYPE，大小写不敏感）")
    @MainActor
    func redisReadCommandsUseQueryPath() {
        // issue #277 的复现命令：KEYS / TYPE 必须走 query 才能展示真实 RESP 值。
        let readCommands = [
            "KEYS *", "TYPE mykey", "EXISTS mykey", "TTL mykey",
            "HGETALL h", "MGET a b", "ZRANGEBYSCORE z 0 10", "INFO",
            "keys *", "type mykey", "  GET mykey  ",
            // 既有读命令不能被改坏。
            "GET mykey", "SCAN 0", "HGET h f", "LRANGE l 0 -1",
            "SMEMBERS s", "ZRANGE z 0 -1",
        ]
        for command in readCommands {
            #expect(DatabaseViewModel.isReadStatement(command, type: .redis),
                    "\(command) 应识别为读路径")
        }
    }

    @Test("Redis 写入命令仍走 execute，前缀相近的写命令不被误判为读")
    @MainActor
    func redisWriteCommandsUseExecutePath() {
        let writeCommands = [
            "SET k v", "DEL k", "HSET h f v", "LPUSH l v", "SADD s v", "ZADD z 1 v",
            "EXPIRE k 10", "FLUSHDB",
            // 与读命令共享前缀、但本质是写入：精确匹配后不得再被当成读。
            "GETSET k v", "GETDEL k", "ZRANGESTORE dst z 0 -1",
            // 多词命令的写子命令统一交给 execute。
            "CONFIG SET maxmemory 100mb",
        ]
        for command in writeCommands {
            #expect(!DatabaseViewModel.isReadStatement(command, type: .redis),
                    "\(command) 应识别为写入路径")
        }
    }
}
