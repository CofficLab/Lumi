import Foundation

@MainActor
final class EditorBreadcrumbContextBridge: ObservableObject {
    static let shared = EditorBreadcrumbContextBridge()

    @Published private(set) var currentFileURL: URL?
    @Published private(set) var activeSymbolTrail: [EditorDocumentSymbolItem] = []

    var openSymbol: ((EditorDocumentSymbolItem) -> Void)?

    private init() {}

    func update(
        currentFileURL: URL?,
        activeSymbolTrail: [EditorDocumentSymbolItem],
        openSymbol: ((EditorDocumentSymbolItem) -> Void)? = nil
    ) {
        self.currentFileURL = currentFileURL
        self.activeSymbolTrail = activeSymbolTrail
        self.openSymbol = openSymbol
    }
}
