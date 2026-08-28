import EditorService
import EditorSource
import SwiftUI

/// Host-owned standard source editor surface.
///
/// Workspace shells consume this view through `EditorSurfaceProviding`, keeping
/// concrete `EditorService` and `EditorSource` types behind the host boundary.
struct EditorSurfaceView: View {
    @ObservedObject var state: EditorState

    private let adapter = SourceEditorAdapter()

    @State private var textCoordinator: EditorCoordinator?
    @State private var cursorCoordinator: CursorCoordinator?
    @State private var scrollCoordinator: ScrollCoordinator?
    @State private var contextMenuCoordinator: ContextMenuCoordinator?

    init(state: EditorState) {
        _state = ObservedObject(wrappedValue: state)
    }

    var body: some View {
        Group {
            if let content = state.content,
               textCoordinator != nil,
               cursorCoordinator != nil,
               scrollCoordinator != nil,
               contextMenuCoordinator != nil {
                SourceEditor(
                    content,
                    language: adapter.resolvedLanguage(for: state),
                    configuration: adapter.configuration(
                        for: state,
                        completionTriggerCharacters: state.lspClient.completionTriggerCharacters()
                    ),
                    state: sourceEditorBinding,
                    coordinators: activeCoordinators
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.isFileLoadInProgress {
                ProgressView("Opening file…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No file open",
                    systemImage: "doc.text",
                    description: Text("Select a file from the Explorer to begin editing.")
                )
            }
        }
        .onAppear(perform: initializeCoordinators)
    }

    private func initializeCoordinators() {
        if textCoordinator == nil {
            let coordinator = EditorCoordinator(state: state)
            coordinator.jumpDelegate = state.jumpDelegate
            textCoordinator = coordinator
        }
        if cursorCoordinator == nil { cursorCoordinator = CursorCoordinator(state: state) }
        if scrollCoordinator == nil { scrollCoordinator = ScrollCoordinator(state: state) }
        if contextMenuCoordinator == nil { contextMenuCoordinator = ContextMenuCoordinator(state: state) }
    }

    private var activeCoordinators: [TextViewCoordinator] {
        adapter.activeCoordinators(
            textCoordinator: textCoordinator,
            cursorCoordinator: cursorCoordinator,
            scrollCoordinator: scrollCoordinator,
            contextMenuCoordinator: contextMenuCoordinator,
            hoverCoordinator: nil
        )
    }

    private var sourceEditorBinding: Binding<SourceEditorState> {
        Binding(
            get: {
                var editorState = state.editorState
                editorState.scrollPosition = nil
                return editorState
            },
            set: { newState in
                let update = EditorSourceEditorBindingController.update(
                    from: newState,
                    multiCursorSelectionCount: state.multiCursorState.all.count,
                    currentFindReplaceState: state.activeSession.findReplaceState
                )
                DispatchQueue.main.async {
                    state.applySourceEditorBindingUpdate(update)
                }
            }
        )
    }
}
