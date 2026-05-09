import MagicKit
import SwiftUI

/// 编辑器底部面板容器视图
///
/// 作为 Panel Bottom 提供给内核，在编辑器面板下方渲染底部面板。
/// Tab 栏始终显示（参考 VSCode 行为），仅在有活跃面板时展开内容区域。
struct EditorBottomPanelContainerView: View {
    @EnvironmentObject private var editorVM: EditorVM

    var body: some View {
        let service = editorVM.service
        EditorBottomPanelContainerInnerView(
            service: service,
            panelState: service.panelState
        )
    }
}

/// 内部视图：直接 @ObservedObject panelState，
/// 确保 isProblemsPanelPresented 等 @Published 属性变化时能触发重绘。
private struct EditorBottomPanelContainerInnerView: View {
    @ObservedObject var service: EditorService
    @ObservedObject var panelState: EditorPanelState

    var body: some View {
        EditorBottomPanelHostView(service: service)
    }
}
