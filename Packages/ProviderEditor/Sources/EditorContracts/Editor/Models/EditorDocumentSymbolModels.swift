import Foundation

// MARK: - 文档符号模型（契约 V2）

/// 文档符号种类（中立枚举；映射自 LSP SymbolKind 的常用子集）。
public enum EditorDocumentSymbolKind: Equatable, Hashable, Sendable, CaseIterable {
    case file
    case module
    case namespace
    case packageScope
    case `class`
    case method
    case property
    case field
    case constructor
    case `enum`
    case interface
    case function
    case variable
    case constant
    case string
    case number
    case boolean
    case array
    case object
    case key
    case null
    case enumMember
    case `struct`
    case event
    case operatorSymbol
    case typeParameter

    /// 从 LSP SymbolKind rawValue 映射（未知值回退 `.variable`）。
    public init(lspRawValue: Int) {
        guard lspRawValue >= 1, lspRawValue <= Self.allCases.count else {
            self = .variable
            return
        }
        self = Self.allCases[lspRawValue - 1]
    }

    /// 该种类对应的 LSP SymbolKind rawValue（1-based，与 LSP 规范一致）。
    public var lspRawValue: Int { Self.lspRawValue(self) }

    private static func lspRawValue(_ kind: EditorDocumentSymbolKind) -> Int {
        switch kind {
        case .file: return 1
        case .module: return 2
        case .namespace: return 3
        case .packageScope: return 4
        case .class: return 5
        case .method: return 6
        case .property: return 7
        case .field: return 8
        case .constructor: return 9
        case .enum: return 10
        case .interface: return 11
        case .function: return 12
        case .variable: return 13
        case .constant: return 14
        case .string: return 15
        case .number: return 16
        case .boolean: return 17
        case .array: return 18
        case .object: return 19
        case .key: return 20
        case .null: return 21
        case .enumMember: return 22
        case .struct: return 23
        case .event: return 24
        case .operatorSymbol: return 25
        case .typeParameter: return 26
        }
    }
}

/// 单个文档符号（树形，值类型快照）。
public struct EditorDocumentSymbol: Identifiable, Equatable, Sendable {
    /// 稳定标识（符号路径，如 `"MyClass/init()"`）。
    public let id: String

    public let name: String

    public let detail: String?

    public let kind: EditorDocumentSymbolKind

    /// 符号完整范围（zero-based UTF-16）。
    public let range: EditorRange

    /// 选中该符号时应跳转到的范围。
    public let selectionRange: EditorRange

    public let children: [EditorDocumentSymbol]

    public init(
        id: String,
        name: String,
        detail: String? = nil,
        kind: EditorDocumentSymbolKind,
        range: EditorRange,
        selectionRange: EditorRange,
        children: [EditorDocumentSymbol] = []
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange
        self.children = children
    }

    /// 起始行（1-based）。
    public var lineNumber: Int { selectionRange.start.line + 1 }

    /// 该行（1-based）是否落在符号范围内（含边界容差，供面包屑/置顶栏判定）。
    public func contains(line: Int) -> Bool {
        let zeroBased = line - 1
        return zeroBased >= range.start.line && zeroBased <= range.end.line
    }

    /// 从根到该行所在符号的路径（面包屑用）。
    public func activePath(for line: Int) -> [EditorDocumentSymbol] {
        var path: [EditorDocumentSymbol] = []
        var current: EditorDocumentSymbol? = self
        while let symbol = current {
            if symbol.contains(line: line) {
                path.append(symbol)
                current = symbol.children.first { $0.contains(line: line) }
            } else {
                current = nil
            }
        }
        return path
    }
}

/// 扁平化符号树（保留层级顺序，供列表型 UI）。
public extension Array where Element == EditorDocumentSymbol {
    func flattened() -> [EditorDocumentSymbol] {
        flatMap { [$0] + $0.children.flattened() }
    }
}
