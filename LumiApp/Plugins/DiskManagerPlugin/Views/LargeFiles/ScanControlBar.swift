import LumiUI
import SwiftUI

/// 扫描控制栏视图 - 用于启动/停止扫描操作
struct ScanControlBar: View {
    @ObservedObject var viewModel: DiskManagerViewModel
    private let scanText: String
    private let scanningText: String
    private let icon: String
    private let scanningIcon: String
    private let description: String

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
            AppButton(
                viewModel.isScanning ? scanningText : scanText,
                systemImage: viewModel.isScanning ? scanningIcon : icon,
                style: viewModel.isScanning ? .destructive : .primary,
                action: {
                    if viewModel.isScanning {
                        viewModel.stopScan()
                    } else {
                        viewModel.startScan()
                    }
                }
            )

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

#Preview("目录扫描") {
    ScanControlBar(forDirectoryTree: DiskManagerViewModel())
        .padding()
}
