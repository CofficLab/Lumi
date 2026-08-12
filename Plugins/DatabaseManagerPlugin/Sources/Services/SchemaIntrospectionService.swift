import Foundation

/// 数据库结构自省服务：把各引擎的 catalog 查询统一成 ``DatabaseObject`` / ``TableSchema``。
///
/// UI（侧边栏树、结构 Tab）只依赖此协议，不感知具体 SQL 方言。
/// Redis 没有关系型结构，不实现此协议——其键浏览走专门的 SCAN 路径。
public protocol DatabaseIntrospector: Sendable {
    func loadDatabases(in connection: any DatabaseConnection) async throws -> [String]
    func loadSchemas(in connection: any DatabaseConnection, database: String?) async throws -> [String]
    func loadObjects(
        of kind: DatabaseObjectKind,
        in connection: any DatabaseConnection,
        database: String?,
        schema: String?
    ) async throws -> [DatabaseObject]
    func describeTable(
        _ object: DatabaseObject,
        in connection: any DatabaseConnection
    ) async throws -> TableSchema
    func loadDDL(
        for object: DatabaseObject,
        in connection: any DatabaseConnection
    ) async throws -> String?
}

// MARK: - DatabaseType routing

public extension DatabaseType {
    var introspector: any DatabaseIntrospector {
        switch self {
        case .sqlite: return SQLiteIntrospector()
        case .mysql: return MySQLIntrospector()
        case .postgresql: return PostgreSQLIntrospector()
        case .redis: return EmptyIntrospector()
        }
    }
}

/// Redis 占位实现：Redis 没有关系型结构，所有调用返回空。
public struct EmptyIntrospector: DatabaseIntrospector {
    public init() {}
    public func loadDatabases(in connection: any DatabaseConnection) async throws -> [String] { [] }
    public func loadSchemas(in connection: any DatabaseConnection, database: String?) async throws -> [String] { [] }
    public func loadObjects(of kind: DatabaseObjectKind, in connection: any DatabaseConnection, database: String?, schema: String?) async throws -> [DatabaseObject] { [] }
    public func describeTable(_ object: DatabaseObject, in connection: any DatabaseConnection) async throws -> TableSchema {
        TableSchema(table: object, columns: [])
    }
    public func loadDDL(for object: DatabaseObject, in connection: any DatabaseConnection) async throws -> String? { nil }
}

// MARK: - QueryResult row decoding helpers

enum SchemaRowDecoder {
    static func string(_ row: [DatabaseValue], at index: Int) -> String? {
        guard index < row.count else { return nil }
        switch row[index] {
        case .string(let s): return s
        case .integer(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        case .data: return nil
        case .null: return nil
        }
    }

    static func int(_ row: [DatabaseValue], at index: Int) -> Int? {
        guard index < row.count else { return nil }
        switch row[index] {
        case .integer(let i): return i
        case .string(let s): return Int(s)
        case .double(let d): return Int(d)
        case .bool(let b): return b ? 1 : 0
        case .data, .null: return nil
        }
    }
}

// MARK: - SQLite

/// SQLite 自省：基于 `sqlite_master` 与 `PRAGMA`。
public struct SQLiteIntrospector: DatabaseIntrospector {
    public init() {}

    public func loadDatabases(in connection: any DatabaseConnection) async throws -> [String] {
        []  // SQLite 是单文件库；ATTACH 的库暂不支持在树中切换
    }

    public func loadSchemas(in connection: any DatabaseConnection, database: String?) async throws -> [String] {
        []
    }

    public func loadObjects(
        of kind: DatabaseObjectKind,
        in connection: any DatabaseConnection,
        database: String?,
        schema: String?
    ) async throws -> [DatabaseObject] {
        let typeLiteral: String
        switch kind {
        case .table: typeLiteral = "table"
        case .view: typeLiteral = "view"
        case .index: typeLiteral = "index"
        case .trigger: typeLiteral = "trigger"
        case .materializedView, .procedure, .function:
            return []  // SQLite 不支持
        }
        let sql = """
        SELECT name, sql FROM sqlite_master
        WHERE type = '\(typeLiteral)' AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
        """
        let result = try await connection.query(sql, params: nil)
        return result.rows.compactMap { row -> DatabaseObject? in
            guard let name = SchemaRowDecoder.string(row, at: 0) else { return nil }
            return DatabaseObject(kind: kind, name: name)
        }
    }

