import AppKit
import Combine
import AgentToolKit
import Foundation
import LumiCoreKit
import SwiftUI

/// 窗口作用域容器
///
/// 每个窗口拥有独立的 `WindowContainer` 实例，持有窗口级的 ViewModel。
/// 全局共享的 Service 通过 `RootContainer` 注入，VM 实例按窗口隔离。
///
/// ## 设计原则
///
/// - **Service 全局共享**：LLMService、ChatHistoryService 等基础设施所有窗口共用
/// - **VM 分两级**：全局 VM（AppThemeVM、AppPluginVM 等）留在 RootContainer；窗口级 VM 放这里
/// - **窗口关闭自动释放**：WindowContainer 随窗口销毁，内存自然回收
///
/// ## 判断标准
///
/// 这个状态换了窗口还有意义吗？
/// - 有 → 全局（RootContainer）
/// - 没有 → 窗口级（WindowContainer）
@MainActor
final class WindowContainer: ObservableObject, Identifiable, SuperLog {
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose: Bool = false // 链路日志见 AgentSendPipelineLog

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

    /// 用户输入队列（每窗口独立的用户输入）
    let inputQueueVM: WindowInputQueueVM

    /// 聊天草稿（每窗口独立，供输入框与右侧栏拖放插件共享）
    let chatDraftVM: WindowChatDraftVM

    /// 图片附件（每窗口独立的附件）
    let agentAttachmentsVM: WindowAttachmentsVM

    /// 权限处理（消息列表内联授权）
    let permissionHandlingVM: WindowPermissionHandlingVM

    /// 会话状态（按 conversationId 隔离，跟随窗口更自然）
    let conversationSendStatusVM: WindowConversationStatusVM

    /// 任务取消（跟随当前窗口）
    let taskCancellationVM: WindowTaskCancellationVM

    /// 命令建议（跟随当前窗口上下文）
    let commandSuggestionVM: WindowCommandSuggestionVM

    /// 项目上下文请求（跟随当前窗口项目）
    let projectContextRequestVM: WindowProjectContextRequestVM

    /// 编辑器（每窗口独立的 EditorService，文件打开/切换互不影响）
    let editorVM: WindowEditorVM

    // MARK: - Window-Level Controllers

    /// 工具调用执行器（每窗口独立）
    lazy var toolCallExecutor: ToolCallExecutor = ToolCallExecutor(
        toolService: _container.toolService,
        agentSessionConfig: _container.agentSessionConfig,
        conversationSendStatusVM: conversationSendStatusVM,
        conversationVM: conversationVM,
        projectVM: projectVM,
        recentProjectPathsProvider: { [weak self] in
            guard let self else { return [] }
            return self._container.recentProjectsVM.getRecentProjects().map(\.path)
        }
    )

    /// 项目控制器
    lazy var projectController: ProjectController = ProjectController(container: self, global: self._container)

    /// 全局容器引用（供 lazy Controller 使用）
    private let _container: RootContainer

    // MARK: - Window-Level State

    /// 窗口标题
    @Published var title: String = "Lumi"

    /// 当前激活的视图容器标题（如"聊天"、"搜索"等）
    /// 由 ContentView 在 activeViewContainerIcon 变化时设置
    var activeViewContainerTitle: String?

    /// 侧边栏可见性
    @Published var sidebarVisibility: Bool = true

    /// 导航分栏视图的列可见性状态
    @Published var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 编辑器已打开的文件
    @Published var editorOpenFileURLs: [URL] = []
    /// 编辑器当前活跃文件
    @Published var editorActiveFileURL: URL?

    /// 窗口是否活跃
    @Published var isActive: Bool = false

    private var hasCleanedUp = false
    private var hasConfiguredPersistence = false

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

