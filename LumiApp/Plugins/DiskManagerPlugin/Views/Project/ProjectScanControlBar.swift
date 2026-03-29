import SwiftUI

/// 项目清理扫描控制栏
struct ProjectScanControlBar: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        HStack {
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScan()
                } else {
                    Task { await viewModel.scanProjects() }
                }
            }, label: {
                Label(
                    title: { Text(viewModel.isScanning ? "停止扫描" : "扫描项目") },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "folder.badge.gearshape") }
                )
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? AppUI.Color.semantic.error : AppUI.Color.semantic.warning)

            Spacer()

            Text("扫描范围：Code、Projects、Developer 等目录")
                .font(.caption)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ProjectScanControlBar(viewModel: ProjectCleanerViewModel())
        .padding()
}
