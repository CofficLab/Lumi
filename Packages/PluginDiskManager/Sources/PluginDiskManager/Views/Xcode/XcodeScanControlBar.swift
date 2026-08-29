import LumiUI
import SwiftUI

/// Xcode 清理扫描控制栏
struct XcodeScanControlBar: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? PluginDiskManagerLocalization.string("Stop Scanning")
                    : PluginDiskManagerLocalization.string("Scan Xcode"),
                systemImage: viewModel.isScanning ? "stop.circle" : "hammer",
                style: viewModel.isScanning ? .destructive : .primary,
                action: {
                    if viewModel.isScanning {
                        viewModel.stopScan()
                    } else {
                        Task { await viewModel.scanAll() }
                    }
                }
            )

            Spacer()

            Text(PluginDiskManagerLocalization.string("Scan scope: Xcode-related cache directories"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

