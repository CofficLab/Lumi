import Foundation
import Combine
import LanguageServerProtocol

/// 工作区符号搜索提供者
@MainActor
final class WorkspaceSymbolProvider: ObservableObject, SuperEditorWorkspaceSymbolProvider {
    
    private let lspService: LSPService
    private let requestLifecycle = LSPRequestLifecycle()
    private let requestSymbols: @Sendable (_ query: String) async -> WorkspaceSymbolResponse
    var preflightMessageProvider: @MainActor (_ operation: String, _ strength: EditorSemanticPreflightStrength) -> String?

    init(
        lspService: LSPService = .shared,
        preflightMessageProvider: @escaping @MainActor (_ operation: String, _ strength: EditorSemanticPreflightStrength) -> String? = { _, _ in nil },
        requestSymbols: (@Sendable (_ query: String) async -> WorkspaceSymbolResponse)? = nil
    ) {
        self.lspService = lspService
        self.preflightMessageProvider = preflightMessageProvider
        self.requestSymbols = requestSymbols ?? { [lspService] query in
            await lspService.requestWorkspaceSymbols(query: query)
        }
    }
    
    @Published var symbols: [WorkspaceSymbolItem] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func searchSymbols(query: String) async {
        isSearching = true
        searchError = nil

        if let message = preflightMessageProvider("Workspace Symbols", .hard) {
            isSearching = false
            searchError = message
            symbols = []
            return
        }

        requestLifecycle.run(
            operation: { [requestSymbols] in
                await requestSymbols(query)
            },
            apply: { [weak self] response in
                guard let self else { return }
                isSearching = false

                guard let response else {
                    searchError = nil
                    symbols = []
                    return
                }

                searchError = nil

                switch response {
                case .optionA(let infos):
                    symbols = infos.map { info in
                        WorkspaceSymbolItem(
                            name: info.name, kind: info.kind,
                            location: SymbolLocation(uri: info.location.uri, range: info.location.range),
                            containerName: info.containerName, tags: info.tags, detail: nil, data: nil
                        )
                    }
                case .optionB(let wsSymbols):
                    symbols = wsSymbols.compactMap { ws -> WorkspaceSymbolItem? in
                        guard let locOpt = ws.location else { return nil }
                        switch locOpt {
                        case .optionA(let loc):
                            return WorkspaceSymbolItem(
                                name: ws.name, kind: ws.kind,
                                location: SymbolLocation(uri: loc.uri, range: loc.range),
                                containerName: nil, tags: ws.tags, detail: nil, data: nil
                            )
                        case .optionB(let identifier):
                            return WorkspaceSymbolItem(
                                name: ws.name, kind: ws.kind,
                                location: SymbolLocation(uri: identifier.uri, range: LSPRange(start: .zero, end: .zero)),
                                containerName: nil, tags: ws.tags, detail: nil, data: nil
                            )
                        }
                    }
                }
            }
        )
    }
    
    func clear() {
        requestLifecycle.reset()
        symbols = []
        isSearching = false
        searchError = nil
    }

    func reset() {
        requestLifecycle.reset()
    }
    
    func filterLocalResults(query: String) -> [WorkspaceSymbolItem] {
        guard !query.isEmpty else { return symbols }
        let lowercased = query.lowercased()
        return symbols.filter { sym in
            sym.name.lowercased().contains(lowercased)
                || (sym.containerName?.lowercased().contains(lowercased) ?? false)
        }
    }
}
