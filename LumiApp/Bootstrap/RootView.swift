import Combine
import Foundation
import MagicAlert
import SwiftData
import SwiftUI
import LumiCoreKit
import AgentTurnNotificationPlugin
import EditorStickySymbolBarPlugin
import EditorTabStripPlugin
import EditorRailWorkspaceSymbolsPlugin
import FontConfigPlugin
import GitPlugin
import GoEditorPlugin
import JSEditorPlugin
import MessageRendererPlugin
import AutoTaskPlugin
import ProjectsPlugin
import QuickFileSearchPlugin
import ScreenshotPlugin
import TerminalPlugin

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
///
/// ## 架构说明
///
/// 全局共享 VM 通过 `RootContainer.shared` 注入。
/// 窗口级 VM 通过 `WindowContainer` 注入，每个窗口拥有独立的 VM 实例。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView(container: windowContainer)
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 窗口容器（每窗口独立）
    @ObservedObject var windowContainer: WindowContainer

    /// 全局服务容器（单例）。
    @StateObject var container = RootContainer.shared
    @StateObject private var pluginProjectContext = PluginProjectContext()
    @StateObject private var pluginRecentProjectsVM = LumiCoreKit.AppProjectsVM()
    @StateObject private var pluginThemeVM = LumiCoreKit.AppThemeVM()
    @StateObject private var pluginEditorContext = LumiCoreKit.EditorContext()
    @StateObject private var pluginPluginVM = LumiCoreKit.AppPluginVM()
    @StateObject private var pluginLLMVM = LumiCoreKit.AppLLMVM()
    @StateObject private var pluginGitVM = LumiCoreKit.AppGitVM()
    @StateObject private var pluginConversationVM = LumiCoreKit.WindowConversationVM()
    @StateObject private var pluginConversationListContext = LumiCoreKit.ConversationListContext()
    @StateObject private var pluginLayoutContext = LumiCoreKit.WindowLayoutVM()

    init(container: WindowContainer, @ViewBuilder content: () -> Content) {
        self._windowContainer = ObservedObject(wrappedValue: container)
        self.content = content()
    }

    var body: some View {
        pluginLayoutLifecycleScene
    }

    private var baseScene: some View {
        ZStack {
            RootListener(scope: windowContainer)
            configuredContent
        }
        .onFileDroppedToChat(windowId: windowContainer.id) { url in
            handleFileDroppedToChat(url)
        }
        .onOpenFileInEditor(windowId: windowContainer.id) { url in
            handleOpenFileInEditor(url)
        }
        .onDisappear {
            windowContainer.persistCurrentStateSynchronously()
            windowContainer.cleanup()
            container.toolService.clearConversationListContext(for: windowContainer.id)
        }
    }

    private var initialLifecycleScene: some View {
        baseScene
            .onAppear(perform: performInitialLifecycleSetup)
    }

    private var projectLifecycleScene: some View {
        initialLifecycleScene
        .onChange(of: windowContainer.projectVM.currentProjectPath) { _, _ in
            syncPluginProjectContext()
        }
        .onChange(of: windowContainer.projectVM.languagePreference) { _, _ in
            syncPluginProjectContext()
        }
        .onChange(of: container.recentProjectsVM.recentProjects) { _, _ in
            syncPluginRecentProjectsContext()
        }
        .onChange(of: windowContainer.conversationVM.selectedConversationId) { _, _ in
            syncPluginConversationListContext()
        }
        .onChange(of: windowContainer.projectVM.currentProjectPath) { _, _ in
            syncPluginConversationListContext()
        }
        .onChange(of: windowContainer.projectVM.currentProjectName) { _, _ in
            syncPluginConversationListContext()
        }
        .onChange(of: windowContainer.conversationVM.selectedConversationId) { _, _ in
            syncPluginConversationContext()
        }
        .onChange(of: windowContainer.chatDraftVM.text) { _, _ in
            syncPluginConversationContext()
        }
        .onChange(of: windowContainer.messageQueueVM.queueVersion) { _, _ in
            syncPluginConversationContext()
            pluginConversationVM.notifyPendingMessagesChanged()
        }
        .onChange(of: windowContainer.agentAttachmentsVM.pendingAttachments) { _, _ in
            syncPluginConversationContext()
            pluginConversationVM.notifyAttachmentsChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .conversationDidChange)) { notification in
            syncPluginConversationListContext()
            guard let change = Self.conversationListChange(from: notification) else { return }
            pluginConversationListContext.notifyConversationChanged(change)
        }
        .onReceive(windowContainer.conversationSendStatusVM.$statusMessageByConversationId) { _ in
            pluginConversationVM.notifyStatusChanged()
            pluginConversationListContext.notifyConversationStatusChanged()
        }
    }

    private var llmLifecycleScene: some View {
        projectLifecycleScene
        .onChange(of: container.agentSessionConfig.selectedProviderId) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.currentModel) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.isAutoMode) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.chatMode) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.verbosity) { _, _ in syncPluginLLMContext() }
    }

    private var appLayoutLifecycleScene: some View {
        llmLifecycleScene
        .onChange(of: windowContainer.layoutVM.bottomPanelVisible) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.contentPanelVisible) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.editorVisible) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.railVisible) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.rightSidebarVisible) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.activeViewContainerIcon) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.selectedAgentSidebarTabId) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.selectedAgentDetailId) { _, _ in syncLayoutPluginContext() }
        .onChange(of: windowContainer.layoutVM.layoutRatios) { _, _ in syncLayoutPluginContext() }
    }

    private var pluginLayoutLifecycleScene: some View {
        appLayoutLifecycleScene
        .onChange(of: pluginLayoutContext.bottomPanelVisible) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.contentPanelVisible) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.editorVisible) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.railVisible) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.rightSidebarVisible) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.activeViewContainerIcon) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.selectedAgentSidebarTabId) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.selectedAgentDetailId) { _, _ in propagateLayoutPluginContextToApp() }
        .onChange(of: pluginLayoutContext.layoutRatios) { _, _ in propagateLayoutPluginContextToApp() }
    }

    private var configuredContent: some View {
        windowEnvironmentContent
            .environment(\.windowContainer, windowContainer)
            .modelContainer(container.modelContainer)
    }

    private var windowEnvironmentContent: some View {
        globalEnvironmentContent
            // 窗口级 VM（每窗口独立）
            .environmentObject(windowContainer)
            .environmentObject(windowContainer.editorVM)
            .environmentObject(windowContainer.editorVM.service)
            .environmentObject(windowContainer.conversationVM)
            .environmentObject(pluginConversationVM)
            .environmentObject(pluginConversationListContext)
            .environmentObject(windowContainer.projectVM)
            .environmentObject(pluginProjectContext)
            .environmentObject(windowContainer.layoutVM)
            .environmentObject(pluginLayoutContext)
            .environmentObject(windowContainer.messageQueueVM)
            .environmentObject(windowContainer.agentAttachmentsVM)
            .environmentObject(windowContainer.inputQueueVM)
            .environmentObject(windowContainer.chatDraftVM)
            .environmentObject(windowContainer.permissionHandlingVM)
            .environmentObject(windowContainer.commandSuggestionVM)
            .environmentObject(windowContainer.permissionRequestVM)
            .environmentObject(windowContainer.taskCancellationVM)
            .environmentObject(windowContainer.conversationSendStatusVM)
            .environmentObject(windowContainer.projectContextRequestVM)
    }

    private var globalEnvironmentContent: some View {
        content
            .withMagicToast()
            // 全局 VM（所有窗口共享）
            .environmentObject(container.windowManagerVM)
            .environmentObject(container.themeVM)
            .environmentObject(pluginThemeVM)
            .environmentObject(pluginEditorContext)
            .environmentObject(container.providerRegistry)
            .environmentObject(container.pluginVM)
            .environmentObject(pluginPluginVM)
            .environmentObject(container.messageRendererVM)
            .environmentObject(container.conversationTurnServices)
            .environmentObject(container.agentSessionConfig)
            .environmentObject(pluginLLMVM)
            .environmentObject(container.chatHistoryVM)
            .environmentObject(container.recentProjectsVM)
            .environmentObject(pluginRecentProjectsVM)
            .environmentObject(container.gitVM)
            .environmentObject(pluginGitVM)
            .environmentObject(container.idleTimeVM)
    }

    private func performInitialLifecycleSetup() {
        syncPluginProjectContext()
        syncPluginRecentProjectsContext()
        syncPluginConversationContext()
        syncPluginConversationListContext()
        syncPluginLLMContext()
        syncLayoutPluginContext()
        configureDefaultIconProvider()
        configurePluginProjectBridge()
        configureConversationListContext()
        configureEditorStickySymbolBarPluginBridge()
        configureEditorTabStripPluginBridge()
        configureEditorRailWorkspaceSymbolsPluginBridge()
        configurePluginFontBridge()
        configureGoEditorPluginBridge()
        configureJSEditorPluginBridge()
        configureScreenshotPluginBridge()
        configureTerminalPluginBridge()
        configureMessageRendererPluginBridge()
        configureQuickFileSearchPluginBridge()
        configureProjectsPluginBridge()
        configureAutoTaskPluginBridge()
        configureAgentTurnNotificationPluginBridge()
        configureEditorContextBridge()
    }

    /// 设置首次回退图标提供者，供 LayoutPlugin 在磁盘无记录时使用
    private func configureDefaultIconProvider() {
        let pluginVM = container.pluginVM
        pluginLayoutContext.defaultIconProvider = { [pluginVM] in
            pluginVM.getViewContainerItems().first?.icon
        }
    }

    private func syncPluginProjectContext() {
        pluginProjectContext.update(
            currentProjectName: windowContainer.projectVM.currentProjectName,
            currentProjectPath: windowContainer.projectVM.currentProjectPath,
            languagePreference: windowContainer.projectVM.languagePreference
        )
    }

    private func syncPluginRecentProjectsContext() {
        pluginRecentProjectsVM.setRecentProjects(
            container.recentProjectsVM.recentProjects.map {
                LumiCoreKit.Project(name: $0.name, path: $0.path, lastUsed: $0.lastUsed)
            }
        )
    }

    private func syncPluginConversationContext() {
        pluginConversationVM.windowId = windowContainer.id
        pluginConversationVM.selectedConversationId = windowContainer.conversationVM.selectedConversationId
        pluginConversationVM.updateDraftTextFromHost(windowContainer.chatDraftVM.text)
        pluginConversationVM.messagesProvider = { [container] conversationId in
            container.chatHistoryVM.loadMessagesAsync(forConversationId: conversationId) ?? []
        }
        pluginConversationVM.statusMessageProvider = { [windowContainer] conversationId in
            windowContainer.conversationSendStatusVM.statusMessage(for: conversationId)
        }
        pluginConversationVM.verbosityPreferenceProvider = { [windowContainer] in
            windowContainer.conversationVM.getVerbosityPreference()
                .flatMap { LumiCoreKit.ResponseVerbosity(rawValue: $0.rawValue) }
        }
        pluginConversationVM.verbosityPreferenceSaver = { [windowContainer] verbosity in
            let appVerbosity = verbosity.flatMap { ResponseVerbosity(rawValue: $0.rawValue) }
            windowContainer.conversationVM.saveVerbosityPreference(appVerbosity)
        }
        pluginConversationVM.pendingMessagesProvider = { [windowContainer] conversationId in
            windowContainer.messageQueueVM.pendingMessages(for: conversationId)
        }
        pluginConversationVM.pendingMessageRemover = { [windowContainer] messageId in
            windowContainer.messageQueueVM.removeMessage(id: messageId)
        }
        pluginConversationVM.pendingAttachmentsProvider = { [windowContainer] in
            windowContainer.agentAttachmentsVM.pendingAttachments
        }
        pluginConversationVM.attachmentRemover = { [windowContainer] attachmentId in
            windowContainer.agentAttachmentsVM.removeAttachment(id: attachmentId)
        }
        pluginConversationVM.imageUploadHandler = { [windowContainer] url in
            windowContainer.agentAttachmentsVM.handleImageUpload(url: url)
        }
        pluginConversationVM.screenshotDataHandler = { [windowContainer] data in
            windowContainer.agentAttachmentsVM.handleScreenshotData(data)
        }
        pluginConversationVM.draftTextAppender = { [windowContainer] text in
            windowContainer.chatDraftVM.append(text)
        }
        pluginConversationVM.draftTextSetter = { [windowContainer] text in
            windowContainer.chatDraftVM.set(text)
        }
        pluginConversationVM.textSubmitter = { [windowContainer] text in
            windowContainer.inputQueueVM.enqueueText(text)
        }
    }

    private func syncPluginConversationListContext() {
        pluginConversationListContext.selectedConversationId = windowContainer.conversationVM.selectedConversationId
        pluginConversationListContext.fetchAllConversationsProvider = { [weak windowContainer] in
            guard let windowContainer else { return [] }
            return windowContainer.conversationVM.fetchAllConversations().map(Self.conversationListItem)
        }
        pluginConversationListContext.fetchConversationsPageProvider = { [weak windowContainer] limit, offset in
            guard let windowContainer else { return [] }
            return windowContainer.conversationVM.fetchConversationsPage(limit: limit, offset: offset).map(Self.conversationListItem)
        }
        pluginConversationListContext.fetchConversationProvider = { [weak windowContainer] id in
            guard let windowContainer else { return nil }
            return windowContainer.conversationVM.fetchConversation(id: id).map(Self.conversationListItem)
        }
        pluginConversationListContext.selectConversationHandler = { [weak windowContainer] id, reason in
            windowContainer?.switchToConversation(id, reason: reason)
        }
        pluginConversationListContext.deleteConversationHandler = { [weak windowContainer] id in
            guard let windowContainer else { return false }
            guard let conversation = windowContainer.conversationVM.fetchConversation(id: id) else { return false }
            windowContainer.conversationVM.deleteConversation(conversation)
            return true
        }
        pluginConversationListContext.updateConversationTitleHandler = { [weak windowContainer] id, title in
            guard let windowContainer else { return false }
            guard let conversation = windowContainer.conversationVM.fetchConversation(id: id) else { return false }
            windowContainer.conversationVM.updateConversationTitle(conversation, newTitle: title)
            return true
        }
        pluginConversationListContext.updateProjectAssociationHandler = { [weak windowContainer] id, projectPath in
            guard let windowContainer else { return false }
            guard let conversation = windowContainer.conversationVM.fetchConversation(id: id) else { return false }
            windowContainer.conversationVM.updateProjectAssociation(for: conversation, projectPath: projectPath)
            return true
        }
        pluginConversationListContext.createConversationHandler = { [weak windowContainer] projectName, projectPath, languagePreference in
            guard let windowContainer else { return nil }
            await windowContainer.conversationVM.createNewConversation(
                projectName: projectName,
                projectPath: projectPath,
                languagePreference: languagePreference
            )
            return windowContainer.conversationVM.selectedConversationId
        }
        pluginConversationListContext.switchProjectHandler = { [weak windowContainer] projectPath, reason in
            guard let windowContainer else { return }
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            windowContainer.projectVM.switchProject(
                to: Project(name: projectName, path: projectPath, lastUsed: Date()),
                reason: reason
            )
        }
        pluginConversationListContext.isConversationProcessingProvider = { [weak windowContainer] id in
            guard let windowContainer else { return false }
            return windowContainer.conversationSendStatusVM.isMessageProcessing(for: id)
        }
        pluginConversationListContext.databaseDirectoryProvider = {
            AppConfig.getDBFolderURL()
        }
        container.toolService.setConversationListContext(
            pluginConversationListContext,
            windowId: windowContainer.id,
            currentProjectName: windowContainer.projectVM.currentProjectName,
            currentProjectPath: windowContainer.projectVM.currentProjectPath
        )
    }

    private func handleFileDroppedToChat(_ url: URL) {
        let fileURL = url.standardizedFileURL
        if Self.isChatImageFileURL(fileURL) {
            windowContainer.agentAttachmentsVM.handleImageUpload(url: fileURL)
        } else {
            windowContainer.chatDraftVM.append(fileURL.path)
        }
    }

    static func isChatImageFileURL(_ url: URL) -> Bool {
        let imagePathExtensions: Set<String> = [
            "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
        ]
        return imagePathExtensions.contains(url.pathExtension.lowercased())
    }

    private func handleOpenFileInEditor(_ url: URL) {
        let fileURL = url.standardizedFileURL
        windowContainer.editorVM.service.open(at: fileURL)
        windowContainer.openFile(fileURL)
    }

    private func syncPluginLLMContext() {
        pluginLLMVM.selectedProviderId = container.agentSessionConfig.selectedProviderId
        pluginLLMVM.currentModel = container.agentSessionConfig.currentModel
        pluginLLMVM.isAutoMode = container.agentSessionConfig.isAutoMode
        pluginLLMVM.lastAutoRouteSummary = container.agentSessionConfig.lastAutoRouteSummary
        pluginLLMVM.updateChatModeFromHost(LumiCoreKit.ChatMode(rawValue: container.agentSessionConfig.chatMode.rawValue) ?? .build)
        pluginLLMVM.updateVerbosityFromHost(LumiCoreKit.ResponseVerbosity(rawValue: container.agentSessionConfig.verbosity.rawValue) ?? .brief)

        // 桥接 provider 查询方法，让插件 VM 能获取已注册的供应商列表
        let appLLMVM = container.agentSessionConfig
        pluginLLMVM.providersProvider = { appLLMVM.allProviders }
        pluginLLMVM.providerTypeProvider = { appLLMVM.providerType(forId: $0) }
        pluginLLMVM.providerFactory = { appLLMVM.createProvider(id: $0) }
        pluginLLMVM.apiKeyProvider = { appLLMVM.getApiKey(for: $0) }

        pluginLLMVM.chatModeSetter = { [container, windowContainer] chatMode in
            guard let appChatMode = ChatMode(rawValue: chatMode.rawValue) else { return }
            container.agentSessionConfig.setChatMode(appChatMode)
            windowContainer.conversationVM.saveChatModePreference(appChatMode)
        }
        pluginLLMVM.verbositySetter = { [container, windowContainer] verbosity in
            guard let appVerbosity = ResponseVerbosity(rawValue: verbosity.rawValue) else { return }
            container.agentSessionConfig.setVerbosity(appVerbosity)
            windowContainer.conversationVM.saveVerbosityPreference(appVerbosity)
        }
    }

    private func syncLayoutPluginContext() {
        pluginLayoutContext.update(
            bottomPanelVisible: windowContainer.layoutVM.bottomPanelVisible,
            contentPanelVisible: windowContainer.layoutVM.contentPanelVisible,
            editorVisible: windowContainer.layoutVM.editorVisible,
            railVisible: windowContainer.layoutVM.railVisible,
            rightSidebarVisible: windowContainer.layoutVM.rightSidebarVisible,
            activeViewContainerIcon: windowContainer.layoutVM.activeViewContainerIcon,
            selectedAgentSidebarTabId: windowContainer.layoutVM.selectedAgentSidebarTabId,
            selectedAgentDetailId: windowContainer.layoutVM.selectedAgentDetailId,
            layoutRatios: windowContainer.layoutVM.layoutRatios
        )
    }

    private func propagateLayoutPluginContextToApp() {
        let layoutVM = windowContainer.layoutVM
        layoutVM.restoreFromPlugin(activeViewContainerIcon: pluginLayoutContext.activeViewContainerIcon)
        layoutVM.restoreFromPlugin(tabId: pluginLayoutContext.selectedAgentSidebarTabId)
        layoutVM.restoreFromPlugin(detailId: pluginLayoutContext.selectedAgentDetailId)
        layoutVM.restoreFromPlugin(ratios: pluginLayoutContext.layoutRatios)
        layoutVM.restoreFromPlugin(bottomPanelVisible: pluginLayoutContext.bottomPanelVisible)
        layoutVM.restoreFromPlugin(contentPanelVisible: pluginLayoutContext.contentPanelVisible)
        layoutVM.restoreFromPlugin(editorVisible: pluginLayoutContext.editorVisible)
        layoutVM.restoreFromPlugin(railVisible: pluginLayoutContext.railVisible)
        layoutVM.restoreFromPlugin(rightSidebarVisible: pluginLayoutContext.rightSidebarVisible)
    }

    private func configurePluginProjectBridge() {
        PluginProjectContext.switchProjectHandler = { [container, windowContainer] project, reason in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            targetWindow.projectVM.switchProject(
                to: Project(name: project.name, path: project.path, lastUsed: project.lastUsed),
                reason: reason
            )
        }
    }

    private func configureProjectsPluginBridge() {
        ProjectsBridge.currentProjectPathProvider = { [container, windowContainer] in
            Self.targetWindowContainer(fallback: windowContainer, rootContainer: container).projectPath
        }
        pluginConversationVM.switchToLatestConversationHandler = { [windowContainer] projectPath in
            windowContainer.conversationVM.switchToLatestConversation(forProject: projectPath)
        }
        pluginConversationVM.createNewConversationHandler = { [windowContainer] projectName, projectPath, languagePreference in
            await windowContainer.conversationVM.createNewConversation(
                projectName: projectName,
                projectPath: projectPath,
                languagePreference: languagePreference
            )
        }
    }

    private func configureAgentTurnNotificationPluginBridge() {
        AgentTurnNotificationRuntime.selectConversation = { [container, windowContainer] conversationId in
            Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
                .switchToConversation(conversationId, reason: "agentTurnNotification")
        }
    }

    private func configureEditorContextBridge() {
        // 桥接主题提供者
        pluginEditorContext.configureThemeProvider { [container] in
            container.themeVM.activeChromeTheme
        }
        pluginEditorContext.configureFileIconThemeProvider { [container] in
            container.themeVM.activeFileIconTheme
        }
        // 桥接编辑器操作
        pluginEditorContext.openFileHandler = { [container, windowContainer] url in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            targetWindow.editorVM.service.open(at: url)
        }
        pluginEditorContext.refreshProjectContextHandler = { [container, windowContainer] projectPath in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            await targetWindow.editorVM.service.refreshProjectContext(for: projectPath)
        }
        pluginEditorContext.addToConversationHandler = { [container] fileURL, windowId in
            NotificationCenter.postFileDroppedToChat(fileURL: fileURL, windowId: windowId)
        }
        EditorContext.syncSelectedFileNotificationName = .syncSelectedFile
        // 同步当前选中文件
        syncEditorContextFileURL()
    }

    private func syncEditorContextFileURL() {
        pluginEditorContext.updateCurrentFileURL(windowContainer.editorVM.service.currentFileURL)
    }

    private func configureMessageRendererPluginBridge() {
        MessageRendererRuntime.showsAssistantHeaderProvider = { [container] in
            container.agentSessionConfig.verbosity == .detailed
        }
    }

    private func configurePluginFontBridge() {
        FontConfigViewModel.applyFontNameHandler = { [container, windowContainer] fontName in
            Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
                .editorVM.service.state.fontName = fontName
        }
    }

    private func configureGoEditorPluginBridge() {
        GoEditorBridge.openFileHandler = { [container, windowContainer] url, projectRoot in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            await targetWindow.editorVM.service.refreshProjectContext(for: projectRoot)
            targetWindow.editorVM.service.open(at: url)
        }
    }

    private func configureEditorStickySymbolBarPluginBridge() {
        EditorStickySymbolBarBridge.editorServiceProvider = { [container, windowContainer] context in
            Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                .editorVM.service
        }
    }

    private func configureEditorTabStripPluginBridge() {
        EditorTabStripBridge.editorServiceProvider = { [container, windowContainer] context in
            Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                .editorVM.service
        }
    }

    private func configureEditorRailWorkspaceSymbolsPluginBridge() {
        EditorRailWorkspaceSymbolsBridge.editorServiceProvider = { [container, windowContainer] context in
            Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                .editorVM.service
        }
    }

    private func configureJSEditorPluginBridge() {
        JSEditorBridge.openFileHandler = { [container, windowContainer] url, projectRoot in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            await targetWindow.editorVM.service.refreshProjectContext(for: projectRoot)
            targetWindow.editorVM.service.open(at: url)
        }
    }

    private func configureScreenshotPluginBridge() {
        ScreenshotBridge.activeWindowIdProvider = { [container] in
            container.windowManagerVM.activeWindowId
        }
    }

    private func configureTerminalPluginBridge() {
        TerminalPluginBridge.editorThemeIdProvider = { [container] in
            container.themeVM.activeEditorThemeId
        }
    }

    private func configureQuickFileSearchPluginBridge() {
        QuickFileSearchBridge.activeWindowIdProvider = { [container] in
            container.windowManagerVM.activeWindowId
        }
        QuickFileSearchBridge.selectFileHandler = { [container] path, windowId in
            NotificationCenter.postSyncSelectedFile(
                path: path,
                windowId: windowId ?? container.windowManagerVM.activeWindowId
            )
        }
    }

    private func configureAutoTaskPluginBridge() {
        AutoTaskPlugin.configuration = AppAutoTaskConfiguration()
    }

    private func configureConversationListContext() {
        syncPluginConversationListContext()
    }

    private static func conversationListItem(_ conversation: Conversation) -> LumiCoreKit.ConversationListItem {
        LumiCoreKit.ConversationListItem(
            id: conversation.id,
            projectPath: conversation.projectId,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt
        )
    }

    private static func conversationListChange(from notification: Notification) -> LumiCoreKit.ConversationListChange? {
        guard
            let userInfo = notification.userInfo,
            let typeRaw = userInfo[ConversationChangeUserInfoKey.type] as? String,
            let idRaw = userInfo[ConversationChangeUserInfoKey.conversationId] as? String,
            let type = LumiCoreKit.ConversationListChangeType(rawValue: typeRaw),
            let conversationId = UUID(uuidString: idRaw)
        else {
            return nil
        }

        return LumiCoreKit.ConversationListChange(type: type, conversationId: conversationId)
    }

    private static func targetWindowContainer(
        for context: PluginContext,
        fallback: WindowContainer,
        rootContainer: RootContainer
    ) -> WindowContainer {
        if let windowId = context.windowId,
           let targetWindow = rootContainer.windowManagerVM.getContainer(windowId) {
            return targetWindow
        }
        return targetWindowContainer(fallback: fallback, rootContainer: rootContainer)
    }

    private static func targetWindowContainer(
        fallback: WindowContainer,
        rootContainer: RootContainer
    ) -> WindowContainer {
        rootContainer.windowManagerVM.activeWindowContainer ?? fallback
    }
}

private struct AppAutoTaskConfiguration: AutoTaskConfiguration {
    func databaseDirectory() -> URL {
        AppConfig.getDBFolderURL()
    }

    @MainActor
    func enqueueUserMessage(_ message: ChatMessage, turnContext: TurnFinishedContext) {
        guard let appContext = turnContext as? AppTurnFinishedContext else { return }
        appContext.messageQueueVM.enqueueMessage(message)
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Parameter container: 窗口容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView(container: WindowContainer) -> some View {
        RootView(container: container, content: { self })
    }

    /// Preview 专用：使用 fallback WindowContainer 注入环境对象
    ///
    /// 生产代码请使用 `inRootView(container:)` 传入窗口容器。
    /// 此方法仅用于 #Preview 和设置窗口等无窗口上下文的场景。
    func inRootView() -> some View {
        inRootView(container: WindowContainer(container: RootContainer.shared))
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView(container: WindowContainer(container: RootContainer.shared))
        .withDebugBar()
}
