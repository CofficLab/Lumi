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

public enum PendingSchemaChange: Identifiable, Equatable, Sendable {
    case addColumn(id: UUID, column: NewTableColumnDraft)
    case renameColumn(id: UUID, oldName: String, newName: String)
    case dropColumn(id: UUID, column: TableColumn)

    public var id: UUID {
        switch self {
        case .addColumn(let id, _), .renameColumn(let id, _, _), .dropColumn(let id, _): id
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

    public var errorDescription: String? {
        switch self {
        case .blankName: "Column name cannot be empty."
        case .blankType: "Column type cannot be empty."
        case .duplicateColumn(let name): "A column named ‘\(name)’ already exists."
        case .unchangedName: "Enter a different column name."
        case .primaryKeyDrop(let name): "Primary key column ‘\(name)’ cannot be dropped in this version."
        case .requiredColumnNeedsDefault: "A NOT NULL column added to an existing table requires a default value."
        case .unsafeSQLFragment: "Column type or default contains an unsafe SQL fragment."
        }
    }
}

/// Stages a conservative subset of table structure changes before SQL preview and execution.
@MainActor
public final class SchemaChangeManager: ObservableObject {
    public let table: DatabaseObject
    public let originalColumns: [TableColumn]
    @Published public private(set) var changes: [PendingSchemaChange] = []

    public init(table: DatabaseObject, columns: [TableColumn]) {
        self.table = table
        self.originalColumns = columns
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
            case .addColumn: false
            }
        }
        changes.append(.dropColumn(id: UUID(), column: column))
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
            }
        }
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
