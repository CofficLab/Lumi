import KernelLumi
import LumiUI
import SwiftUI

/// Toolbar title view that reflects the currently selected PDF tool.
///
/// 设计要点：
/// 1. 仅在 BookletMaker 容器激活时显示标题，避免在其它容器中残留；
///    容器激活态通过 init 时的 `activeViewContainerID` 快照 + `.activeViewContainerIDDidChange`
///    事件刷新来追踪，避免订阅 workspace 整体的 objectWillChange。
/// 2. 标题随 `viewModel.selectedTool` 动态切换：
///    - `.booklet` → "小册子生成"
///    - `.split`   → "拆分PDF"
///    图标也使用与侧边栏 `PDFTool.systemImage` 一致的 SF Symbol，保持视觉一致。
struct BookletMakerToolbarTitleView: View {
    let containerID: String
    let kernel: KernelLumi
    @ObservedObject var viewModel: BookletMakerViewModel

    @State private var activeContainerID: String?

    init(containerID: String, kernel: KernelLumi, viewModel: BookletMakerViewModel) {
        self.containerID = containerID
        self.kernel = kernel
        self.viewModel = viewModel
        _activeContainerID = State(initialValue: kernel.workspace?.activeViewContainerID)
    }

    var body: some View {
        Group {
            if activeContainerID == containerID {
                AppToolbarTitleLabel(
                    icon: viewModel.selectedTool.systemImage,
                    title: title(for: viewModel.selectedTool)
                )
            }
        }
        .onActiveViewContainerIDDidChange { newContainerID in
            activeContainerID = newContainerID
        }
    }

    /// 根据当前选中的工具返回工具栏中间区域显示的标题文案。
    private func title(for tool: PDFTool) -> String {
        switch tool {
        case .booklet:
            BookletLocalization.string("Booklet Maker")
        case .split:
            BookletLocalization.string("Split PDF")
        }
    }
}