import Foundation
import LanguageServerProtocol

@MainActor
final class DocumentSymbolProvider: ObservableObject, SuperEditorDocumentSymbolProvider {
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
                applySymbols(result.map { EditorDocumentSymbolItem(symbol: $0) })
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

    func applySymbols(_ symbols: [EditorDocumentSymbolItem]) {
        self.symbols = symbols
    }

    func activeItems(for line: Int) -> [EditorDocumentSymbolItem] {
        symbols.compactMap { $0.activeItems(for: line) }
            .max(by: { $0.count < $1.count }) ?? []
    }

    func activePathIDs(for line: Int) -> [String] {
        activeItems(for: line).map(\.id)
    }

    func activeAncestorIDs(for line: Int) -> Set<String> {
        Set(activePathIDs(for: line).dropLast())
    }
}
