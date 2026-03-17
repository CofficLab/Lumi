import SwiftUI

/// 大文件扫描控制栏视图 - 用于启动/停止扫描操作
struct LargeFilesScanControlBar: View {
    @ObservedObject var viewModel: LargeFilesViewModel

    var body: some View {
        HStack {
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScan()
                } else {
                    viewModel.startScan()
                }
            }, label: {
                Label(
                    title: { Text(viewModel.isScanning ? "停止扫描" : "扫描大文件") },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "magnifyingglass.circle") }
                )
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? DesignTokens.Color.semantic.error : DesignTokens.Color.semantic.info)

            Spacer()

            Text("扫描目录：用户主目录")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    LargeFilesScanControlBar(viewModel: LargeFilesViewModel())
        .padding()
}

