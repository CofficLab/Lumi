import Foundation
import LanguageServerProtocol

public struct EditorDocumentSymbolItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let detail: String?
    public let kind: SymbolKind
    public let range: LSPRange
    public let selectionRange: LSPRange
    public let children: [EditorDocumentSymbolItem]

    public init(symbol: DocumentSymbol, path: [String] = []) {
        self.name = symbol.name
        self.detail = symbol.detail
        self.kind = symbol.kind
        self.range = symbol.range
        self.selectionRange = symbol.selectionRange
        let nextPath = path + [symbol.name]
        self.id = nextPath.joined(separator: "/")
        self.children = symbol.children?.map { EditorDocumentSymbolItem(symbol: $0, path: nextPath) } ?? []
    }

    public init(
        id: String,
        name: String,
        detail: String?,
        kind: SymbolKind,
        range: LSPRange,
        selectionRange: LSPRange,
        children: [EditorDocumentSymbolItem]
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange
        self.children = children
    }

    public var line: Int {
        Int(selectionRange.start.line) + 1
    }

    public var column: Int {
        Int(selectionRange.start.character) + 1
    }

    public var iconSymbol: String {
        switch kind {
        case .class: return "square.stack"
        case .struct: return "shippingbox"
        case .interface: return "circle.square"
        case .enum: return "list.bullet"
        case .enumMember: return "list.bullet.indent"
        case .function: return "f.cursive"
        case .method: return "cube"
        case .property: return "p.circle"
        case .field: return "f.circle"
        case .variable: return "textformat.abc"
        case .constant: return "c.circle"
        case .namespace: return "square.3.layers.3d"
        case .module: return "shippingbox.circle"
        case .constructor: return "plus.square"
        default: return "doc.text"
        }
    }

    public func contains(line: Int) -> Bool {
        let start = Int(range.start.line) + 1
        let end = Int(range.end.line) + 1
        return line >= start && line <= max(end, start)
    }

    public func activePath(for line: Int) -> [String]? {
        guard contains(line: line) else { return nil }
        for child in children {
            if let childPath = child.activePath(for: line) {
                return [id] + childPath
            }
        }
        return [id]
    }

    public func activeItems(for line: Int) -> [EditorDocumentSymbolItem]? {
        guard contains(line: line) else { return nil }
        for child in children {
            if let childItems = child.activeItems(for: line) {
                return [self] + childItems
            }
        }
        return [self]
    }
}
