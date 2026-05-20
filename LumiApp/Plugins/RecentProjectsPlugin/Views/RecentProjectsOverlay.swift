import MagicKit
import SwiftUI

/// 最近项目覆盖层
/// 在 RootView 出现时恢复全局最近项目列表，并在未选项目时显示引导遮罩。
/// 项目切换时自动联动切换到关联的对话。
///
/// 各窗口当前项目的持久化与恢复由 `WindowPersistencePlugin` 负责。
struct RecentProjectsOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "📋" }

    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var conversationCreationVM: WindowConversationCreationVM
    @EnvironmentObject private var recentProjectsVM: AppProjectsVM
    @EnvironmentObject private var windowManagerVM: WindowManagerVM
    @Environment(\.windowScope) private var windowScope

    let content: Content

    @State private var restored = false
    @State private var isFileImporterPresented = false
    @State private var restoreTask: Task<Void, Never>?

    private let store = RecentProjectsStore()

    var body: some View {
        ZStack {
            content

            // 恢复完成且未选择项目时，显示引导遮罩
            // 等待 WindowPersistencePlugin 完成窗口恢复后再显示，避免闪烁
            if shouldShowNoProjectOverlay {
                NoProjectOverlay(
                    recentProjects: recentProjectsVM.recentProjects,
                    isFileImporterPresented: $isFileImporterPresented,
                    onSelectProject: { project in
                        recentProjectsVM.addProject(project)
                        projectVM.switchProject(to: project)
                    },
                    onAddProject: { url in
                        addProjectAndSwitch(to: url)
                    }
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: projectVM.isProjectSelected)
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: windowManagerVM.hasCompletedInitialStateRestoration) { _, completed in
            guard completed else { return }
            syncProjectFromScopeIfNeeded()
            logOverlayDecisionIfNeeded()
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
}

// MARK: - Action

extension RecentProjectsOverlay {
    /// 仅在全局恢复结束且窗口 scope / projectVM 均无项目时展示选项目界面
    private var shouldShowNoProjectOverlay: Bool {
        guard restored else { return false }
        guard windowManagerVM.hasCompletedInitialStateRestoration else { return false }
        if projectVM.isProjectSelected { return false }
        if let path = windowScope?.projectPath, !path.isEmpty { return false }
        return true
    }

    private func restoreIfNeeded() {
        guard !restored, restoreTask == nil else { return }

        restoreTask = Task { @MainActor [store] in
            let projects = await Task.detached(priority: .utility) {
                store.loadProjects()
            }.value
            guard !Task.isCancelled else { return }
            recentProjectsVM.setRecentProjects(projects)

            await waitForWindowRestoration()
            guard !Task.isCancelled else { return }

            syncProjectFromScopeIfNeeded()
            logOverlayDecisionIfNeeded()
            setRestored(true)
            restoreTask = nil
        }
    }

    /// 等待 WindowPersistencePlugin 完成初始窗口状态恢复（含各窗口当前项目）
    ///
    /// 不能仅用 `hasCompletedInitialStateRestoration`：该标志可能在「等待首个 scope」之前就为 true（无磁盘记录），
    /// 或在 scope 注册与 `applyFirstRecord` 之间存在间隙，导致过早展示选项目界面。
    private func waitForWindowRestoration() async {
        if WindowPersistenceCoordinator.shared.isInitialRestorationFinished {
            return
        }
        for await _ in NotificationCenter.default.notifications(
            named: .initialWindowStateRestorationDidFinish
        ) {
            if WindowPersistenceCoordinator.shared.isInitialRestorationFinished {
                return
            }
        }
    }

    /// 若持久化已写入 scope 但本视图 projectVM 未同步，补一次切换（避免恢复竞态）
    private func syncProjectFromScopeIfNeeded() {
        guard let scope = windowScope,
              let path = scope.projectPath,
              !path.isEmpty,
              !projectVM.isProjectSelected else { return }

        let name = URL(fileURLWithPath: path).lastPathComponent
        projectVM.switchProject(to: Project(name: name, path: path, lastUsed: Date()))
    }

    private func logOverlayDecisionIfNeeded() {
        let scopePath = windowScope?.projectPath ?? ""
        let scopeSelected = windowScope?.projectVM.isProjectSelected ?? false
        let willShow = shouldShowNoProjectOverlay
        let restorationFinished = WindowPersistenceCoordinator.shared.isInitialRestorationFinished
        RecentProjectsPlugin.logger.info(
            """
            \(Self.t) overlay decision willShow=\(willShow, privacy: .public) \
            restored=\(restored, privacy: .public) \
            restorationFinished=\(restorationFinished, privacy: .public) \
            projectVM.selected=\(projectVM.isProjectSelected, privacy: .public) \
            scope.selected=\(scopeSelected, privacy: .public) \
            projectVM.path=\(projectVM.currentProjectPath, privacy: .public) \
            scope.path=\(scopePath, privacy: .public) \
            scopeCount=\(windowManagerVM.windowScopes.count, privacy: .public)
            """
        )
    }
}

// MARK: - Setter

extension RecentProjectsOverlay {
    @MainActor
    private func setRestored(_ value: Bool) {
        restored = value
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
                projectVM.switchProject(to: matched)
            }

            switchConversationForProject(path)
        }
    }
}

// MARK: - Project Add Helper

extension RecentProjectsOverlay {
    private func addProjectAndSwitch(to url: URL) {
        let standardizedURL = url.standardizedFileURL
        let project = Project(
            name: standardizedURL.lastPathComponent,
            path: standardizedURL.path,
            lastUsed: Date()
        )
        store.addProject(name: project.name, path: project.path)
        recentProjectsVM.addProject(project)
        projectVM.switchProject(to: project)
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
            await conversationCreationVM.createNewConversation()
        }
    }
}

// MARK: - Preview

#Preview("Recent Projects Persistence Overlay") {
    RecentProjectsOverlay(content: Text("Content"))
        .inRootView()
}
