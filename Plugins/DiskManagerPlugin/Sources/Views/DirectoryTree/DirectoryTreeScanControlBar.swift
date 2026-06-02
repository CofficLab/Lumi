import LumiUI
import SwiftUI

/// 目录结构分析控制栏
struct DirectoryTreeScanControlBar: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? PluginDiskManagerLocalization.string("停止分析")
                    : PluginDiskManagerLocalization.string("分析目录"),
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

            Text(PluginDiskManagerLocalization.string("扫描目录：用户主目录"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

