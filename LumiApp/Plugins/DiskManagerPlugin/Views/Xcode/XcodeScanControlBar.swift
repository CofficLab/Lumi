import SwiftUI

/// Xcode 清理扫描控制栏
struct XcodeScanControlBar: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        HStack {
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScan()
                } else {
                    Task { await viewModel.scanAll() }
                }
            }, label: {
                Label(
                    title: { Text(viewModel.isScanning ? "停止扫描" : "扫描 Xcode") },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "hammer") }
                )
                .font(AppUI.Typography.bodyEmphasized)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? AppUI.Color.semantic.error : AppUI.Color.semantic.info)

            Spacer()

            Text("扫描范围：Xcode 相关缓存目录")
                .font(.caption)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    XcodeScanControlBar(viewModel: XcodeCleanerViewModel())
        .padding()
}
