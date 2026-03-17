import SwiftUI

/// Xcode 清理扫描控制栏
struct XcodeScanControlBar: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        HStack {
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

            Spacer()

            Text("扫描范围：Xcode 相关缓存目录")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    XcodeScanControlBar(viewModel: XcodeCleanerViewModel())
        .padding()
}
