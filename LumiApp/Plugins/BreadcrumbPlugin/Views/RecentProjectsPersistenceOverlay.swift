import MagicKit
import SwiftUI

/// 最近项目持久化覆盖层
/// 在 RootView 出现时恢复最近项目列表和当前项目，监听项目切换保存，
/// 并在项目切换时自动联动切换到关联的对话
struct RecentProjectsPersistenceOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { false }
    nonisolated static var emoji: String { "📋" }

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var conversationVM: ConversationVM
    @EnvironmentObject private var conversationCreationVM: ConversationCreationVM

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
        .onChange(of: projectVM.selectedFileURL) { oldURL, newURL in
            handleFileSelectionChange(oldURL: oldURL, newURL: newURL)
        }
        .onCurrentProjectDidChange { name, path in
            handleCurrentProjectDidChange(name: name, path: path)
        }
        .onCurrentFileDidChange { path in
            handleCurrentFileDidChange(path: path)
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
            projectVM.switchProject(to: currentProject)
        }
        
        // 恢复当前文件到 projectVM
        if let currentFile = store.getCurrentFile() {
            let url = URL(fileURLWithPath: currentFile.path)
            projectVM.selectFile(at: url)
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

        // 项目切换 → 联动切换对话
        // 仅在真正切换时触发（oldPath != newPath），跳过首次恢复
        guard !oldPath.isEmpty, oldPath != newPath else { return }
        switchConversationForProject(newPath)
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

        // Agent 工具触发项目切换 → 同样联动对话
        switchConversationForProject(path)
    }
    
    /// 处理文件选择变化（从 UI 触发）
    private func handleFileSelectionChange(oldURL: URL?, newURL: URL?) {
        guard let newURL = newURL else { return }
        
        // 保存到持久化存储
        store.setCurrentFile(path: newURL.path)
    }
    
    /// 处理 SetCurrentFileTool 发出的事件，同步到 ProjectVM
    private func handleCurrentFileDidChange(path: String) {
        let url = URL(fileURLWithPath: path)
        
        // 如果路径与当前文件相同，无需切换
        guard projectVM.selectedFileURL?.path != path else { return }
        
        // 验证文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            if Self.verbose {
                BreadcrumbPlugin.logger.warning("\(Self.t)⚠️ 文件不存在：\(path)")
            }
            return
        }
        
        // 同步到 ProjectVM
        projectVM.selectFile(at: url)
    }
}

// MARK: - Project-Conversation Sync

extension RecentProjectsPersistenceOverlay {
    /// 项目切换时，自动切换到该项目最近使用的对话
    /// 如果该项目没有关联对话，则新建一个
    private func switchConversationForProject(_ projectPath: String) {
        let switched = conversationVM.switchToLatestConversation(forProject: projectPath)

        if switched {
            if Self.verbose {
                BreadcrumbPlugin.logger.info("\(Self.t)✅ 已切换到项目 [\(projectPath)] 的最近对话")
            }
            return
        }

        // 该项目没有关联对话 → 新建一个
        if Self.verbose {
            BreadcrumbPlugin.logger.info("\(Self.t)📁 项目 [\(projectPath)] 无关联对话，创建新对话")
        }

        Task {
            await conversationCreationVM.createNewConversation()
        }
    }
}

// MARK: - Preview

#Preview("Recent Projects Persistence Overlay") {
    RecentProjectsPersistenceOverlay(content: Text("Content"))
        .inRootView()
}
