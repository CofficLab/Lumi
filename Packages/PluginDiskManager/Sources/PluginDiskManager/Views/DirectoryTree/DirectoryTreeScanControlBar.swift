import LumiUI
import SwiftUI

/// 目录结构分析控制栏
struct DirectoryTreeScanControlBar: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? PluginDiskManagerLocalization.string("Stop Analysis")
                    : PluginDiskManagerLocalization.string("Analyze Directory"),
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

            Text(PluginDiskManagerLocalization.string("Scan directory: User Home"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

