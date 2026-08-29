import LumiUI
import SwiftUI

/// 缓存清理扫描控制栏
struct CacheScanControlBar: View {
    @ObservedObject var viewModel: CacheCleanerViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? PluginDiskManagerLocalization.string("Stop Scanning")
                    : PluginDiskManagerLocalization.string("Scan System Caches"),
                systemImage: viewModel.isScanning ? "stop.circle" : "doc.badge.gearshape",
                style: viewModel.isScanning ? .destructive : .primary,
                action: {
                    if viewModel.isScanning {
                        viewModel.stopScan()
                    } else {
                        viewModel.scan()
                    }
                }
            )

            Spacer()

            Text(PluginDiskManagerLocalization.string("Scan scope: User Home"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

