import LumiUI
import SwiftUI

/// 目录结构分析控制栏
struct DirectoryTreeScanControlBar: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? String(localized: "停止分析", table: "DiskManager")
                    : String(localized: "分析目录", table: "DiskManager"),
                systemImage: viewModel.isScanning ? "stop.circle" : "folder.badge.gear",
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

            Text(String(localized: "扫描目录：用户主目录", table: "DiskManager"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

#Preview {
    DirectoryTreeScanControlBar(viewModel: DirectoryTreeViewModel())
        .padding()
}