    public func describeTable(_ object: DatabaseObject, in connection: any DatabaseConnection) async throws -> TableSchema {
        let quoted = Self.quote(object.name)
        let columnsResult = try await connection.query("PRAGMA table_info(\(quoted));", params: nil)
        let columns: [TableColumn] = columnsResult.rows.enumerated().map { idx, row in
            // PRAGMA table_info: cid, name, type, notnull, dflt_value, pk
            TableColumn(
                name: SchemaRowDecoder.string(row, at: 1) ?? "",
                dataType: SchemaRowDecoder.string(row, at: 2) ?? "",
                isNullable: SchemaRowDecoder.int(row, at: 3) != 1,
                isPrimaryKey: (SchemaRowDecoder.int(row, at: 5) ?? 0) > 0,
                defaultValue: SchemaRowDecoder.string(row, at: 4),
                position: SchemaRowDecoder.int(row, at: 0) ?? idx
            )
        }

        // 索引：PRAGMA index_list + 每个 index 的 index_info
        var indexes: [TableIndex] = []
        let indexList = try? await connection.query("PRAGMA index_list(\(quoted));", params: nil)
        if let indexList {
            for row in indexList.rows {
                // PRAGMA index_list: seq, name, unique, origin, partial
                guard let indexName = SchemaRowDecoder.string(row, at: 1) else { continue }
                let isUnique = SchemaRowDecoder.int(row, at: 2) == 1
                let colsResult = (try? await connection.query("PRAGMA index_info(\"\(Self.escape(indexName))\");", params: nil)) ?? QueryResult(columns: [], rows: [], rowsAffected: 0)
                let cols = colsResult.rows.compactMap { SchemaRowDecoder.string($0, at: 2) }
                indexes.append(TableIndex(name: indexName, columns: cols, isUnique: isUnique, indexType: nil))
            }
        }

        // 外键：PRAGMA foreign_key_list
        var foreignKeys: [ForeignKey] = []
        let fkList = try? await connection.query("PRAGMA foreign_key_list(\(quoted));", params: nil)
        if let fkList {
            for row in fkList.rows {
                // PRAGMA foreign_key_list: id, seq, table, from, to, on_update, on_delete, match
                guard let name = SchemaRowDecoder.string(row, at: 3) else { continue }
                let refTable = SchemaRowDecoder.string(row, at: 2) ?? ""
                let refCol = SchemaRowDecoder.string(row, at: 4) ?? ""
                foreignKeys.append(ForeignKey(
                    name: "fk_\(object.name)_\(name)",
                    columns: [name],
                    referencesTable: refTable,
                    referencesColumns: refCol.isEmpty ? [] : [refCol],
                    onDelete: SchemaRowDecoder.string(row, at: 6),
                    onUpdate: SchemaRowDecoder.string(row, at: 5)
                ))
            }
        }

        // 触发器
        let triggerSql = "SELECT name FROM sqlite_master WHERE type='trigger' AND tbl_name='\(Self.escape(object.name))' ORDER BY name;"
        let triggerResult = (try? await connection.query(triggerSql, params: nil)) ?? QueryResult(columns: [], rows: [], rowsAffected: 0)
        let triggers: [TableTrigger] = triggerResult.rows.compactMap { row in
            guard let name = SchemaRowDecoder.string(row, at: 0) else { return nil }
            return TableTrigger(name: name, timing: nil, event: nil, statement: nil)
        }

        let ddl = try? await loadDDL(for: object, in: connection)
        return TableSchema(
            table: object,
            columns: columns,
            indexes: indexes,
            foreignKeys: foreignKeys,
            triggers: triggers,
            ddl: ddl
        )
    }

    public func loadDDL(for object: DatabaseObject, in connection: any DatabaseConnection) async throws -> String? {
        let sql = "SELECT sql FROM sqlite_master WHERE type='\(object.kind == .view ? "view" : "table")' AND name='\(Self.escape(object.name))' LIMIT 1;"
        let result = try await connection.query(sql, params: nil)
        guard let row = result.rows.first else { return nil }
        return SchemaRowDecoder.string(row, at: 0)
    }

    private static func escape(_ name: String) -> String {
        name.replacingOccurrences(of: "'", with: "''")
    }

