import SwiftUI
import MagicKit

/// 最近项目侧边栏视图
struct RecentProjectsSidebarView: View {
    @EnvironmentObject var projectVM: ProjectVM
    
    /// 折叠状态
    @AppStorage("Sidebar_RecentProjects_Expanded") private var isExpanded: Bool = true
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            if isExpanded {
                GlassDivider()
                
                // 最近项目列表
                if !recentProjects.isEmpty {
                    recentProjectsList
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
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 16, height: 16)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text(String(localized: "Recent Projects", table: "RecentProjects"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer()
                
                if !recentProjects.isEmpty {
                    GlassBadge(text: "\(recentProjects.count)", style: .neutral)
                }
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
    
    // MARK: - Recent Projects List

    private var recentProjectsList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(recentProjects) { project in
                    projectRow(project)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Project Row

    private func projectRow(_ project: Project) -> some View {
        let isSelected = projectVM.currentProjectPath == project.path
        let isRowHovered = projectVM.currentProjectPath == project.path
        
        return Button(action: {
            switchToProject(project)
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 12))
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                        .lineLimit(1)
                    
                    Text(project.path)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())  // 确保整个区域可点击
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "No Recent Projects", table: "RecentProjects"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Computed Properties
    
    private var recentProjects: [Project] {
        projectVM.recentProjects
    }
    
    // MARK: - Actions
    
    private func switchToProject(_ project: Project) {
        projectVM.switchProject(to: project)
    }
}

#Preview {
    RecentProjectsSidebarView()
        .inRootView()
        .frame(width: 250, height: 400)
}
