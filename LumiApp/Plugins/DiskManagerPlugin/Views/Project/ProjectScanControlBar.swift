import LumiUI
import SwiftUI

/// 项目清理扫描控制栏
struct ProjectScanControlBar: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        HStack {
            AppButton(
                viewModel.isScanning
                    ? String(localized: "停止扫描", table: "DiskManager")
                    : String(localized: "扫描项目", table: "DiskManager"),
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

            Text(String(localized: "扫描范围：Code、Projects、Developer 等目录", table: "DiskManager"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

#Preview {
    ProjectScanControlBar(viewModel: ProjectCleanerViewModel())
        .padding()
}
