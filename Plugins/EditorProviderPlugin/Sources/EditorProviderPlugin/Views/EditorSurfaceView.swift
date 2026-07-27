import EditorService
import EditorSource
import EditorTextView
import LumiUI
import SwiftUI

/// 最小可用的源码编辑器视图。
///
/// 由 `EditorState` 驱动，组装 `SourceEditor` 与基础协调器（文本/光标/滚动/右键菜单），
/// 提供真正的代码编辑能力。LSP、hover、rename、code-action 等 overlay 暂未接入，
/// 后续按需补回。
struct EditorSurfaceView: View {
    @ObservedObject var state: EditorState

    private let adapter = SourceEditorAdapter()

    /// 基础协调器（@State 保证在 View 更新间保持同一实例）
    @State private var textCoordinator: EditorCoordinator?
    @State private var cursorCoordinator: CursorCoordinator?
    @State private var scrollCoordinator: ScrollCoordinator?
    @State private var contextMenuCoordinator: ContextMenuCoordinator?

    init(state: EditorState) {
        self._state = ObservedObject(wrappedValue: state)
    }

    var body: some View {
        Group {
            if let content = state.content,
               textCoordinator != nil,
               cursorCoordinator != nil,
               contextMenuCoordinator != nil {
                SourceEditor(
                    content,
                    language: adapter.resolvedLanguage(for: state),
                    configuration: buildConfiguration(),
                    state: sourceEditorBinding,
                    coordinators: activeCoordinators
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No file content")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { initializeCoordinators() }
    }

    // MARK: - Coordinators

    private func initializeCoordinators() {
        if textCoordinator == nil { textCoordinator = EditorCoordinator(state: state) }
        if cursorCoordinator == nil { cursorCoordinator = CursorCoordinator(state: state) }
        if scrollCoordinator == nil { scrollCoordinator = ScrollCoordinator(state: state) }
        if contextMenuCoordinator == nil { contextMenuCoordinator = ContextMenuCoordinator(state: state) }
    }

    private var activeCoordinators: [TextViewCoordinator] {
        var result: [TextViewCoordinator] = []
        if let textCoordinator { result.append(textCoordinator) }
        if let cursorCoordinator { result.append(cursorCoordinator) }
        if let scrollCoordinator { result.append(scrollCoordinator) }
        if let contextMenuCoordinator { result.append(contextMenuCoordinator) }
        return result
    }

    // MARK: - Configuration

    @MainActor
    private func buildConfiguration() -> SourceEditorConfiguration {
        adapter.configuration(for: state, completionTriggerCharacters: [])
    }

    // MARK: - Binding

    /// 提供给 SourceEditor 的安全 Binding。
    ///
    /// - get 中清空 scrollPosition，避免滚动位置反馈循环；
    /// - set 中延迟回写 @Published，避免 "publishing during view updates"。
    private var sourceEditorBinding: Binding<SourceEditorState> {
        Binding<SourceEditorState>(
            get: {
                var result = state.editorState
                result.scrollPosition = nil
                return result
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
