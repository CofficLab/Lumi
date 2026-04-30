import Foundation
import LanguageServerProtocol

@MainActor
final class DocumentSymbolProvider: ObservableObject {
    private let requestLifecycle = LSPRequestLifecycle()
    private let requestDocumentSymbols: @Sendable () async -> [DocumentSymbol]

    init(
        requestDocumentSymbols: @escaping @Sendable () async -> [DocumentSymbol]
    ) {
        self.requestDocumentSymbols = requestDocumentSymbols
    }

    @Published private(set) var symbols: [EditorDocumentSymbolItem] = []
    @Published private(set) var isLoading: Bool = false

    func refresh() {
        isLoading = true
        requestLifecycle.run(
            operation: { [requestDocumentSymbols] in
                await requestDocumentSymbols()
            },
            apply: { [weak self] result in
                guard let self else { return }
                isLoading = false
                symbols = result?.map(EditorDocumentSymbolItem.init(symbol:)) ?? []
            }
        )
    }

    func clear() {
        requestLifecycle.reset()
        symbols = []
        isLoading = false
    }

    func reset() {
        requestLifecycle.reset()
    }
}

struct EditorDocumentSymbolItem: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String?
    let kind: SymbolKind
    let range: LSPRange
    let selectionRange: LSPRange
    let children: [EditorDocumentSymbolItem]

    init(symbol: DocumentSymbol, path: [String] = []) {
        self.name = symbol.name
        self.detail = symbol.detail
        self.kind = symbol.kind
        self.range = symbol.range
        self.selectionRange = symbol.selectionRange
        let nextPath = path + [symbol.name]
        self.id = nextPath.joined(separator: "/")
        self.children = symbol.children?.map { EditorDocumentSymbolItem(symbol: $0, path: nextPath) } ?? []
    }

    init(
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

    var line: Int {
        Int(selectionRange.start.line) + 1
    }

    var column: Int {
        Int(selectionRange.start.character) + 1
    }

    var iconSymbol: String {
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

    func contains(line: Int) -> Bool {
        let start = Int(range.start.line) + 1
        let end = Int(range.end.line) + 1
        return line >= start && line <= max(end, start)
    }

    func activePath(for line: Int) -> [String]? {
        guard contains(line: line) else { return nil }
        for child in children {
            if let childPath = child.activePath(for: line) {
                return [id] + childPath
            }
        }
        return [id]
    }
}