    private static func quote(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

// MARK: - MySQL

/// MySQL 自省：基于 `information_schema` 与 `SHOW`。
public struct MySQLIntrospector: DatabaseIntrospector {
    public init() {}

    public func loadDatabases(in connection: any DatabaseConnection) async throws -> [String] {
        let result = try await connection.query("SHOW DATABASES;", params: nil)
        return result.rows.compactMap { SchemaRowDecoder.string($0, at: 0) }
            .filter { !$0.isEmpty && $0 != "information_schema" && $0 != "performance_schema" && $0 != "mysql" && $0 != "sys" }
    }

    public func loadSchemas(in connection: any DatabaseConnection, database: String?) async throws -> [String] {
        // MySQL 中 schema ≈ database，这里返回单元素，避免树出现冗余层级。
        database.map { [$0] } ?? []
    }

    public func loadObjects(
        of kind: DatabaseObjectKind,
        in connection: any DatabaseConnection,
        database: String?,
        schema: String?
    ) async throws -> [DatabaseObject] {
        guard let database else { return [] }
        switch kind {
        case .table, .view:
            let tableType = kind == .table ? "BASE TABLE" : "VIEW"
            let sql = """
            SELECT table_name, table_comment FROM information_schema.tables
            WHERE table_schema = '\(Self.escape(database))' AND table_type = '\(tableType)'
            ORDER BY table_name;
            """
            let result = try await connection.query(sql, params: nil)
            return result.rows.compactMap { row in
                guard let name = SchemaRowDecoder.string(row, at: 0) else { return nil }
                let comment = SchemaRowDecoder.string(row, at: 1)
                return DatabaseObject(kind: kind, name: name, database: database, comment: (comment?.isEmpty == false ? comment : nil))
            }
        case .procedure, .function:
            let routineType = kind == .procedure ? "PROCEDURE" : "FUNCTION"
            let sql = """
            SELECT routine_name FROM information_schema.routines
            WHERE routine_schema = '\(Self.escape(database))' AND routine_type = '\(routineType)'
            ORDER BY routine_name;
            """
            let result = try await connection.query(sql, params: nil)
            return result.rows.compactMap { row in
                guard let name = SchemaRowDecoder.string(row, at: 0) else { return nil }
                return DatabaseObject(kind: kind, name: name, database: database)
            }
        case .index, .trigger, .materializedView:
            // 索引/触发器随表结构展示，不在顶层树列出。Phase 5 可扩展。
            return []
        }
    }

    public func describeTable(_ object: DatabaseObject, in connection: any DatabaseConnection) async throws -> TableSchema {
        guard let database = object.database else {
            return TableSchema(table: object, columns: [])
        }
        let qualified = "`\(Self.escape(database))`.`\(Self.escape(object.name))`"
        let sql = """
        SELECT column_name, data_type, is_nullable, column_default, column_key, column_comment, ordinal_position
        FROM information_schema.columns
        WHERE table_schema = '\(Self.escape(database))' AND table_name = '\(Self.escape(object.name))'
        ORDER BY ordinal_position;
        """
        let result = try await connection.query(sql, params: nil)
        let columns: [TableColumn] = result.rows.map { row in
            TableColumn(
                name: SchemaRowDecoder.string(row, at: 0) ?? "",
                dataType: SchemaRowDecoder.string(row, at: 1) ?? "",
                isNullable: SchemaRowDecoder.string(row, at: 2)?.uppercased() == "YES",
                isPrimaryKey: SchemaRowDecoder.string(row, at: 4)?.uppercased() == "PRI",
                defaultValue: SchemaRowDecoder.string(row, at: 3),
                position: (SchemaRowDecoder.int(row, at: 6) ?? 1) - 1,
                comment: SchemaRowDecoder.string(row, at: 5)
            )
        }
        let ddl = try? await connection.query("SHOW CREATE TABLE \(qualified);", params: nil)
        let ddlString = ddl?.rows.first.flatMap { SchemaRowDecoder.string($0, at: 1) }
        return TableSchema(table: object, columns: columns, ddl: ddlString)
    }

    public func loadDDL(for object: DatabaseObject, in connection: any DatabaseConnection) async throws -> String? {
        guard let database = object.database else { return nil }
        let qualified = "`\(Self.escape(database))`.`\(Self.escape(object.name))`"
        let result = try await connection.query("SHOW CREATE TABLE \(qualified);", params: nil)
        return result.rows.first.flatMap { SchemaRowDecoder.string($0, at: 1) }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "`", with: "``").replacingOccurrences(of: "'", with: "''")
    }
}

// MARK: - PostgreSQL

/// PostgreSQL 自省：基于 `information_schema` 与 `pg_catalog`。
public struct PostgreSQLIntrospector: DatabaseIntrospector {
    public init() {}

    public func loadDatabases(in connection: any DatabaseConnection) async throws -> [String] {
        let result = try await connection.query(
            "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;",
            params: nil
        )
        return result.rows.compactMap { SchemaRowDecoder.string($0, at: 0) }
    }

