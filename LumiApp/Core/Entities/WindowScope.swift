import Combine
import Foundation
import MagicKit
import SwiftUI

/// 窗口作用域容器
///
/// 每个窗口拥有独立的 `WindowScope` 实例，持有窗口级的 ViewModel。
/// 全局共享的 Service 通过 `RootContainer` 注入，VM 实例按窗口隔离。
///
/// ## 设计原则
///
/// - **Service 全局共享**：LLMService、ChatHistoryService 等基础设施所有窗口共用
/// - **VM 分两级**：全局 VM（AppThemeVM、AppPluginVM 等）留在 RootContainer；窗口级 VM 放这里
/// - **窗口关闭自动释放**：WindowScope 随窗口销毁，内存自然回收
///
/// ## 判断标准
///
/// 这个状态换了窗口还有意义吗？
/// - 有 → 全局（RootContainer）
/// - 没有 → 窗口级（WindowScope）
@MainActor
final class WindowScope: ObservableObject, Identifiable, SuperLog {
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose: Bool = false

    // MARK: - Identity

    /// 窗口唯一标识
    let id: UUID

    /// 窗口创建时间
    let createdAt: Date

    // MARK: - Window-Level ViewModel

    /// 会话管理（每窗口选中不同会话）
    let conversationVM: Lumi.WindowConversationVM

    /// 项目管理（每窗口打开不同项目）
    let projectVM: Lumi.WindowProjectVM

    /// 布局管理（每窗口独立的侧边栏/布局状态）
    let layoutVM: WindowLayoutVM

    /// 消息列表（每窗口显示不同会话的消息）
    let messagePendingVM: WindowMessagePendingVM

    /// 消息发送队列（每窗口独立的消息发送队列）
    let messageQueueVM: Lumi.WindowMessageQueueVM

    /// 用户输入队列（每窗口独立的用户输入）
    let inputQueueVM: WindowInputQueueVM

    /// 图片附件（每窗口独立的附件）
    let agentAttachmentsVM: WindowAttachmentsVM

    /// 权限请求（每窗口独立的权限弹窗）
    let permissionRequestVM: WindowPermissionRequestVM

    /// 权限处理（跟随 WindowPermissionRequestVM）
    let permissionHandlingVM: WindowPermissionHandlingVM

    /// 会话状态（按 conversationId 隔离，跟随窗口更自然）
    let conversationSendStatusVM: WindowConversationStatusVM

    /// 会话创建（跟随当前窗口）
    let conversationCreationVM: WindowConversationCreationVM

    /// 任务取消（跟随当前窗口）
    let taskCancellationVM: WindowTaskCancellationVM

    /// 命令建议（跟随当前窗口上下文）
    let commandSuggestionVM: WindowCommandSuggestionVM

    /// 项目上下文请求（跟随当前窗口项目）
    let projectContextRequestVM: WindowProjectContextRequestVM

    /// 聊天时间线（依赖 WindowConversationVM，窗口级）
    let chatTimelineViewModel: WindowChatTimelineViewModel

    // MARK: - Window-Level State (from WindowState)

    /// 窗口标题
    @Published var title: String = "Lumi"

    /// 当前活跃的面板类型
    @Published var activePanel: WindowActivePanel = .chat

    /// 侧边栏可见性
    @Published var sidebarVisibility: Bool = true

    /// 导航分栏视图的列可见性状态
    @Published var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 窗口级编辑器状态
    @Published var editorState: WindowEditorState = WindowEditorState()

    /// 窗口是否活跃
    @Published var isActive: Bool = false

    // MARK: - Convenience Computed Properties

    /// 当前选中的会话 ID
    var selectedConversationId: UUID? {
        conversationVM.selectedConversationId
    }

    /// 当前关联的项目路径
    var projectPath: String? {
        projectVM.currentProject?.path
    }

    /// 当前项目名称
    var projectName: String? {
        projectVM.currentProject?.name
    }

    /// 是否已选择项目
    var isProjectSelected: Bool {
        projectVM.isProjectSelected
    }

    // MARK: - Combine Subscriptions

