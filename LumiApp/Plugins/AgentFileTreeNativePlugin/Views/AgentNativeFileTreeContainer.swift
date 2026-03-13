import SwiftUI
import MagicKit

/// 高性能文件树容器视图
struct AgentNativeFileTreeContainer: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    /// 折叠状态
    @AppStorage("Sidebar_FileTree_Expanded") private var isExpanded: Bool = true
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.1))

                // 文件树
                if !projectViewModel.currentProjectPath.isEmpty {
                    FileTreeView(
                        rootURL: URL(fileURLWithPath: projectViewModel.currentProjectPath),
                        onSelect: { url in
                            projectViewModel.selectFile(at: url)
                        }
                    )
                } else {
                    emptyView
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)

                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text("文件树")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            if !projectViewModel.currentProjectPath.isEmpty {
                Text(projectViewModel.currentProjectPath)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无项目")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AgentNativeFileTreeContainer()
        .environmentObject(ProjectViewModel())
        .frame(width: 250, height: 400)
}
