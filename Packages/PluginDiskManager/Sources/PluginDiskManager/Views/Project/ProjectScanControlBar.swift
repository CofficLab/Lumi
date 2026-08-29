import LumiUI
import SwiftUI

/// 项目清理扫描控制栏
struct ProjectScanControlBar: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? PluginDiskManagerLocalization.string("Stop Scanning")
                    : PluginDiskManagerLocalization.string("Scan Project Dependencies"),
                systemImage: viewModel.isScanning ? "stop.circle" : "folder.badge.gearshape",
                style: viewModel.isScanning ? .destructive : .primary,
                action: {
                    if viewModel.isScanning {
                        viewModel.stopScan()
                    } else {
                        Task { await viewModel.scanProjects() }
                    }
                }
            )

            Spacer()

            Text(PluginDiskManagerLocalization.string("Scan scope: Code, Projects, Developer directories"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

