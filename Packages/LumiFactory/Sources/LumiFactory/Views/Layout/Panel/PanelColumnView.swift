import EditorService
import LumiKernel
import LumiUI
import SwiftUI

/// 主面板列，包含 Rail 和面板工作区
struct PanelColumnView: View {
    @ObservedObject var kernel: LumiKernel

    let editor: any LumiEditorServicing

    private var showRail: Bool {
        kernel.layoutManager?.isRailVisible ?? true
    }

    var body: some View {
        if showRail {
            HSplitView {
                RailView(kernel: kernel)
                PanelView(kernel: kernel)
            }
            .id(kernel.layoutManager?.activeViewContainerID ?? "main")
            .background(
                SplitViewDividerPersistence.rail(
                    layoutState: kernel.layoutManager?.layoutState ?? LayoutState(),
                    viewContainerID: kernel.layoutManager?.activeViewContainerID ?? "main"
                )
            )
        } else {
            PanelView(kernel: kernel)
        }
    }
}
