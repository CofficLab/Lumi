import MagicKit
import SwiftUI

/// 最近项目持久化覆盖层
/// 在 RootView 出现时恢复最近项目列表和当前项目，监听项目切换保存
struct RecentProjectsPersistenceOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "📋" }

    @EnvironmentObject private var projectVM: ProjectVM

    let content: Content

    @State private var restored = false

    private let store = RecentProjectsStore()

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
            handleProjectPathChange(oldPath: oldPath, newPath: newPath)
        }
        .onCurrentProjectDidChange { name, path in
            handleCurrentProjectDidChange(name: name, path: path)
        }
    }
}

// MARK: - View

// MARK: - Action

extension RecentProjectsPersistenceOverlay {
    private func restoreIfNeeded() {
        guard !restored else { return }
        setRestored(true)

        // 恢复最近项目列表到 projectVM
        let projects = store.loadProjects()
        projectVM.setRecentProjects(projects)

        // 恢复当前项目到 projectVM
        if let currentProject = store.getCurrentProject() {
            if Self.verbose {
                AgentRecentProjectsPlugin.logger.info("\(Self.t)📋 已从工具同步项目到 VM：\(currentProject.name)")
            }
            projectVM.switchProject(to: currentProject)
        }
    }
}

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

    /// 处理 SetCurrentProjectTool 发出的事件，同步到 ProjectVM
    private func handleCurrentProjectDidChange(name: String, path: String) {
        // 如果路径与当前项目相同，无需切换
        guard projectVM.currentProjectPath != path else { return }

        // 同步到 ProjectVM：优先从最近项目列表中找到匹配 Project
        let projects = store.loadProjects()
        if let matched = projects.first(where: { $0.path == path }) {
            projectVM.switchProject(to: matched)
        }
    }
}

// MARK: - Preview

#Preview("Recent Projects Persistence Overlay") {
    RecentProjectsPersistenceOverlay(content: Text("Content"))
        .inRootView()
}
