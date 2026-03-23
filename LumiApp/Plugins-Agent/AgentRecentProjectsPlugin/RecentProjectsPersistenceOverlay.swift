import SwiftUI

/// 最近项目持久化覆盖层
/// 在 RootView 出现时恢复最近项目列表和当前项目，监听项目切换保存
struct RecentProjectsPersistenceOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM

    let content: Content

    @State private var restored = false

    private let store = RecentProjectsStore()

    var body: some View {
        content
            .onAppear {
                handleOnAppear()
            }
            .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
                handleProjectPathChange(oldPath: oldPath, newPath: newPath)
            }
    }
}

// MARK: - View

// MARK: - Action

// MARK: - Setter

extension RecentProjectsPersistenceOverlay {
    @MainActor
    private func setRestored(_ value: Bool) {
        restored = value
    }
}

// MARK: - Event Handler

extension RecentProjectsPersistenceOverlay {
    private func handleOnAppear() {
        restoreIfNeeded()
    }

    private func handleProjectPathChange(oldPath: String, newPath: String) {
        // 保存新项目到最近列表
        guard !newPath.isEmpty else { return }
        let name = projectVM.currentProjectName
        store.addProject(name: name, path: newPath)
        
        // 同时更新持久化的当前项目
        store.setCurrentProject(name: name, path: newPath)
    }

    private func restoreIfNeeded() {
        guard !restored else { return }
        setRestored(true)

        // 恢复最近项目列表到 projectVM
        let projects = store.loadProjects()
        projectVM.setRecentProjects(projects)
        
        // 恢复当前项目到 projectVM
        if let currentProject = store.getCurrentProject() {
            projectVM.switchProject(to: currentProject.path)
        }
    }
}

// MARK: - Preview

#Preview("Recent Projects Persistence Overlay") {
    RecentProjectsPersistenceOverlay(content: Text("Content"))
        .inRootView()
}
