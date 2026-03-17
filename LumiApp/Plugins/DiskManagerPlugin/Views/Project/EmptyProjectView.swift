import SwiftUI

/// 空项目列表视图
struct EmptyProjectView: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text("未发现可清理的项目")
                .font(.title2)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("已扫描：Code、Projects、Developer 等目录")
                .font(.subheadline)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

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
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    EmptyProjectView(viewModel: ProjectCleanerViewModel())
        .padding()
}
