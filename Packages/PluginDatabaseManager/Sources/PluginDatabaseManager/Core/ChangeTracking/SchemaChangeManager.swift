import Combine
import Foundation

public struct NewTableColumnDraft: Equatable, Sendable {
    public var name: String
    public var dataType: String
    public var isNullable: Bool
    public var defaultValue: String?

    public init(name: String = "", dataType: String = "TEXT", isNullable: Bool = true, defaultValue: String? = nil) {
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.defaultValue = defaultValue
    }
}

public struct NewTableIndexDraft: Equatable, Sendable {
    public var name: String
    public var columns: [String]
    public var isUnique: Bool

    public init(name: String = "", columns: [String] = [], isUnique: Bool = false) {
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
    }
}

public enum PendingSchemaChange: Identifiable, Equatable, Sendable {
    case addColumn(id: UUID, column: NewTableColumnDraft)
    case renameColumn(id: UUID, oldName: String, newName: String)
    case dropColumn(id: UUID, column: TableColumn)
    case addIndex(id: UUID, index: NewTableIndexDraft)
    case dropIndex(id: UUID, index: TableIndex)

    public var id: UUID {
        switch self {
        case .addColumn(let id, _), .renameColumn(let id, _, _), .dropColumn(let id, _),
             .addIndex(let id, _), .dropIndex(let id, _): id
        }
    }

    public var isDestructive: Bool {
        if case .dropColumn = self { return true }
        return false
    }

    public var summary: String {
        switch self {
        case .addColumn(_, let column): return "Add column ‘\(column.name)’"
        case .renameColumn(_, let oldName, let newName): return "Rename ‘\(oldName)’ to ‘\(newName)’"
        case .dropColumn(_, let column): return "Drop column ‘\(column.name)’"
        case .addIndex(_, let index): return "Add index ‘\(index.name)’"
        case .dropIndex(_, let index): return "Drop index ‘\(index.name)’"
        }
    }
}

public enum SchemaChangeValidationError: LocalizedError, Equatable {
    case blankName
    case blankType
    case duplicateColumn(String)
    case unchangedName
    case primaryKeyDrop(String)
    case requiredColumnNeedsDefault
    case unsafeSQLFragment
    case missingIndexColumns
    case unknownIndexColumn(String)
    case duplicateIndex(String)
    case protectedIndex(String)

    public var errorDescription: String? {
        switch self {
        case .blankName: "Column name cannot be empty."
        case .blankType: "Column type cannot be empty."
        case .duplicateColumn(let name): "A column named ‘\(name)’ already exists."
        case .unchangedName: "Enter a different column name."
        case .primaryKeyDrop(let name): "Primary key column ‘\(name)’ cannot be dropped in this version."
        case .requiredColumnNeedsDefault: "A NOT NULL column added to an existing table requires a default value."
        case .unsafeSQLFragment: "Column type or default contains an unsafe SQL fragment."
        case .missingIndexColumns: "Select at least one column for the index."
        case .unknownIndexColumn(let name): "Column ‘\(name)’ does not exist."
        case .duplicateIndex(let name): "An index named ‘\(name)’ already exists."
        case .protectedIndex(let name): "System or primary index ‘\(name)’ cannot be dropped here."
        }
    }
}

/// Stages a conservative subset of table structure changes before SQL preview and execution.
@MainActor
public final class SchemaChangeManager: ObservableObject {
    public let table: DatabaseObject
    public let originalColumns: [TableColumn]
    public let originalIndexes: [TableIndex]
    @Published public private(set) var changes: [PendingSchemaChange] = []

    public init(table: DatabaseObject, columns: [TableColumn], indexes: [TableIndex] = []) {
        self.table = table
        self.originalColumns = columns
        self.originalIndexes = indexes
    }

    public var hasChanges: Bool { !changes.isEmpty }
    public var hasDestructiveChanges: Bool { changes.contains(where: \.isDestructive) }

    public func stageAdd(_ draft: NewTableColumnDraft) throws {
        let column = normalized(draft)
        guard !column.name.isEmpty else { throw SchemaChangeValidationError.blankName }
        guard !column.dataType.isEmpty else { throw SchemaChangeValidationError.blankType }
        guard Self.isSafeSQLFragment(column.dataType),
              column.defaultValue.map(Self.isSafeSQLFragment) ?? true else {
            throw SchemaChangeValidationError.unsafeSQLFragment
        }
        guard !containsColumn(named: column.name) else { throw SchemaChangeValidationError.duplicateColumn(column.name) }
        if !column.isNullable, column.defaultValue == nil {
            throw SchemaChangeValidationError.requiredColumnNeedsDefault
        }
        changes.append(.addColumn(id: UUID(), column: column))
    }

    public func stageRename(_ column: TableColumn, to requestedName: String) throws {
        let newName = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { throw SchemaChangeValidationError.blankName }
        guard newName.caseInsensitiveCompare(column.name) != .orderedSame else {
            throw SchemaChangeValidationError.unchangedName
        }
        guard !containsColumn(named: newName, excludingOriginal: column.name) else {
            throw SchemaChangeValidationError.duplicateColumn(newName)
        }
        changes.removeAll { change in
            if case .renameColumn(_, let oldName, _) = change { return oldName == column.name }
            return false
        }
        changes.append(.renameColumn(id: UUID(), oldName: column.name, newName: newName))
    }

    public func stageDrop(_ column: TableColumn) throws {
        guard !column.isPrimaryKey else { throw SchemaChangeValidationError.primaryKeyDrop(column.name) }
        changes.removeAll { change in
            switch change {
            case .renameColumn(_, let oldName, _): oldName == column.name
            case .dropColumn(_, let existing): existing.name == column.name
            case .addColumn, .addIndex, .dropIndex: false
            }
        }
        changes.append(.dropColumn(id: UUID(), column: column))
    }

