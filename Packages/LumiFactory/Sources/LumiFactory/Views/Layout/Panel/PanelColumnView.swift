import EditorService
import LumiKernel
import LumiUI
import SwiftUI

/// 主面板列，包含 Rail 和面板工作区
struct PanelColumnView: View {
    @ObservedObject var kernel: LumiKernel

    let editor: any LumiEditorServicing

    private var showRail: Bool {
        kernel.layout?.isRailVisible ?? true
    }

    var body: some View {
        if showRail {
            HSplitView {
                RailView(kernel: kernel)
                PanelView(kernel: kernel)
            }
            .id(kernel.layout?.activeViewContainerID ?? "main")
            .background(
                SplitViewDividerPersistence.rail(
                    layoutState: kernel.layout?.layoutState ?? LayoutState(),
                    viewContainerID: kernel.layout?.activeViewContainerID ?? "main"
                )
            )
        } else {
            PanelView(kernel: kernel)
        }
    }
}
