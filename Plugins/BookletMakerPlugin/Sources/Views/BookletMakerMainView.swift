import SwiftUI

// MARK: - Booklet Maker Main View

/// 主界面视图
/// 上方：拖放区域（固定高度）
/// 下方：示意图（自适应剩余空间）
struct BookletMakerMainView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 上方：拖放区域
            BookletDropZoneView(viewModel: viewModel)

            // 下方：示意图
            BookletExplanationView(settings: viewModel.settings)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Empty State") {
    BookletMakerMainView(viewModel: BookletMakerViewModel())
        .frame(width: 800, height: 600)
}
