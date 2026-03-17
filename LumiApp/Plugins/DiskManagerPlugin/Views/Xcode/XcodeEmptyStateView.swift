import SwiftUI

/// Xcode 清理空状态视图
struct XcodeEmptyStateView: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Color.semantic.success)

            Text("Xcode 环境很干净！")
                .font(.title2)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("没有发现可清理的缓存文件")
                .font(.subheadline)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Button(action: {
                Task { await viewModel.scanAll() }
            }, label: {
                Label(title: { Text("重新扫描") }, icon: {
                    Image(systemName: "arrow.clockwise")
                })
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Color.semantic.info)
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    XcodeEmptyStateView(viewModel: XcodeCleanerViewModel())
        .padding()
}
