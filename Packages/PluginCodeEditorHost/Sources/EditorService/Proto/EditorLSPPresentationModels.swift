import Foundation
import LanguageServerProtocol

// MARK: - Signature Help

public struct SignatureHelpItem: Identifiable {
    public let id: UUID
    public let label: String
    public let documentation: String?
    public let parameters: [SignatureParam]
    public let activeParameterIndex: Int

    public init(
        id: UUID = UUID(),
        label: String,
        documentation: String?,
        parameters: [SignatureParam],
        activeParameterIndex: Int
    ) {
        self.id = id
        self.label = label
        self.documentation = documentation
        self.parameters = parameters
        self.activeParameterIndex = activeParameterIndex
    }
}

public struct SignatureParam: Identifiable {
    public let id: UUID
    public let label: String
    public let documentation: String?

    public init(id: UUID = UUID(), label: String, documentation: String?) {
        self.id = id
        self.label = label
        self.documentation = documentation
    }
}

// MARK: - Inlay Hints

public struct InlayHintItem: Identifiable {
    public var id: String { "\(line):\(character):\(text)" }
    public let line: Int
    public let character: Int
    public let text: String
    public let kind: InlayHintKind?
    public let tooltip: String?
    public let paddingLeft: Bool
    public let paddingRight: Bool

    public init(
        line: Int,
        character: Int,
        text: String,
        kind: InlayHintKind?,
        tooltip: String?,
        paddingLeft: Bool,
        paddingRight: Bool
    ) {
        self.line = line
        self.character = character
        self.text = text
        self.kind = kind
        self.tooltip = tooltip
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
    }

    public var isTypeHint: Bool { kind == .type }
    public var isParameterHint: Bool { kind == .parameter }
}

// MARK: - Code Actions

public struct CodeActionItem: Identifiable {
    public enum Payload {
        case lsp(CodeAction)
        case plugin(EditorCodeActionSuggestion)
    }

    public let id: UUID
    public let title: String
    public let kind: String
    public let payload: Payload
    public let isPreferred: Bool

    public init(title: String, kind: String, payload: Payload, isPreferred: Bool, id: UUID = UUID()) {
        self.id = id
        self.title = title
        self.kind = kind
        self.payload = payload
        self.isPreferred = isPreferred
    }

    public var icon: String {
        if kind == "plugin" {
            return "puzzlepiece.extension"
        }
        if kind.contains("quickfix") {
            return "lightbulb"
        } else if kind.contains("refactor") {
            return "arrow.triangle.2.circlepath"
        } else if kind.contains("source") {
            return "gearshape"
        }
        return "hammer"
    }
}

// MARK: - Workspace Symbols

public struct WorkspaceSymbolItem: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let kind: SymbolKind
    public let location: SymbolLocation
    public let containerName: String?
    public let tags: [SymbolTag]?
    public let detail: String?
    public let data: LanguageServerProtocol.LSPAny?

    public init(
        id: UUID = UUID(),
        name: String,
        kind: SymbolKind,
        location: SymbolLocation,
        containerName: String?,
        tags: [SymbolTag]?,
        detail: String?,
        data: LanguageServerProtocol.LSPAny?
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.location = location
        self.containerName = containerName
        self.tags = tags
        self.detail = detail
        self.data = data
    }

    public var kindDisplayName: String {
        switch kind {
        case .function: return "函数"
        case .method: return "方法"
        case .variable: return "变量"
        case .class: return "类"
        case .interface: return "接口"
        case .struct: return "结构体"
        case .enum: return "枚举"
        case .property: return "属性"
        case .constant: return "常量"
        case .field: return "字段"
        case .typeParameter: return "类型参数"
        default: return String(kind.rawValue)
        }
    }

    public var iconSymbol: String {
        switch kind {
        case .function: return "f.cursive"
        case .method: return "cube"
        case .variable: return "text.word.spacing"
        case .class: return "square.stack"
        case .interface: return "circle.square"
        case .struct: return "box"
        case .enum: return "list.bullet"
        case .property: return "p.circle"
        case .constant: return "c.circle"
        case .field: return "f.circle"
        default: return "doc"
        }
    }
}

public struct SymbolLocation: Equatable {
    public let uri: String
    public let range: LSPRange

    public init(uri: String, range: LSPRange) {
        self.uri = uri
        self.range = range
    }
}

// MARK: - Call Hierarchy

public struct EditorCallHierarchyItem: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let kind: SymbolKind
    public let uri: String
    public let range: LSPRange
    public let selectionRange: LSPRange
    public let data: LanguageServerProtocol.LSPAny?

    public init(
        id: UUID = UUID(),
        name: String,
        kind: SymbolKind,
        uri: String,
        range: LSPRange,
        selectionRange: LSPRange,
        data: LanguageServerProtocol.LSPAny?
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.uri = uri
        self.range = range
        self.selectionRange = selectionRange
        self.data = data
    }

    public init(item: LanguageServerProtocol.CallHierarchyItem) {
        self.init(
            name: item.name,
            kind: item.kind,
            uri: item.uri,
            range: item.range,
            selectionRange: item.selectionRange,
            data: item.data
        )
    }

    public var kindDisplayName: String {
        switch kind {
        case .function: return "函数"
        case .method: return "方法"
        case .constructor: return "构造函数"
        case .class: return "类"
        case .interface: return "接口"
        case .struct: return "结构体"
        case .enum: return "枚举"
        case .enumMember: return "枚举成员"
        default: return String(kind.rawValue)
        }
    }

    public var fileBadge: String {
        WorkspaceEditFileOperations.fileURL(from: uri)?.lastPathComponent ?? "Symbol"
    }

    public var iconSymbol: String {
        switch kind {
        case .function: return "f.cursive"
        case .method: return "cube"
        case .constructor: return "plus.square"
        case .class: return "square.stack"
        case .interface: return "circle.square"
        case .struct: return "box"
        case .enum: return "list.bullet"
        case .enumMember: return "bullet"
        default: return "doc"
        }
    }
}

public struct EditorCallHierarchyCall: Identifiable, Equatable {
    public let id: UUID
    public let item: EditorCallHierarchyItem
    public let fromRanges: [LSPRange]

    public init(
        id: UUID = UUID(),
        item: EditorCallHierarchyItem,
        fromRanges: [LSPRange]
    ) {
        self.id = id
        self.item = item
        self.fromRanges = fromRanges
    }

    public init(item: LanguageServerProtocol.CallHierarchyItem, fromRanges: [LSPRange]) {
        self.init(item: EditorCallHierarchyItem(item: item), fromRanges: fromRanges)
    }
}

// MARK: - Folding

public struct FoldingRangeItem: Identifiable, Hashable {
    public let id: UUID
    public let startLine: Int
    public let endLine: Int
    public let startCharacter: Int?
    public let kind: FoldingRangeKind?
    public var collapsedText: String?

    public init(
        id: UUID = UUID(),
        startLine: Int,
        endLine: Int,
        startCharacter: Int?,
        kind: FoldingRangeKind?,
        collapsedText: String?
    ) {
        self.id = id
        self.startLine = startLine
        self.endLine = endLine
        self.startCharacter = startCharacter
        self.kind = kind
        self.collapsedText = collapsedText
    }

    public var isComment: Bool { kind == .comment }
    public var isImports: Bool { kind == .imports }
    public var isRegion: Bool { kind == .region }
    public var hiddenLineCount: Int { max(0, endLine - startLine) }
}
