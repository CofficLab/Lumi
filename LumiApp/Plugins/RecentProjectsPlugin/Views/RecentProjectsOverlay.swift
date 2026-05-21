import MagicKit
import SwiftUI

/// 最近项目覆盖层
/// 在 RootView 出现时恢复全局最近项目列表，并在未选项目时显示引导遮罩。
/// 项目切换时自动联动切换到关联的对话。
///
/// 各窗口当前项目的磁盘快照由 `WindowPersistencePlugin` 负责保存。
struct RecentProjectsOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "📋" }

    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var recentProjectsVM: AppProjectsVM
    @EnvironmentObject private var pluginVM: AppPluginVM
    @Environment(\.windowContainer) private var windowContainer

    let content: Content

    @State private var restoreTask: Task<Void, Never>?

    private let store = RecentProjectsStore()

    var body: some View {
        ZStack {
            content

            if shouldShowNoProjectOverlay {
                NoProjectOverlay()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: shouldShowNoProjectOverlay)
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
            handleProjectPathChange(oldPath: oldPath, newPath: newPath)
        }
        .onCurrentProjectDidChange { name, path in
            handleCurrentProjectDidChange(name: name, path: path)
        }
        .onDisappear {
            restoreTask?.cancel()
            restoreTask = nil
        }
    }

    private var shouldShowNoProjectOverlay: Bool {
        !projectVM.isProjectSelected
            && pluginVM.isActivePanelIcon(in: [EditorPlugin.iconName, GitPlugin.iconName])
    }
}

// MARK: - Action

extension RecentProjectsOverlay {
    private func restoreIfNeeded() {
        guard restoreTask == nil else { return }

        restoreTask = Task { @MainActor [store] in
            let projects = await Task.detached(priority: .utility) {
                store.loadProjects()
            }.value
            guard !Task.isCancelled else { return }
            recentProjectsVM.setRecentProjects(projects)

            guard !Task.isCancelled else { return }

            syncProjectFromScopeIfNeeded()
            restoreTask = nil
        }
    }

    private func syncProjectFromScopeIfNeeded() {
        guard let container = windowContainer,
              let path = container.projectPath,
              !path.isEmpty,
              !projectVM.isProjectSelected else { return }

        let name = URL(fileURLWithPath: path).lastPathComponent
        projectVM.switchProject(
            to: Project(name: name, path: path, lastUsed: Date()),
            reason: "syncProjectFromScope"
        )
    }
}

// MARK: - Event Handler

extension RecentProjectsOverlay {
    @MainActor
    private func handleOnAppear() {
        restoreIfNeeded()
    }

    private func handleProjectPathChange(oldPath: String, newPath: String) {
        guard !newPath.isEmpty else { return }
        let name = projectVM.currentProjectName
        store.addProject(name: name, path: newPath)
        NotificationCenter.default.post(name: .windowStateShouldPersist, object: nil)

        guard !oldPath.isEmpty, oldPath != newPath else { return }
        switchConversationForProject(newPath)
    }

    /// 处理 SetCurrentProjectTool 发出的事件，同步到 WindowProjectVM
    private func handleCurrentProjectDidChange(name: String, path: String) {
        guard projectVM.currentProjectPath != path else { return }

        Task { @MainActor [store, path] in
            let projects = await Task.detached(priority: .utility) {
                store.loadProjects()
            }.value
            if let matched = projects.first(where: { $0.path == path }) {
                projectVM.switchProject(to: matched, reason: "currentProjectDidChange")
            }

            switchConversationForProject(path)
        }
    }
}

// MARK: - Project-Conversation Sync

extension RecentProjectsOverlay {
    /// 项目切换时，自动切换到该项目最近使用的对话
    /// 如果该项目没有关联对话，则新建一个
    private func switchConversationForProject(_ projectPath: String) {
        let switched = conversationVM.switchToLatestConversation(forProject: projectPath)

        if switched {
            if Self.verbose {
                if RecentProjectsPlugin.verbose {
                    RecentProjectsPlugin.logger.info("\(Self.t)✅ Switched to latest conversation for project [\(projectPath)]")
                }
            }
            return
        }

        if Self.verbose {
            if RecentProjectsPlugin.verbose {
                RecentProjectsPlugin.logger.info("\(Self.t)📁 No associated conversation for project [\(projectPath)], creating new one")
            }
        }

        Task {
            await conversationVM.createNewConversation(
                projectName: projectVM.currentProjectName,
                projectPath: projectPath,
                languagePreference: projectVM.languagePreference
            )
        }
    }
}

// MARK: - Preview

#Preview("Recent Projects Persistence Overlay") {
    RecentProjectsOverlay(content: Text("Content"))
        .inRootView()
}
