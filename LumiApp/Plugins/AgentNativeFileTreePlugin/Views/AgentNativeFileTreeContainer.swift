import SwiftUI
import MagicKit

/// 高性能文件树容器视图
struct AgentNativeFileTreeContainer: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 文件树
            if !projectViewModel.currentProjectPath.isEmpty {
                FileTreeView(
                    rootURL: URL(fileURLWithPath: projectViewModel.currentProjectPath),
                    onSelect: { url in
                        // 处理文件选择
                    }
                )
            } else {
                emptyView
            }
        }
        .padding(.vertical, 8)
        .background(.background.opacity(0.8))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("文件树")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
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
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
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
