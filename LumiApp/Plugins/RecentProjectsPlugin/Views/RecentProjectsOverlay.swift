import MagicKit
import SwiftUI

/// 最近项目覆盖层
/// 在 RootView 出现时恢复最近项目列表，监听项目切换保存，
/// 并在项目切换时自动联动切换到关联的对话。
///
/// 当前文件（Editor active tab）的持久化由 EditorTabStripPlugin 负责。
/// 窗口级项目状态（当前项目）的持久化由 WindowPersistencePlugin 负责。
struct RecentProjectsOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "📋" }

    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var conversationCreationVM: WindowConversationCreationVM
    @EnvironmentObject private var recentProjectsVM: AppProjectsVM

    let content: Content

    @State private var restored = false
    @State private var isFileImporterPresented = false
    @State private var restoreTask: Task<Void, Never>?
    @State private var initialWindowStateRestored = false

    private let store = RecentProjectsStore()

    var body: some View {
        ZStack {
            content

            // 未选择项目时显示引导遮罩
            if restored && initialWindowStateRestored && !projectVM.isProjectSelected {
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
        .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
            handleProjectPathChange(oldPath: oldPath, newPath: newPath)
        }
        .onReceive(NotificationCenter.default.publisher(for: .initialWindowStateRestorationDidFinish)) { _ in
            initialWindowStateRestored = true
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
    private func restoreIfNeeded() {
        guard !restored, restoreTask == nil else { return }

        // 窗口级项目状态由 WindowPersistencePlugin 负责恢复，
        // 这里只恢复全局最近项目列表
        restoreTask = Task { @MainActor [store] in
            let projects = await Task.detached(priority: .utility) {
                store.loadProjects()
            }.value

            guard !Task.isCancelled else { return }

            recentProjectsVM.setRecentProjects(projects)

            setRestored(true)
            restoreTask = nil
        }
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
        if WindowManager.shared.hasCompletedInitialStateRestoration {
            initialWindowStateRestored = true
        }
        restoreIfNeeded()
    }

    private func handleProjectPathChange(oldPath: String, newPath: String) {
        // 保存新项目到最近列表
        guard !newPath.isEmpty else { return }
        let name = projectVM.currentProjectName
        store.addProject(name: name, path: newPath)

        // 项目切换 → 联动切换对话
        // 仅在真正切换时触发（oldPath != newPath），跳过首次恢复
        guard !oldPath.isEmpty, oldPath != newPath else { return }
        switchConversationForProject(newPath)
    }

    /// 处理 SetCurrentProjectTool 发出的事件，同步到 WindowProjectVM
    private func handleCurrentProjectDidChange(name: String, path: String) {
        // 如果路径与当前项目相同，无需切换
        guard projectVM.currentProjectPath != path else { return }

        Task { @MainActor [store, path] in
            // 同步到 WindowProjectVM：优先从最近项目列表中找到匹配 Project
            let projects = await Task.detached(priority: .utility) {
                store.loadProjects()
            }.value
            if let matched = projects.first(where: { $0.path == path }) {
                projectVM.switchProject(to: matched)
            }

            // Agent 工具触发项目切换 → 同样联动对话
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

        // 该项目没有关联对话 → 新建一个
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
