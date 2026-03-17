import SwiftUI

/// 项目清理扫描进度视图
struct ProjectScanProgressView: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Color.semantic.warning)

            Text("正在扫描项目...")
                .font(.headline)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("正在扫描常见目录中的项目...")
                .font(.subheadline)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProjectScanProgressView(viewModel: ProjectCleanerViewModel())
        .padding()
}
