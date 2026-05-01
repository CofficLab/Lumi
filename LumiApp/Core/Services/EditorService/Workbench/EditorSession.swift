import Foundation
import AppKit
import LanguageServerProtocol

@MainActor
final class EditorSession: ObservableObject, Identifiable {
    let id: UUID

    @Published var fileURL: URL?
    @Published var multiCursorState: MultiCursorState
    @Published private var storedPanelState: EditorPanelSessionState
    @Published var isDirty: Bool
    @Published var findReplaceState: EditorFindReplaceState
    @Published var scrollState: EditorScrollState
    @Published var viewState: EditorViewState
    @Published var foldingState: EditorFoldingState

    var mouseHoverContent: String? { storedPanelState.mouseHoverContent }
    var mouseHoverSymbolRect: CGRect { storedPanelState.mouseHoverSymbolRect }
    var referenceResults: [ReferenceResult] { storedPanelState.referenceResults }
    var isReferencePanelPresented: Bool { storedPanelState.isReferencePanelPresented }
    var isWorkspaceSymbolSearchPresented: Bool { storedPanelState.isWorkspaceSymbolSearchPresented }
    var isCallHierarchyPresented: Bool { storedPanelState.isCallHierarchyPresented }
    var problemDiagnostics: [Diagnostic] { storedPanelState.problemDiagnostics }
    var selectedProblemDiagnostic: Diagnostic? { storedPanelState.selectedProblemDiagnostic }
    var isProblemsPanelPresented: Bool { storedPanelState.isProblemsPanelPresented }
    var panelSnapshot: EditorPanelSnapshot { storedPanelState.snapshot }

    var panelState: EditorPanelSessionState {
        get { storedPanelState }
        set { storedPanelState = newValue }
    }

    init(
        id: UUID = UUID(),
        fileURL: URL? = nil,
        multiCursorState: MultiCursorState = MultiCursorState(),
        panelState: EditorPanelSessionState = EditorPanelSessionState(),
        isDirty: Bool = false,
        findReplaceState: EditorFindReplaceState = EditorFindReplaceState(),
        scrollState: EditorScrollState = EditorScrollState(),
        viewState: EditorViewState = EditorViewState(),
        foldingState: EditorFoldingState = EditorFoldingState()
    ) {
        self.id = id
        self.fileURL = fileURL
        self.multiCursorState = multiCursorState
        self.storedPanelState = panelState
        self.isDirty = isDirty
        self.findReplaceState = findReplaceState
        self.scrollState = scrollState
        self.viewState = viewState
        self.foldingState = foldingState
    }

    convenience init(snapshot: EditorSession, preservingID: Bool = true) {
        self.init(
            id: preservingID ? snapshot.id : UUID(),
            fileURL: snapshot.fileURL,
            multiCursorState: snapshot.multiCursorState,
            panelState: snapshot.panelState,
            isDirty: snapshot.isDirty,
            findReplaceState: snapshot.findReplaceState,
            scrollState: snapshot.scrollState,
            viewState: snapshot.viewState,
            foldingState: snapshot.foldingState
        )
    }

    func applySnapshot(from snapshot: EditorSession) {
        fileURL = snapshot.fileURL
        multiCursorState = snapshot.multiCursorState
        panelState = snapshot.panelState
        isDirty = snapshot.isDirty
        findReplaceState = snapshot.findReplaceState
        scrollState = snapshot.scrollState
        viewState = snapshot.viewState
        foldingState = snapshot.foldingState
    }

    func reset() {
        fileURL = nil
        multiCursorState = MultiCursorState()
        panelState = .init()
        isDirty = false
        findReplaceState = EditorFindReplaceState()
        scrollState = EditorScrollState()
        viewState = .initial
        foldingState = EditorFoldingState()
    }
}
