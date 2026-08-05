import SwiftUI

// MARK: - Booklet Maker Main View

/// 主界面视图，显示拖放区域和示意图。
/// 配置和导出已移至侧边栏 BookletMakerRailView。
struct BookletMakerMainView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        BookletDropZoneView(viewModel: viewModel)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    BookletMakerMainView(viewModel: BookletMakerViewModel())
        .frame(width: 800, height: 500)
}
