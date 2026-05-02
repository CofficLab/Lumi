import MagicKit
import SwiftUI

/// 编辑器底部面板容器视图
///
/// 作为 Panel Bottom 提供给内核，在编辑器面板下方渲染底部面板。
/// 仅在有活跃的底部面板或扩展面板时才显示。
struct EditorBottomPanelContainerView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        if shouldShow {
            EditorBottomPanelHostView(state: state)
        }
    }

    private var shouldShow: Bool {
        // 有活跃的内置底部面板
        state.panelState.activeBottomPanel != nil ||
        // 或有扩展插件贡献的底部面板
        state.editorExtensions.panelSuggestions(state: state).contains {
            $0.placement == .bottom && $0.isPresented(state)
        }
    }
}