    public func loadSchemas(in connection: any DatabaseConnection, database: String?) async throws -> [String] {
        let result = try await connection.query(
            """
            SELECT schema_name FROM information_schema.schemata
            WHERE schema_name NOT LIKE 'pg_%' AND schema_name <> 'information_schema'
            ORDER BY schema_name;
            """,
            params: nil
        )
        return result.rows.compactMap { SchemaRowDecoder.string($0, at: 0) }
    }

    public func loadObjects(
        of kind: DatabaseObjectKind,
        in connection: any DatabaseConnection,
        database: String?,
        schema: String?
    ) async throws -> [DatabaseObject] {
        switch kind {
        case .table, .view, .materializedView:
            let tableType: String
            switch kind {
            case .table: tableType = "BASE TABLE"
            case .view: tableType = "VIEW"
            default: tableType = "FOREIGN"  // 占位，物化视图走 pg_class 分支
            }
            if kind == .materializedView {
                let sql = """
                SELECT relname FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind = 'm' AND n.nspname = current_schema()
                ORDER BY relname;
                """
                let result = try await connection.query(sql, params: nil)
                return result.rows.compactMap { row in
                    guard let name = SchemaRowDecoder.string(row, at: 0) else { return nil }
                    return DatabaseObject(kind: kind, name: name, database: database, schema: schema)
                }
            }
            let schemaFilter = schema ?? "current_schema()"
            let sql = """
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = '\(Self.escape(schemaFilter))' AND table_type = '\(tableType)'
            ORDER BY table_name;
            """
            let result = try await connection.query(sql, params: nil)
            return result.rows.compactMap { row in
                guard let name = SchemaRowDecoder.string(row, at: 0) else { return nil }
                return DatabaseObject(kind: kind, name: name, database: database, schema: schema)
            }
        case .procedure, .function:
            let kindFilter = kind == .procedure ? "p" : "f"
            let schemaFilter = schema ?? "current_schema()"
            let sql = """
            SELECT p.proname FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = '\(Self.escape(schemaFilter))' AND p.prokind = '\(kindFilter)'
            ORDER BY p.proname;
            """
            let result = try await connection.query(sql, params: nil)
            return result.rows.compactMap { row in
                guard let name = SchemaRowDecoder.string(row, at: 0) else { return nil }
                return DatabaseObject(kind: kind, name: name, database: database, schema: schema)
            }
        case .index, .trigger:
            return []  // 随表结构展示
        }
    }

    public func describeTable(_ object: DatabaseObject, in connection: any DatabaseConnection) async throws -> TableSchema {
        let schema = object.schema ?? "public"
        let sql = """
        SELECT column_name, data_type, is_nullable, column_default, ordinal_position
        FROM information_schema.columns
        WHERE table_schema = '\(Self.escape(schema))' AND table_name = '\(Self.escape(object.name))'
        ORDER BY ordinal_position;
        """
        let result = try await connection.query(sql, params: nil)
        // 主键列
        let pkResult = (try? await connection.query(
            """
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
            WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = '\(Self.escape(schema))'
              AND tc.table_name = '\(Self.escape(object.name))';
            """,
            params: nil)) ?? QueryResult(columns: [], rows: [], rowsAffected: 0)
        let pkColumns = Set(pkResult.rows.compactMap { SchemaRowDecoder.string($0, at: 0) })

        let columns: [TableColumn] = result.rows.map { row in
            TableColumn(
                name: SchemaRowDecoder.string(row, at: 0) ?? "",
                dataType: SchemaRowDecoder.string(row, at: 1) ?? "",
                isNullable: SchemaRowDecoder.string(row, at: 2)?.uppercased() == "YES",
                isPrimaryKey: pkColumns.contains(SchemaRowDecoder.string(row, at: 0) ?? ""),
                defaultValue: SchemaRowDecoder.string(row, at: 3),
                position: (SchemaRowDecoder.int(row, at: 4) ?? 1) - 1
            )
        }
        return TableSchema(table: object, columns: columns)
    }

    public func loadDDL(for object: DatabaseObject, in connection: any DatabaseConnection) async throws -> String? {
        let schema = object.schema ?? "public"
        let result = try await connection.query(
            "SELECT pg_get_tabledef('\(Self.escape(schema))'::text, '\(Self.escape(object.name))'::text, false);",
            params: nil
        )
        // pg_get_tabledef 可能不可用（非默认扩展），失败时返回 nil，由上层用列信息兜底
        return result.rows.first.flatMap { SchemaRowDecoder.string($0, at: 0) }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "''")
    }
}
