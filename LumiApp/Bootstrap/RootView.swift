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
    @StateObject private var pluginPluginVM = LumiCoreKit.AppPluginVM()
    @StateObject private var pluginLLMVM = LumiCoreKit.AppLLMVM()
    @StateObject private var pluginGitVM = LumiCoreKit.AppGitVM()
    @StateObject private var pluginConversationVM = LumiCoreKit.WindowConversationVM()
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
    }

    private var llmLifecycleScene: some View {
        projectLifecycleScene
        .onChange(of: container.agentSessionConfig.selectedProviderId) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.currentModel) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.isAutoMode) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.chatMode) { _, _ in syncPluginLLMContext() }
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
            .environmentObject(windowContainer.conversationVM)
            .environmentObject(pluginConversationVM)
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
            .environmentObject(windowContainer.chatTimelineViewModel)
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
        syncPluginLLMContext()
        syncLayoutPluginContext()
        configurePluginProjectBridge()
        configureEditorStickySymbolBarPluginBridge()
        configureEditorTabStripPluginBridge()
        configureEditorRailWorkspaceSymbolsPluginBridge()
        configurePluginFontBridge()
        configureGoEditorPluginBridge()
        configureJSEditorPluginBridge()
        configureScreenshotPluginBridge()
        configureTerminalPluginBridge()
        configureQuickFileSearchPluginBridge()
        configureProjectsPluginBridge()
        configureAutoTaskPluginBridge()
        configureAgentTurnNotificationPluginBridge()
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
        pluginLLMVM.chatModeSetter = { [container, windowContainer] chatMode in
            guard let appChatMode = ChatMode(rawValue: chatMode.rawValue) else { return }
            container.agentSessionConfig.setChatMode(appChatMode)
            windowContainer.conversationVM.saveChatModePreference(appChatMode)
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
        ProjectsPlugin.ProjectsBridge.currentProjectPathProvider = { [container, windowContainer] in
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
        AgentTurnNotificationPlugin.AgentTurnNotificationRuntime.selectConversation = { [container, windowContainer] conversationId in
            Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
                .switchToConversation(conversationId, reason: "agentTurnNotification")
        }
    }

    private func configurePluginFontBridge() {
        FontConfigPlugin.FontConfigViewModel.applyFontNameHandler = { [container, windowContainer] fontName in
            Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
                .editorVM.service.state.fontName = fontName
        }
    }

    private func configureGoEditorPluginBridge() {
        GoEditorPlugin.GoEditorBridge.openFileHandler = { [container, windowContainer] url, projectRoot in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            await targetWindow.editorVM.service.refreshProjectContext(for: projectRoot)
            targetWindow.editorVM.service.open(at: url)
        }
    }

    private func configureEditorStickySymbolBarPluginBridge() {
        EditorStickySymbolBarPlugin.EditorStickySymbolBarBridge.editorServiceProvider = { [container, windowContainer] context in
            Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                .editorVM.service
        }
    }

    private func configureEditorTabStripPluginBridge() {
        EditorTabStripPlugin.EditorTabStripBridge.editorServiceProvider = { [container, windowContainer] context in
            Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                .editorVM.service
        }
    }

    private func configureEditorRailWorkspaceSymbolsPluginBridge() {
        EditorRailWorkspaceSymbolsPlugin.EditorRailWorkspaceSymbolsBridge.editorServiceProvider = { [container, windowContainer] context in
            Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                .editorVM.service
        }
    }

    private func configureJSEditorPluginBridge() {
        JSEditorPlugin.JSEditorBridge.openFileHandler = { [container, windowContainer] url, projectRoot in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            await targetWindow.editorVM.service.refreshProjectContext(for: projectRoot)
            targetWindow.editorVM.service.open(at: url)
        }
    }

    private func configureScreenshotPluginBridge() {
        ScreenshotPlugin.ScreenshotBridge.activeWindowIdProvider = { [container] in
            container.windowManagerVM.activeWindowId
        }
    }

    private func configureTerminalPluginBridge() {
        TerminalPlugin.TerminalPluginBridge.editorThemeIdProvider = { [container] in
            container.themeVM.activeEditorThemeId
        }
    }

    private func configureQuickFileSearchPluginBridge() {
        QuickFileSearchPlugin.QuickFileSearchBridge.activeWindowIdProvider = { [container] in
            container.windowManagerVM.activeWindowId
        }
        QuickFileSearchPlugin.QuickFileSearchBridge.selectFileHandler = { [container] path, windowId in
            NotificationCenter.postSyncSelectedFile(
                path: path,
                windowId: windowId ?? container.windowManagerVM.activeWindowId
            )
        }
    }

    private func configureAutoTaskPluginBridge() {
        AutoTaskPlugin.AutoTaskPlugin.configuration = AppAutoTaskConfiguration()
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
