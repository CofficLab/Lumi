import SwiftUI

/// 扫描控制栏视图 - 用于启动/停止扫描操作
struct ScanControlBar: View {
    @ObservedObject var viewModel: DiskManagerViewModel
    let scanText: String
    let scanningText: String
    let icon: String
    let scanningIcon: String
    let description: String

    /// 大文件扫描控制栏
    init(forLargeFiles viewModel: DiskManagerViewModel) {
        self.viewModel = viewModel
        self.scanText = "扫描大文件"
        self.scanningText = "停止扫描"
        self.icon = "magnifyingglass.circle"
        self.scanningIcon = "stop.circle"
        self.description = "扫描目录：用户主目录"
    }

    /// 目录树扫描控制栏
    init(forDirectoryTree viewModel: DiskManagerViewModel) {
        self.viewModel = viewModel
        self.scanText = "扫描目录"
        self.scanningText = "停止扫描"
        self.icon = "folder.badge.plus"
        self.scanningIcon = "stop.circle"
        self.description = "扫描目录：用户主目录"
    }

    var body: some View {
        HStack {
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScan()
                } else {
                    viewModel.startScan()
                }
            }, label: {
                Label(title: { Text(viewModel.isScanning ? scanningText : scanText) }, icon: {
                    Image(systemName: viewModel.isScanning ? scanningIcon : icon)
                })
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? DesignTokens.Color.semantic.error : DesignTokens.Color.semantic.info)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview("大文件扫描") {
    ScanControlBar(forLargeFiles: DiskManagerViewModel())
        .padding()
}

#Preview("目录扫描") {
    ScanControlBar(forDirectoryTree: DiskManagerViewModel())
        .padding()
}