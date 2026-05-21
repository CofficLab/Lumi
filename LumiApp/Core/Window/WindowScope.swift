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
    let conversationVM: WindowConversationVM

    /// 项目管理（每窗口打开不同项目）
    let projectVM: WindowProjectVM

    /// 布局管理（每窗口独立的侧边栏/布局状态）
    let layoutVM: WindowLayoutVM

    /// 消息发送队列（每窗口独立的消息发送队列）
    let messageQueueVM: WindowMessageQueueVM

    /// 用户输入队列（每窗口独立的用户输入）
    let inputQueueVM: WindowInputQueueVM

    /// 聊天草稿（每窗口独立，供输入框与右侧栏拖放插件共享）
    let chatDraftVM: WindowChatDraftVM

    /// 图片附件（每窗口独立的附件）
    let agentAttachmentsVM: WindowAttachmentsVM

    /// 权限请求（每窗口独立的权限弹窗）
    let permissionRequestVM: WindowPermissionRequestVM

    /// 权限处理（跟随 WindowPermissionRequestVM）
    let permissionHandlingVM: WindowPermissionHandlingVM

    /// 会话状态（按 conversationId 隔离，跟随窗口更自然）
    let conversationSendStatusVM: WindowConversationStatusVM

    /// 任务取消（跟随当前窗口）
    let taskCancellationVM: WindowTaskCancellationVM

    /// 命令建议（跟随当前窗口上下文）
    let commandSuggestionVM: WindowCommandSuggestionVM

    /// 项目上下文请求（跟随当前窗口项目）
    let projectContextRequestVM: WindowProjectContextRequestVM

    /// 聊天时间线（依赖 WindowConversationVM，窗口级）
    let chatTimelineViewModel: WindowChatTimelineViewModel

    /// 编辑器（每窗口独立的 EditorService，文件打开/切换互不影响）
    let editorVM: WindowEditorVM

    // MARK: - Window-Level Controllers

    /// 发送控制器（每窗口独立，直接访问窗口级 VM）
    lazy var sendController: SendController = SendController(scope: self, global: self._container)

    /// 项目控制器
    lazy var projectController: ProjectController = ProjectController(scope: self, global: self._container)

    /// 全局容器引用（供 lazy Controller 使用）
    private let _container: RootContainer

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

    private var hasCleanedUp = false

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

    /// 使用全局容器和可选的初始项目路径创建窗口作用域
    ///
    /// - Parameters:
    ///   - id: 窗口唯一标识，默认自动生成
    ///   - container: 全局服务容器，提供 Service 注入
    ///   - projectPath: 初始关联的项目路径（用于 Dock 拖拽打开等场景）
    init(
        id: UUID = UUID(),
        container: RootContainer,
        projectPath: String? = nil
    ) {
        self.id = id
        self.createdAt = Date()

        // ========================================
        // 创建窗口级 VM（用全局 Service 注入，VM 独立）
        // ========================================

        self.conversationVM = WindowConversationVM(
            chatHistoryService: container.chatHistoryService,
            promptService: container.promptService,
            agentSessionConfig: container.agentSessionConfig
        )
        self.projectVM = WindowProjectVM(
            contextService: container.contextService,
            llmService: container.llmService
        )
        self.layoutVM = WindowLayoutVM()
        self.messageQueueVM = WindowMessageQueueVM()
        self.inputQueueVM = WindowInputQueueVM()
        self.chatDraftVM = WindowChatDraftVM()
        self.agentAttachmentsVM = WindowAttachmentsVM()
        self.permissionRequestVM = WindowPermissionRequestVM()
        self.taskCancellationVM = WindowTaskCancellationVM()
        self.permissionHandlingVM = WindowPermissionHandlingVM(
            permissionRequestViewModel: permissionRequestVM,
            chatHistoryService: container.chatHistoryService,
            toolExecutionService: container.toolExecutionService
        )
        self.conversationSendStatusVM = WindowConversationStatusVM()
        self.commandSuggestionVM = WindowCommandSuggestionVM(
            slashCommandService: container.slashCommandService
        )
        self.projectContextRequestVM = WindowProjectContextRequestVM()
        self.chatTimelineViewModel = WindowChatTimelineViewModel(
            chatHistoryService: container.chatHistoryService,
            conversationVM: conversationVM
        )
        self.editorVM = WindowEditorVM(
            service: EditorService(editorExtensionRegistry: container.createEditorExtensionRegistry())
        )
        self._container = container

        // 将窗口级 conversationVM 注入全局 toolService，供插件工具构建时使用
        container.toolService.conversationVM = conversationVM

        self.inputQueueVM.onEnqueueRequest = { [weak self] request in
            self?.handleInputEnqueueRequest(request)
        }

        // ========================================
        // 初始化项目（新窗口不预设会话）
        // ========================================

        if let projectPath {
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            projectVM.switchProject(to: Project(name: projectName, path: projectPath, lastUsed: Date()))
            activePanel = .fileTree
        }

        updateTitle()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)创建 WindowScope: \(id.uuidString.prefix(8))")
        }
    }

    /// 将持久化记录中的会话和项目状态应用到当前窗口。
    ///
    /// 由 WindowPersistencePlugin 在窗口恢复阶段调用，用于恢复完整的窗口上下文
    /// （包括 conversationId，这不在 LumiWindowRoute 中）。
    func applyPersistenceRecord(conversationId: UUID?, projectPath: String?) {
        if let conversationId {
            conversationVM.setSelectedConversation(conversationId, reason: "windowPersistenceRestore")
        }
        if let projectPath {
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            projectVM.switchProject(to: Project(name: projectName, path: projectPath, lastUsed: Date()))
        }

        if conversationId != nil {
            activePanel = .chat
        } else if projectPath != nil {
            activePanel = .fileTree
        }

        updateTitle()
    }

    /// 处理当前窗口的用户输入请求。
    ///
    /// 输入框位于插件侧栏里，SwiftUI 的 `.onReceive` 在多窗口和缓存 AnyView 组合下可能失效；
    /// 因此发送入口绑定在 WindowScope 上，确保输入请求直接进入当前窗口的消息队列。
    func handleInputEnqueueRequest(_ request: WindowInputQueueVM.InputEnqueueRequest) {
        guard !hasCleanedUp else { return }

        _ = inputQueueVM.consumePendingRequest(id: request.id)
        guard let conversationId = conversationVM.selectedConversationId else {
            return
        }

        let pendingImages = agentAttachmentsVM.drainPendingImageAttachments()
        let allImages = request.images + pendingImages
        guard !request.text.isEmpty || !allImages.isEmpty else {
            return
        }

        let message = ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: request.text,
            images: allImages
        )
        messageQueueVM.enqueueMessage(message)
        chatTimelineViewModel.handleMessageQueued(message)

        Task { [weak self] in
            guard let self, !self.hasCleanedUp else { return }
            await self.sendController.attemptBeginNextQueuedSend()
        }
    }

    // MARK: - Conversation Management

    /// 切换到指定会话
    func switchToConversation(_ conversationId: UUID?, reason: String) {
        conversationVM.setSelectedConversation(conversationId, reason: reason)
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

    // MARK: - Teardown

    /// 释放窗口级资源。窗口关闭时由 `WindowManagerVM` 在移除 scope 前调用。
    func cleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true

        cancellables.removeAll()
        inputQueueVM.clearForTeardown()
        sendController.cancelAllSendsForTeardown()
        messageQueueVM.clearAll()
        chatDraftVM.clear()
        agentAttachmentsVM.clearPendingAttachments()
        permissionRequestVM.clearPending()
        conversationSendStatusVM.clearAll()
        editorVM.cleanupForTeardown()
        editorState.openFileURLs.removeAll()
        editorState.activeFileURL = nil
        isActive = false
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