    public func stageAddIndex(_ draft: NewTableIndexDraft) throws {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SchemaChangeValidationError.blankName }
        guard !draft.columns.isEmpty else { throw SchemaChangeValidationError.missingIndexColumns }
        guard !containsIndex(named: name) else { throw SchemaChangeValidationError.duplicateIndex(name) }
        let availableColumns = Set(effectiveColumnNames.map { $0.lowercased() })
        if let unknown = draft.columns.first(where: { !availableColumns.contains($0.lowercased()) }) {
            throw SchemaChangeValidationError.unknownIndexColumn(unknown)
        }
        changes.append(.addIndex(
            id: UUID(),
            index: NewTableIndexDraft(name: name, columns: draft.columns, isUnique: draft.isUnique)
        ))
    }

    public func stageDropIndex(_ index: TableIndex) throws {
        let lowercaseName = index.name.lowercased()
        guard lowercaseName != "primary", !lowercaseName.hasPrefix("sqlite_autoindex_") else {
            throw SchemaChangeValidationError.protectedIndex(index.name)
        }
        changes.removeAll { change in
            if case .dropIndex(_, let existing) = change { return existing.name == index.name }
            return false
        }
        changes.append(.dropIndex(id: UUID(), index: index))
    }

    public func remove(id: UUID) {
        changes.removeAll { $0.id == id }
    }

    public func discardAll() {
        changes.removeAll()
    }

    public func statements(for type: DatabaseType) -> [String] {
        let tableName = DatabaseViewModel.qualifiedName(for: table, type: type)
        return changes.map { change in
            switch change {
            case .addColumn(_, let column):
                return "ALTER TABLE \(tableName) ADD COLUMN \(Self.columnDefinition(column, type: type));"
            case .renameColumn(_, let oldName, let newName):
                return "ALTER TABLE \(tableName) RENAME COLUMN \(DatabaseViewModel.quoteIdentifier(oldName, for: type)) TO \(DatabaseViewModel.quoteIdentifier(newName, for: type));"
            case .dropColumn(_, let column):
                return "ALTER TABLE \(tableName) DROP COLUMN \(DatabaseViewModel.quoteIdentifier(column.name, for: type));"
            case .addIndex(_, let index):
                let name = DatabaseViewModel.quoteIdentifier(index.name, for: type)
                let columns = index.columns.map { DatabaseViewModel.quoteIdentifier($0, for: type) }.joined(separator: ", ")
                let unique = index.isUnique ? "UNIQUE " : ""
                switch type {
                case .mysql: return "ALTER TABLE \(tableName) ADD \(unique)INDEX \(name) (\(columns));"
                case .sqlite, .postgresql: return "CREATE \(unique)INDEX \(name) ON \(tableName) (\(columns));"
                case .redis: return ""
                }
            case .dropIndex(_, let index):
                let name = DatabaseViewModel.quoteIdentifier(index.name, for: type)
                switch type {
                case .mysql: return "ALTER TABLE \(tableName) DROP INDEX \(name);"
                case .postgresql:
                    if let schema = table.schema, !schema.isEmpty {
                        return "DROP INDEX \(DatabaseViewModel.quoteIdentifier(schema, for: type)).\(name);"
                    }
                    return "DROP INDEX \(name);"
                case .sqlite: return "DROP INDEX \(name);"
                case .redis: return ""
                }
            }
        }.filter { !$0.isEmpty }
    }

    private func containsColumn(named name: String, excludingOriginal: String? = nil) -> Bool {
        let normalizedName = name.lowercased()
        let originals = originalColumns.contains {
            $0.name != excludingOriginal && $0.name.lowercased() == normalizedName
        }
        let additions = changes.contains { change in
            if case .addColumn(_, let column) = change { return column.name.lowercased() == normalizedName }
            if case .renameColumn(_, _, let newName) = change { return newName.lowercased() == normalizedName }
            return false
        }
        return originals || additions
    }

    private var effectiveColumnNames: [String] {
        var names = originalColumns.map(\.name)
        for change in changes {
            switch change {
            case .addColumn(_, let column): names.append(column.name)
            case .renameColumn(_, let oldName, let newName):
                if let index = names.firstIndex(of: oldName) { names[index] = newName }
            case .dropColumn(_, let column): names.removeAll { $0 == column.name }
            case .addIndex, .dropIndex: break
            }
        }
        return names
    }

    private func containsIndex(named name: String) -> Bool {
        originalIndexes.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            || changes.contains {
                if case .addIndex(_, let index) = $0 { return index.name.caseInsensitiveCompare(name) == .orderedSame }
                return false
            }
    }

    private func normalized(_ draft: NewTableColumnDraft) -> NewTableColumnDraft {
        var result = draft
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.dataType = result.dataType.trimmingCharacters(in: .whitespacesAndNewlines)
        result.defaultValue = result.defaultValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.defaultValue?.isEmpty == true { result.defaultValue = nil }
        return result
    }

    private nonisolated static func columnDefinition(_ column: NewTableColumnDraft, type: DatabaseType) -> String {
        var parts = [DatabaseViewModel.quoteIdentifier(column.name, for: type), column.dataType]
        if !column.isNullable { parts.append("NOT NULL") }
        if let defaultValue = column.defaultValue { parts.append("DEFAULT \(defaultValue)") }
        return parts.joined(separator: " ")
    }

    private nonisolated static func isSafeSQLFragment(_ value: String) -> Bool {
        !value.contains(";") && !value.contains("--") && !value.contains("/*") && !value.contains("*/")
    }
}
