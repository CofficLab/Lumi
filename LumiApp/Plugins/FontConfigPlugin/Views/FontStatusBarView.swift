import SwiftUI
import AppKit

/// 字体配置状态栏入口视图
///
/// 在编辑器底部状态栏右侧显示当前字体名称缩写，
/// 点击后弹出 popover 选择字体。
struct FontStatusBarView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @StateObject private var viewModel = FontConfigViewModel()

    var body: some View {
        StatusBarHoverContainer(
            detailView: FontConfigDetailView(viewModel: viewModel),
            popoverWidth: 320,
            id: "lumi-font-config"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "textformat")
                    .font(.system(size: 11))
                Text(viewModel.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .onAppear {
            viewModel.syncFromEditor(editorVM: editorVM)
        }
    }
}
