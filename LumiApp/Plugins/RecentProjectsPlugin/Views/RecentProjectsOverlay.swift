import MagicKit
import SwiftUI

/// 最近项目覆盖层
/// 在 RootView 出现时恢复最近项目列表和窗口级项目路径，监听项目切换保存，
/// 并在项目切换时自动联动切换到关联的对话。
///
/// 当前文件（Editor active tab）的持久化由 EditorTabStripPlugin 负责。
/// 窗口级项目状态的持久化由此插件（RecentProjectsPlugin）负责。
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

            // 未选择项目时显示引导遮罩
            if !projectVM.isProjectSelected {
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

        restoreTask = Task { @MainActor [store, windowScope] in
            // 并行加载最近项目列表和窗口-项目关联
            async let projectsTask = Task.detached(priority: .utility) {
                store.loadProjects()
            }.value
            async let windowProjectsTask = Task.detached(priority: .utility) {
                store.loadWindowProjects()
            }.value

            let projects = await projectsTask
            let windowProjects = await windowProjectsTask

            guard !Task.isCancelled else { return }

            recentProjectsVM.setRecentProjects(projects)

            // 将保存的窗口-项目关联应用到当前窗口
            if let scope = windowScope,
               let record = windowProjects.first(where: { $0.windowId == scope.id }),
               let projectPath = record.projectPath,
               !projectPath.isEmpty {
                let matchedProject = projects.first(where: { $0.path == projectPath })
                let project = matchedProject ?? Project(
                    name: URL(fileURLWithPath: projectPath).lastPathComponent,
                    path: projectPath,
                    lastUsed: Date()
                )
                scope.switchToProject(projectPath)
                // 同步到 projectVM（如果还没设置的话）
                if !projectVM.isProjectSelected {
                    projectVM.switchProject(to: project)
                }
            }

            // 附加协调器，监听窗口关闭和应用终止事件
            let coordinator = WindowProjectCoordinator.shared
            coordinator.attach(
                windowManagerVM: windowManagerVM,
                store: store
            )

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
        restoreIfNeeded()
    }

    private func handleProjectPathChange(oldPath: String, newPath: String) {
        // 保存新项目到最近列表
        guard !newPath.isEmpty else { return }
        let name = projectVM.currentProjectName
        store.addProject(name: name, path: newPath)

        // 保存窗口-项目关联
        WindowProjectCoordinator.shared.saveCurrentStates()

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

// MARK: - Coordinator

/// 窗口-项目关联协调器
/// 监听窗口关闭和应用终止事件，自动保存窗口-项目关联。
@MainActor
private final class WindowProjectCoordinator {
    static let shared = WindowProjectCoordinator()

    private weak var windowManagerVM: WindowManagerVM?
    private var store: RecentProjectsStore?
    private var observers: [NSObjectProtocol] = []

    func attach(windowManagerVM: WindowManagerVM, store: RecentProjectsStore) {
        self.windowManagerVM = windowManagerVM
        self.store = store
        guard observers.isEmpty else { return }

        let windowClosedObserver = NotificationCenter.default.addObserver(
            forName: .windowClosed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.saveCurrentStates()
            }
        }

        let willTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveCurrentStatesSynchronously()
            }
        }

        observers = [windowClosedObserver, willTerminateObserver]
    }

    func saveCurrentStates() {
        guard let scopes = windowManagerVM?.windowScopes, let store else { return }
        store.saveWindowProjects(from: scopes)
    }

    private func saveCurrentStatesSynchronously() {
        guard let scopes = windowManagerVM?.windowScopes, let store else { return }
        store.saveWindowProjectsSynchronously(from: scopes)
    }
}

// MARK: - Preview

#Preview("Recent Projects Persistence Overlay") {
    RecentProjectsOverlay(content: Text("Content"))
        .inRootView()
}
