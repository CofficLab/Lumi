import LumiUI
import SwiftUI

/// 大文件扫描控制栏视图 - 用于启动/停止扫描操作
struct LargeFilesScanControlBar: View {
    @ObservedObject var viewModel: LargeFilesViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? PluginDiskManagerLocalization.string("Stop Scanning")
                    : PluginDiskManagerLocalization.string("Scan Large Files"),
                systemImage: viewModel.isScanning ? "stop.circle" : "magnifyingglass.circle",
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

