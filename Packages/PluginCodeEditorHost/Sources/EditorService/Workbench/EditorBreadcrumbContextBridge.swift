import Foundation

@MainActor
public final class EditorBreadcrumbContextBridge: ObservableObject {
    public static let shared = EditorBreadcrumbContextBridge()

    @Published public private(set) var currentFileURL: URL?
    @Published public private(set) var activeSymbolTrail: [EditorDocumentSymbolItem] = []

    public var openSymbol: ((EditorDocumentSymbolItem) -> Void)?

    private init() {}

    public func update(
        currentFileURL: URL?,
        activeSymbolTrail: [EditorDocumentSymbolItem],
        openSymbol: ((EditorDocumentSymbolItem) -> Void)? = nil
    ) {
        self.currentFileURL = currentFileURL
        self.activeSymbolTrail = activeSymbolTrail
        self.openSymbol = openSymbol
    }
}
