import SwiftUI

/// 项目清理扫描控制栏
struct ProjectScanControlBar: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        HStack {
            Button(action: {
                Task { await viewModel.scanProjects() }
            }, label: {
                Label(title: { Text("重新扫描") }, icon: {
                    Image(systemName: "arrow.clockwise")
                })
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Color.semantic.info)
            .disabled(viewModel.isScanning)

            Spacer()

            Text("扫描范围：Code、Projects、Developer 等目录")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ProjectScanControlBar(viewModel: ProjectCleanerViewModel())
        .padding()
}
