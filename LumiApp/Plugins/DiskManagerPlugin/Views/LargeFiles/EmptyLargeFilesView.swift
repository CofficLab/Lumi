import SwiftUI

/// 空大文件列表视图
struct EmptyLargeFilesView: View {
    @ObservedObject var viewModel: DiskManagerViewModel

    init(viewModel: DiskManagerViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ContentUnavailableView {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                .padding(.bottom, 8)
        } description: {
            VStack(spacing: 12) {
                Text("暂无大文件")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Button(action: {
                    viewModel.startScan()
                }) {
                    Label {
                        Text("开始扫描")
                    } icon: {
                        Image(systemName: "magnifyingglass.circle")
                    }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.semantic.info)
            }
        }
    }
}
