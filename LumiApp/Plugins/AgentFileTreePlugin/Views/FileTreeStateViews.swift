import SwiftUI

/// 文件树加载状态视图
struct FileTreeLoadingView: View {
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
            Text(String(localized: "Loading...", table: "ProjectTree"))
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 24)
        .padding(.vertical, 4)
    }
}

/// 文件树空目录视图
struct FileTreeEmptyView: View {
    var body: some View {
        Text(String(localized: "Empty folder", table: "ProjectTree"))
            .font(.system(size: 10))
            .foregroundColor(AppUI.Color.semantic.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24)
            .padding(.vertical, 4)
    }
}

/// 文件树无项目视图（未选择项目）
struct FileTreeNoProjectView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "No project", table: "ProjectTree"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        FileTreeLoadingView()
        FileTreeEmptyView()
        FileTreeNoProjectView()
    }
    .frame(width: 200)
}