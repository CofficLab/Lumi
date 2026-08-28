import Foundation

/// 数据库对象类型（侧边栏树的叶子分类）。
///
/// 用于统一描述 SQLite/MySQL/PostgreSQL 的可浏览对象。
/// Redis 不使用此模型（其"对象"是 key，由专门的键浏览逻辑处理）。
public enum DatabaseObjectKind: String, CaseIterable, Sendable {
    case table
    case view
    case materializedView
    case index
    case trigger
    case procedure
    case function

    /// 侧边栏分组标题的本地化键（英文兜底，由调用方再做本地化映射）。
    public var sectionKey: String {
        switch self {
        case .table: return "Tables"
        case .view: return "Views"
        case .materializedView: return "Materialized Views"
        case .index: return "Indexes"
        case .trigger: return "Triggers"
        case .procedure: return "Procedures"
        case .function: return "Functions"
        }
    }

    /// SF Symbol 图标名。
    public var systemImage: String {
        switch self {
        case .table: return "tablecells"
        case .view, .materializedView: return "eye"
        case .index: return "list.number"
        case .trigger: return "bolt"
        case .procedure: return "wrench.and.screwdriver"
        case .function: return "f.cursive"
        }
    }
}

/// 一个可浏览的数据库对象（表/视图/索引/触发器/例程）。
public struct DatabaseObject: Identifiable, Hashable, Sendable {
    /// 在一次 introspection 结果中唯一的标识（`database/schema/kind/name`）。
    public let id: String
    public let kind: DatabaseObjectKind
    public let name: String
    public let database: String?
    public let schema: String?
    public var comment: String?
    public var rowCount: Int?

    public init(
        kind: DatabaseObjectKind,
        name: String,
        database: String? = nil,
        schema: String? = nil,
        comment: String? = nil,
        rowCount: Int? = nil
    ) {
        let idParts = [database ?? "", schema ?? "", kind.rawValue, name]
        self.id = idParts.joined(separator: "/")
        self.kind = kind
        self.name = name
        self.database = database
        self.schema = schema
        self.comment = comment
        self.rowCount = rowCount
    }
}

/// 表的一列。
public struct TableColumn: Hashable, Sendable {
    public let name: String
    public let dataType: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let defaultValue: String?
    /// 在表中的序号（从 0 起）。
    public let position: Int
    public var comment: String?

    public init(
        name: String,
        dataType: String,
        isNullable: Bool,
        isPrimaryKey: Bool,
        defaultValue: String?,
        position: Int,
        comment: String? = nil
    ) {
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.defaultValue = defaultValue
        self.position = position
        self.comment = comment
    }
}

/// 表索引。
public struct TableIndex: Hashable, Sendable {
    public let name: String
    public let columns: [String]
    public let isUnique: Bool
    /// BTREE / HASH / GIN / GIST / BRIN / FULLTEXT 等。
    public let indexType: String?

    public init(name: String, columns: [String], isUnique: Bool, indexType: String? = nil) {
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
        self.indexType = indexType
    }
}

/// 外键定义。
public struct ForeignKey: Hashable, Sendable {
    public let name: String
    public let columns: [String]
    public let referencesTable: String
    public let referencesColumns: [String]
    public let onDelete: String?
    public let onUpdate: String?

    public init(
        name: String,
        columns: [String],
        referencesTable: String,
        referencesColumns: [String],
        onDelete: String? = nil,
        onUpdate: String? = nil
    ) {
        self.name = name
        self.columns = columns
        self.referencesTable = referencesTable
        self.referencesColumns = referencesColumns
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }
}

/// 触发器定义。
public struct TableTrigger: Hashable, Sendable {
    public let name: String
    /// BEFORE / AFTER / INSTEAD OF。
    public let timing: String?
    /// INSERT / UPDATE / DELETE。
    public let event: String?
    public let statement: String?
    public let isEnabled: Bool

    public init(name: String, timing: String?, event: String?, statement: String?, isEnabled: Bool = true) {
        self.name = name
        self.timing = timing
        self.event = event
        self.statement = statement
        self.isEnabled = isEnabled
    }
}

/// 一张表的完整结构描述。
public struct TableSchema: Sendable {
    public let table: DatabaseObject
    public let columns: [TableColumn]
    public let indexes: [TableIndex]
    public let foreignKeys: [ForeignKey]
    public let triggers: [TableTrigger]
    public let ddl: String?

    public init(
        table: DatabaseObject,
        columns: [TableColumn],
        indexes: [TableIndex] = [],
        foreignKeys: [ForeignKey] = [],
        triggers: [TableTrigger] = [],
        ddl: String? = nil
    ) {
        self.table = table
        self.columns = columns
        self.indexes = indexes
        self.foreignKeys = foreignKeys
        self.triggers = triggers
        self.ddl = ddl
    }
}
