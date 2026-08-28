import LumiUI
import SwiftUI

/// Toolbar title view that reflects the currently selected PDF tool.
///
/// 设计要点：
/// 标题随 `viewModel.selectedTool` 动态切换。
///    - `.booklet` → "小册子生成"
///    - `.split`   → "拆分PDF"
///    图标也使用与侧边栏 `PDFTool.systemImage` 一致的 SF Symbol，保持视觉一致。
struct BookletMakerToolbarTitleView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        AppToolbarTitleLabel(
            icon: viewModel.selectedTool.systemImage,
            title: title(for: viewModel.selectedTool)
        )
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