    var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// 使用全局容器和可选的初始路由参数创建窗口作用域
    ///
    /// - Parameters:
    ///   - id: 窗口唯一标识，默认自动生成
    ///   - container: 全局服务容器，提供 Service 注入
    ///   - conversationId: 初始选中的会话 ID
    ///   - projectPath: 初始关联的项目路径
    init(
        id: UUID = UUID(),
        container: RootContainer,
        conversationId: UUID? = nil,
        projectPath: String? = nil
    ) {
        self.id = id
        self.createdAt = Date()

        // ========================================
        // 创建窗口级 VM（用全局 Service 注入，VM 独立）
        // ========================================

        self.conversationVM = Lumi.WindowConversationVM(
            chatHistoryService: container.chatHistoryService
        )
        self.projectVM = Lumi.WindowProjectVM(
            contextService: container.contextService,
            llmService: container.llmService
        )
        self.layoutVM = WindowLayoutVM()
        self.messagePendingVM = WindowMessagePendingVM()
        self.messageQueueVM = Lumi.WindowMessageQueueVM()
        self.inputQueueVM = WindowInputQueueVM()
        self.agentAttachmentsVM = WindowAttachmentsVM()
        self.permissionRequestVM = WindowPermissionRequestVM()
        self.taskCancellationVM = WindowTaskCancellationVM()
        self.permissionHandlingVM = WindowPermissionHandlingVM(
            permissionRequestViewModel: permissionRequestVM,
            chatHistoryService: container.chatHistoryService,
            toolExecutionService: container.toolExecutionService
        )
        self.conversationSendStatusVM = WindowConversationStatusVM()
        self.conversationCreationVM = WindowConversationCreationVM()
        self.commandSuggestionVM = WindowCommandSuggestionVM(
            slashCommandService: container.slashCommandService
        )
        self.projectContextRequestVM = WindowProjectContextRequestVM()
        self.chatTimelineViewModel = WindowChatTimelineViewModel(
            chatHistoryService: container.chatHistoryService,
            conversationVM: conversationVM
        )

        // ========================================
        // 初始化会话和项目
        // ========================================

        if let conversationId {
            conversationVM.setSelectedConversation(conversationId)
            activePanel = .chat
        }
        if let projectPath {
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            projectVM.switchProject(to: Project(name: projectName, path: projectPath, lastUsed: Date()))
            if conversationId == nil {
                activePanel = .fileTree
            }
        }

        updateTitle()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)创建 WindowScope: \(id.uuidString.prefix(8))")
        }
    }

    /// 从窗口路由创建
    convenience init(route: LumiWindowRoute, container: RootContainer) {
        self.init(
            id: route.id,
            container: container,
            conversationId: route.conversationId,
            projectPath: route.projectPath
        )
    }

    // MARK: - Conversation Management

    /// 切换到指定会话
    func switchToConversation(_ conversationId: UUID?) {
        conversationVM.setSelectedConversation(conversationId)
        if conversationId != nil {
            activePanel = .chat
        }
        updateTitle()
    }

    // MARK: - Project Management

    /// 切换到指定项目
    func switchToProject(_ path: String?) {
        if let path {
            let projectName = URL(fileURLWithPath: path).lastPathComponent
            projectVM.switchProject(to: Project(name: projectName, path: path, lastUsed: Date()))
            if activePanel == .welcome {
                activePanel = .fileTree
            }
        } else {
            projectVM.clearProject()
        }
        updateTitle()
    }

    // MARK: - Editor State Management

    /// 打开文件到编辑器
    func openFile(_ url: URL) {
        if !editorState.openFileURLs.contains(url) {
            editorState.openFileURLs.append(url)
        }
        editorState.activeFileURL = url
        activePanel = .editor
    }

    /// 关闭文件
    func closeFile(_ url: URL) {
        editorState.openFileURLs.removeAll { $0 == url }
        if editorState.activeFileURL == url {
            editorState.activeFileURL = editorState.openFileURLs.last
        }
        if !editorState.hasOpenFiles {
            activePanel = projectPath != nil ? .fileTree : .chat
        }
    }

    // MARK: - Title Management

    /// 更新窗口标题
    func updateTitle() {
        if let conversationId = conversationVM.selectedConversationId,
           let conversation = conversationVM.fetchConversation(id: conversationId) {
            title = conversation.title
        } else if let _ = projectPath {
            title = "Lumi - \(projectVM.currentProjectName)"
        } else {
            title = "Lumi"
        }
    }

    // MARK: - Window Status

    /// 设置窗口活跃状态
    func setActive(_ active: Bool) {
        isActive = active
    }

    // MARK: - Snapshot (Persistence)

    /// 获取当前状态快照（用于持久化）
    func snapshot() -> WindowStateSnapshot {
        WindowStateSnapshot(
            windowId: id,
            conversationId: conversationVM.selectedConversationId,
            projectPath: projectVM.currentProject?.path,
            activePanel: activePanel,
            editorState: editorState,
            sidebarVisibility: sidebarVisibility,
            createdAt: createdAt
        )
    }
}

// MARK: - Environment Key

/// 窗口作用域环境键（用于在视图中注入）
struct WindowScopeKey: EnvironmentKey {
    static let defaultValue: WindowScope? = nil
}

extension EnvironmentValues {
    var windowScope: WindowScope? {
        get { self[WindowScopeKey.self] }
        set { self[WindowScopeKey.self] = newValue }
    }
}