    /// 编辑器是否有打开的文件
    var hasOpenEditorFiles: Bool {
        !editorOpenFileURLs.isEmpty
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
            conversationService: container.conversationService,
            promptService: container.promptService,
            agentSessionConfig: container.agentSessionConfig
        )
        self.projectVM = WindowProjectVM(
            contextService: container.contextService,
            llmService: container.llmService
        )
        self.layoutVM = WindowLayoutVM()
        self.inputQueueVM = WindowInputQueueVM()
        self.chatDraftVM = WindowChatDraftVM()
        self.agentAttachmentsVM = WindowAttachmentsVM()
        self.taskCancellationVM = WindowTaskCancellationVM()
        self.permissionHandlingVM = WindowPermissionHandlingVM(
            chatHistoryService: container.chatHistoryService
        )
        self.conversationSendStatusVM = WindowConversationStatusVM()
        self.commandSuggestionVM = WindowCommandSuggestionVM(
            slashCommandService: container.slashCommandService
        )
        self.projectContextRequestVM = WindowProjectContextRequestVM()
        self.editorVM = WindowEditorVM(
            service: EditorService(editorExtensionRegistry: container.createEditorExtensionRegistry())
        )
        self.editorVM.service.state.windowId = id
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
            projectVM.switchProject(
                to: Project(name: projectName, path: projectPath, lastUsed: Date()),
                reason: "windowContainerInit"
            )
        }

        updateTitle()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)创建 WindowContainer: \(id.uuidString.prefix(8))")
        }
    }

    /// 处理当前窗口的用户输入请求。
    ///
    /// 输入框位于插件侧栏里，SwiftUI 的 `.onReceive` 在多窗口和缓存 AnyView 组合下可能失效；
    /// 因此发送入口绑定在 WindowContainer 上，确保输入请求直接进入当前窗口的消息队列。
    func handleInputEnqueueRequest(_ request: WindowInputQueueVM.InputEnqueueRequest) {
        guard !hasCleanedUp else { return }

        guard inputQueueVM.consumePendingRequest(id: request.id) != nil else {
            return
        }
        guard let conversationId = conversationVM.selectedConversationId else {
            return
        }

        let pendingImages = agentAttachmentsVM.drainPendingImageAttachments()
        let allImages = request.images + pendingImages
        guard !request.text.isEmpty || !allImages.isEmpty else {
            return
        }

        if allImages.isEmpty, request.text.hasPrefix("/") {
            Task { [weak self] in
                await self?.handleSlashCommandInput(request.text, conversationId: conversationId)
            }
            return
        }

        enqueueMessageForSend(text: request.text, images: allImages, conversationId: conversationId)
    }

    private func handleSlashCommandInput(_ text: String, conversationId: UUID) async {
        let result = await _container.slashCommandService.handle(input: text)

        switch result {
        case .handled:
            return

        case .notHandled:
            enqueueMessageForSend(text: text, images: [], conversationId: conversationId)

        case .error(let message):
            saveSystemMessage(message, conversationId: conversationId)

        case .systemMessage(let message):
            saveSystemMessage(message, conversationId: conversationId)

        case .userMessage(let message, let triggerProcessing):
            if triggerProcessing {
                enqueueMessageForSend(text: message, images: [], conversationId: conversationId)
            } else {
                conversationVM.saveMessage(
                    ChatMessage(role: .user, conversationId: conversationId, content: message),
                    to: conversationId
                )
            }

        case .clearHistory:
            await clearConversationHistory(conversationId: conversationId)

        case .triggerPlanning(let task):
            _container.agentSessionConfig.setChatMode(.build)
            enqueueMessageForSend(text: task, images: [], conversationId: conversationId)

        case .mcpCommand:
            saveSystemMessage("MCP slash commands are not available in this chat yet.", conversationId: conversationId)
        }
    }

    private func enqueueMessageForSend(text: String, images: [ImageAttachment], conversationId: UUID) {
        guard !text.isEmpty || !images.isEmpty else {
            return
        }

        let message = ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: text,
            images: images
        )
        var pendingMessage = message
        pendingMessage.queueStatus = .pending
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ① [Input] 保存 pending 用户消息 id=\(message.id.uuidString.prefix(8)) text=\(text.prefix(40))")
        }
        conversationVM.saveMessage(pendingMessage, to: conversationId)
    }

    private func saveSystemMessage(_ text: String, conversationId: UUID) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        conversationVM.saveMessage(
            ChatMessage(role: .system, conversationId: conversationId, content: text),
            to: conversationId
        )
    }

    private func clearConversationHistory(conversationId: UUID) async {
        let messages = _container.chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
        let deletedCount = await _container.chatHistoryService.deleteMessagesAsync(
            messageIds: messages.map(\.id),
            conversationId: conversationId
        )

        if deletedCount > 0 {
            saveSystemMessage("Cleared \(deletedCount) messages from this conversation.", conversationId: conversationId)
        } else {
            saveSystemMessage("This conversation is already empty.", conversationId: conversationId)
        }
    }

    // MARK: - Conversation Management

    /// 切换到指定会话
    func switchToConversation(_ conversationId: UUID?, reason: String) {
        conversationVM.setSelectedConversation(conversationId, reason: reason)
        updateTitle()
    }

    // MARK: - Persistence Restore

    /// 从磁盘快照恢复窗口状态（项目、会话、编辑器、侧栏）。
    func applyPersistenceRecord(_ record: WindowPersistenceRecord) {
        if let conversationId = record.conversationId {
            conversationVM.setSelectedConversation(conversationId, reason: "windowPersistenceRestore")
        }
        if let projectPath = record.projectPath, !projectPath.isEmpty {
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            projectVM.switchProject(
                to: Project(name: projectName, path: projectPath, lastUsed: Date()),
                reason: "windowPersistenceRestore"
            )
        }

        let restoredEditorState = Self.restoredEditorState(
            openFilePaths: record.editorOpenFilePaths,
            activeFilePath: record.editorActiveFilePath
        )
        editorOpenFileURLs = restoredEditorState.openFiles
        editorActiveFileURL = restoredEditorState.activeFile
        restoreEditorSessions(openFiles: restoredEditorState.openFiles, activeFile: restoredEditorState.activeFile)

        if let sidebarVisibility = record.sidebarVisibility {
            self.sidebarVisibility = sidebarVisibility
        }

        updateTitle()
    }

    static func restoredEditorState(
        openFilePaths: [String]?,
        activeFilePath: String?
    ) -> (openFiles: [URL], activeFile: URL?) {
        let activeFile = activeFilePath.flatMap { restoredEditorURL(path: $0) }
        return editorSessionState(
            tabFileURLs: (openFilePaths ?? []).compactMap(restoredEditorURL(path:)),
            activeFile: activeFile
        )
    }

    static func editorSessionState(
        tabFileURLs: [URL?],
        activeFile: URL?
    ) -> (openFiles: [URL], activeFile: URL?) {
        var seenPaths = Set<String>()
        var openFiles: [URL] = []

        for fileURL in tabFileURLs {
            guard let url = fileURL?.standardizedFileURL,
                  seenPaths.insert(url.path).inserted else { continue }
            openFiles.append(url)
        }

        let activeFile = activeFile?.standardizedFileURL

        if let activeFile, seenPaths.insert(activeFile.path).inserted {
            openFiles.append(activeFile)
        }

        return (openFiles, activeFile)
    }

    private static func restoredEditorURL(path: String) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmedPath).standardizedFileURL
    }

    /// 根据稳定窗口 ID 恢复上次保存的窗口状态。
    func restorePersistedStateIfAvailable(allowProjectRestore: Bool) {
        guard let record = WindowStateStore.shared.record(for: id) else { return }
        let recordToApply: WindowPersistenceRecord
        if allowProjectRestore {
            recordToApply = record
        } else {
            recordToApply = WindowPersistenceRecord(
                windowId: record.windowId,
                conversationId: record.conversationId,
                projectPath: nil,
                editorOpenFilePaths: record.editorOpenFilePaths,
                editorActiveFilePath: record.editorActiveFilePath,
                sidebarVisibility: record.sidebarVisibility,
                createdAt: record.createdAt
            )
        }
        applyPersistenceRecord(recordToApply)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)恢复窗口状态: \(self.id.uuidString.prefix(8)), project=\(record.projectPath ?? "nil")")
        }
    }

    /// 安装窗口状态持久化订阅。
    func configurePersistenceObserversIfNeeded() {
        guard !hasConfiguredPersistence else { return }
        hasConfiguredPersistence = true

        projectVM.$currentProject
            .dropFirst()
            .sink { [weak self] project in
                guard let self else { return }
                self.updateTitle()
                WindowStateStore.shared.saveProject(
                    windowId: self.id,
                    projectPath: project?.path,
                    createdAt: self.createdAt
                )
            }
            .store(in: &cancellables)

        conversationVM.$selectedConversationId
            .dropFirst()
            .sink { [weak self] conversationId in
                guard let self else { return }
                self.updateTitle()
                WindowStateStore.shared.saveConversation(windowId: self.id, conversationId: conversationId)
            }
            .store(in: &cancellables)

        $sidebarVisibility
            .dropFirst()
            .sink { [weak self] isVisible in
                guard let self else { return }
                WindowStateStore.shared.saveSidebar(windowId: self.id, sidebarVisibility: isVisible)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($editorOpenFileURLs, $editorActiveFileURL)
            .dropFirst()
            .sink { [weak self] openFiles, activeFile in
                guard let self else { return }
                WindowStateStore.shared.saveEditor(
                    windowId: self.id,
                    editorOpenFilePaths: openFiles.map(\.path),
                    editorActiveFilePath: activeFile?.path
                )
            }
            .store(in: &cancellables)

        editorVM.service.sessionObjectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.syncEditorStateFromServiceSessions()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .windowStateShouldPersist)
            .sink { [weak self] _ in
                self?.persistCurrentStateSynchronously()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.persistCurrentStateSynchronously()
            }
            .store(in: &cancellables)
    }

    func persistCurrentStateSynchronously() {
        let currentRecord = makePersistenceRecord()
        var records = WindowStateStore.shared.loadAll()
        if let index = records.firstIndex(where: { $0.windowId == id }) {
            records[index] = currentRecord
        } else {
            records.insert(currentRecord, at: 0)
        }
        WindowStateStore.shared.saveAllSynchronously(records)
    }

    private func makePersistenceRecord() -> WindowPersistenceRecord {
        WindowPersistenceRecord(
            windowId: id,
            conversationId: conversationVM.selectedConversationId,
            projectPath: projectVM.currentProject?.path,
            editorOpenFilePaths: editorOpenFileURLs.map(\.path),
            editorActiveFilePath: editorActiveFileURL?.path,
            sidebarVisibility: sidebarVisibility,
            createdAt: createdAt
        )
    }

    // MARK: - Project Management

    /// 切换到指定项目
    func switchToProject(_ path: String?, reason: String) {
        if let path {
            let projectName = URL(fileURLWithPath: path).lastPathComponent
            projectVM.switchProject(
                to: Project(name: projectName, path: path, lastUsed: Date()),
                reason: reason
            )
        } else {
            projectVM.clearProject()
        }
        updateTitle()
    }

    // MARK: - Editor State Management

    /// 打开文件到编辑器
    func openFile(_ url: URL) {
        if !editorOpenFileURLs.contains(url) {
            editorOpenFileURLs.append(url)
        }
        editorActiveFileURL = url
    }

    /// 关闭文件
    func closeFile(_ url: URL) {
        editorOpenFileURLs.removeAll { $0 == url }
        if editorActiveFileURL == url {
            editorActiveFileURL = editorOpenFileURLs.last
        }
    }

    private func syncEditorStateFromServiceSessions() {
        let editorState = Self.editorSessionState(
            tabFileURLs: editorVM.service.tabs.map(\.fileURL),
            activeFile: editorVM.service.activeSession?.fileURL
        )
        let openFiles = editorState.openFiles
        let activeFile = editorState.activeFile

        if editorOpenFileURLs != openFiles {
            editorOpenFileURLs = openFiles
        }
        if editorActiveFileURL != activeFile {
            editorActiveFileURL = activeFile
        }
    }

    private func restoreEditorSessions(openFiles: [URL], activeFile: URL?) {
        editorVM.service.closeAllSessions()
        for url in openFiles {
            editorVM.service.openFile(at: url)
        }
        if let activeFile {
            editorVM.service.open(at: activeFile)
        }
    }


    // MARK: - Agent Turn Control

    /// 取消当前会话的 Agent Turn。
    func cancelAgentTurn(conversationId: UUID) {
        let wasProcessing = _container.conversationService.loadTurnPhase(forConversationId: conversationId) != .idle

        AgentConversationLock.shared.markCancelled(conversationId)
        AgentConversationLock.shared.release(conversationId)

conversationSendStatusVM.setStatus(conversationId: conversationId, content: "已停止生成")
        conversationSendStatusVM.clearStatus(conversationId: conversationId)
        _container.chatHistoryService.clearQueueStatus(forConversationId: conversationId)
        _container.conversationService.setTurnPhase(.idle, forConversationId: conversationId)
        AgentTransientPromptStore.shared.clear(for: conversationId)

        guard wasProcessing else { return }
        let systemMessage = ChatMessage(role: .system, conversationId: conversationId, content: "用户主动取消了对话")
        conversationVM.saveMessage(systemMessage, to: conversationId)
    }

    /// 窗口关闭时清理所有 Agent Turn 状态。
    func cancelAllAgentTurnsForTeardown() {
        AgentTransientPromptStore.shared.clearAll()
        conversationSendStatusVM.clearAll()
        AgentConversationLock.shared.releaseAll()
    }

    // MARK: - Teardown

    /// 释放窗口级资源。窗口关闭时由 `WindowManagerVM` 在移除 scope 前调用。
    func cleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true

        cancellables.removeAll()
        inputQueueVM.clearForTeardown()
        cancelAllAgentTurnsForTeardown()
        chatDraftVM.clear()
        agentAttachmentsVM.clearPendingAttachments()
        conversationSendStatusVM.clearAll()
        editorVM.cleanupForTeardown()
        editorOpenFileURLs.removeAll()
        editorActiveFileURL = nil
        isActive = false
    }

    // MARK: - Title Management

    /// 更新窗口标题
    func updateTitle() {
        let baseTitle: String
        if let conversationId = conversationVM.selectedConversationId,
           let conversation = conversationVM.fetchConversation(id: conversationId) {
            baseTitle = conversation.displayTitle
        } else if let _ = projectPath {
            baseTitle = projectVM.currentProjectName
        } else {
            baseTitle = "Lumi"
        }

        if let viewTitle = activeViewContainerTitle, !viewTitle.isEmpty, viewTitle != "Chat" {
            title = "\(baseTitle) — \(viewTitle)"
        } else {
            title = baseTitle
        }
    }

    /// 由 ContentView 调用，通知当前激活的视图容器已变化
    func setActiveViewContainerTitle(_ newTitle: String?) {
        guard activeViewContainerTitle != newTitle else { return }
        activeViewContainerTitle = newTitle
        updateTitle()
    }

    // MARK: - Window Status

    /// 设置窗口活跃状态
    func setActive(_ active: Bool) {
        isActive = active
    }
}

// MARK: - Environment Key

/// 窗口作用域环境键（用于在视图中注入）
struct WindowContainerKey: EnvironmentKey {
    static let defaultValue: WindowContainer? = nil
}

extension EnvironmentValues {
    var windowContainer: WindowContainer? {
        get { self[WindowContainerKey.self] }
        set { self[WindowContainerKey.self] = newValue }
    }
}
