import LumiUI
import SwiftUI

/// 项目状态栏视图
///
/// 在 ChatPanel 激活时，于状态栏左侧显示当前项目图标，
/// 点击弹出项目列表 Popover 以快速切换项目。
struct ProjectStatusBarView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        if projectVM.isProjectSelected {
            StatusBarHoverContainer(
                detailView: ProjectsSidebarView(),
                popoverWidth: 320,
                id: "projects-status"
            ) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.appMicroEmphasized)

                    Text(projectVM.currentProjectName)
                        .font(.appMicro)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview("Project Status Bar") {
    ProjectStatusBarView()
        .frame(height: 30)
        .inRootView()
}
