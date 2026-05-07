import Foundation
import LanguageServerProtocol
import Combine

@MainActor
public final class EditorDocumentSymbolProviderCore: ObservableObject {
    private let requestLifecycle = LSPRequestLifecycle()
    private let requestDocumentSymbols: @Sendable () async -> [DocumentSymbol]

    public init(
        requestDocumentSymbols: @escaping @Sendable () async -> [DocumentSymbol]
    ) {
        self.requestDocumentSymbols = requestDocumentSymbols
    }

    @Published public private(set) var symbols: [EditorDocumentSymbolItem] = []
    @Published public private(set) var isLoading: Bool = false

    public func refresh() {
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

    public func clear() {
        requestLifecycle.reset()
        symbols = []
        isLoading = false
    }

    public func reset() {
        requestLifecycle.reset()
    }

    public func applySymbols(_ symbols: [EditorDocumentSymbolItem]) {
        self.symbols = symbols
    }

    public func activeItems(for line: Int) -> [EditorDocumentSymbolItem] {
        symbols.compactMap { $0.activeItems(for: line) }
            .max(by: { $0.count < $1.count }) ?? []
    }

    public func activePathIDs(for line: Int) -> [String] {
        activeItems(for: line).map(\.id)
    }

    public func activeAncestorIDs(for line: Int) -> Set<String> {
        Set(activePathIDs(for: line).dropLast())
    }
}
