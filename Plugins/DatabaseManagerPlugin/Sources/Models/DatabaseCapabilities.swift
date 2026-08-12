import Foundation

/// 各数据库类型支持的能力声明。
///
/// UI 层据此启用/禁用功能入口（结构编辑、SSL、EXPLAIN、分页等），
/// 避免在视图里硬编码 `switch databaseType`。新增驱动时只需提供一份 preset。
///
/// - Note: 能力是"该引擎原则上支持"，不代表当前驱动已实现对应特性。
///   例如 SQLite 的 `supportsSSH` 为 true（TCP 隧道对任何引擎都适用），
///   但 SSL 为 false（SQLite 是本地文件，无需 TLS）。
public struct DatabaseCapabilities: Sendable, Equatable {
    // MARK: - Schema editing
    public let supportsSchemaEditing: Bool
    public let supportsIndexes: Bool
    public let supportsForeignKeys: Bool
    public let supportsTriggers: Bool
    public let supportsViews: Bool
    public let supportsMaterializedViews: Bool
    /// 存储过程与函数。
    public let supportsRoutines: Bool

    // MARK: - Connection / security
    public let supportsSSL: Bool
    public let supportsSSH: Bool
    /// 除内联密码外，是否支持 file/env/command 等密码来源。
    public let supportsPasswordSources: Bool

    // MARK: - Query features
    public let supportsExplain: Bool
    public let supportsTransactions: Bool
    public let supportsPagination: Bool
    public let supportsMultiStatement: Bool

    // MARK: - Structure
    /// 服务器层级可存在多个数据库（PG/MySQL/Redis 是，SQLite 单文件否）。
    public let supportsMultipleDatabases: Bool
    /// PG 风格的 schema 命名空间（database → schema → table）。
    public let supportsSchemas: Bool
    public let supportsComments: Bool

    // MARK: - Data editing
    public let supportsRowEdit: Bool

    // MARK: - Defaults
    public let defaultQueryLimit: Int
    /// 标识符引用字符（SQLite/PG 用 `"`、MySQL 用 `` ` ``，Redis 为 nil）。
    public let identifierQuoteCharacter: Character?

    public init(
        supportsSchemaEditing: Bool,
        supportsIndexes: Bool,
        supportsForeignKeys: Bool,
        supportsTriggers: Bool,
        supportsViews: Bool,
        supportsMaterializedViews: Bool,
        supportsRoutines: Bool,
        supportsSSL: Bool,
        supportsSSH: Bool,
        supportsPasswordSources: Bool,
        supportsExplain: Bool,
        supportsTransactions: Bool,
        supportsPagination: Bool,
        supportsMultiStatement: Bool,
        supportsMultipleDatabases: Bool,
        supportsSchemas: Bool,
        supportsComments: Bool,
        supportsRowEdit: Bool,
        defaultQueryLimit: Int,
        identifierQuoteCharacter: Character?
    ) {
        self.supportsSchemaEditing = supportsSchemaEditing
        self.supportsIndexes = supportsIndexes
        self.supportsForeignKeys = supportsForeignKeys
        self.supportsTriggers = supportsTriggers
        self.supportsViews = supportsViews
        self.supportsMaterializedViews = supportsMaterializedViews
        self.supportsRoutines = supportsRoutines
        self.supportsSSL = supportsSSL
        self.supportsSSH = supportsSSH
        self.supportsPasswordSources = supportsPasswordSources
        self.supportsExplain = supportsExplain
        self.supportsTransactions = supportsTransactions
        self.supportsPagination = supportsPagination
        self.supportsMultiStatement = supportsMultiStatement
        self.supportsMultipleDatabases = supportsMultipleDatabases
        self.supportsSchemas = supportsSchemas
        self.supportsComments = supportsComments
        self.supportsRowEdit = supportsRowEdit
        self.defaultQueryLimit = defaultQueryLimit
        self.identifierQuoteCharacter = identifierQuoteCharacter
    }
}

// MARK: - Per-type presets

extension DatabaseCapabilities {
    public static let sqlite = DatabaseCapabilities(
        supportsSchemaEditing: true,
        supportsIndexes: true,
        supportsForeignKeys: true,
        supportsTriggers: true,
        supportsViews: true,
        supportsMaterializedViews: false,
        supportsRoutines: false,
        supportsSSL: false,
        supportsSSH: true,
        supportsPasswordSources: false,
        supportsExplain: true,
        supportsTransactions: true,
        supportsPagination: true,
        supportsMultiStatement: true,
        supportsMultipleDatabases: false,
        supportsSchemas: false,
        supportsComments: false,
        supportsRowEdit: true,
        defaultQueryLimit: 50,
        identifierQuoteCharacter: "\""
    )

    public static let mysql = DatabaseCapabilities(
        supportsSchemaEditing: true,
        supportsIndexes: true,
        supportsForeignKeys: true,
        supportsTriggers: true,
        supportsViews: true,
        supportsMaterializedViews: false,
        supportsRoutines: true,
        supportsSSL: true,
        supportsSSH: true,
        supportsPasswordSources: true,
        supportsExplain: true,
        supportsTransactions: true,
        supportsPagination: true,
        supportsMultiStatement: true,
        supportsMultipleDatabases: true,
        supportsSchemas: false,
        supportsComments: true,
        supportsRowEdit: true,
        defaultQueryLimit: 100,
        identifierQuoteCharacter: "`"
    )

    public static let postgresql = DatabaseCapabilities(
        supportsSchemaEditing: true,
        supportsIndexes: true,
        supportsForeignKeys: true,
        supportsTriggers: true,
        supportsViews: true,
        supportsMaterializedViews: true,
        supportsRoutines: true,
        supportsSSL: true,
        supportsSSH: true,
        supportsPasswordSources: true,
        supportsExplain: true,
        supportsTransactions: true,
        supportsPagination: true,
        supportsMultiStatement: true,
        supportsMultipleDatabases: true,
        supportsSchemas: true,
        supportsComments: true,
        supportsRowEdit: true,
        defaultQueryLimit: 100,
        identifierQuoteCharacter: "\""
    )

    public static let redis = DatabaseCapabilities(
        supportsSchemaEditing: false,
        supportsIndexes: false,
        supportsForeignKeys: false,
        supportsTriggers: false,
        supportsViews: false,
        supportsMaterializedViews: false,
        supportsRoutines: false,
        supportsSSL: true,
        supportsSSH: true,
        supportsPasswordSources: false,
        supportsExplain: false,
        supportsTransactions: true,
        supportsPagination: false,
        supportsMultiStatement: false,
        supportsMultipleDatabases: true,
        supportsSchemas: false,
        supportsComments: false,
        supportsRowEdit: true,
        defaultQueryLimit: 100,
        identifierQuoteCharacter: nil
    )
}

// MARK: - DatabaseType convenience

public extension DatabaseType {
    /// 该类型对应的默认能力集合。
    var capabilities: DatabaseCapabilities {
        switch self {
        case .sqlite: return .sqlite
        case .mysql: return .mysql
        case .postgresql: return .postgresql
        case .redis: return .redis
        }
    }

    /// 默认网络端口。SQLite 本地文件无端口，返回 nil。
    var defaultPort: Int? {
        switch self {
        case .sqlite: return nil
        case .mysql: return 3306
        case .postgresql: return 5432
        case .redis: return 6379
        }
    }
}
