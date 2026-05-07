import CodeEditSourceEditor
import Foundation
import MagicKit
import os

/// 编辑器面板业务逻辑服务
///
/// 封装 Session 操作、标签页持久化、导航、项目上下文刷新等业务逻辑，
/// 从 EditorPanelView 中提取，使视图层保持纯粹的布局职责。
///
/// ## 使用方式
///
/// ```swift
/// @StateObject private var service = EditorPanelService()
///
/// // 在视图中通过 service 调用业务方法
/// service.openOrActivateSession(for: url, state: state, sessionStore: store)
/// service.saveCurrentTabs(forProject: path, state: state, sessionStore: store)
/// ```
@MainActor
final class EditorPanelService: ObservableObject {

    // MARK: - 属性

    /// 标签页持久化存储
    private let tabStore = EditorTabStripStore.shared

    /// 防抖保存的 Task
    private var tabSaveTask: Task<Void, Never>?

    /// 首次 appear 后延迟恢复标签页的 Task
    private(set) var tabRestoreTask: Task<Void, Never>?

    /// 当前拖拽中的标签页 Session ID
    @Published var draggedTabSessionID: EditorSession.ID?

    /// 命令面板是否展示
    @Published var isCommandPalettePresented: Bool = false

    // MARK: - Tab 持久化

    /// 保存当前打开的标签页到持久化存储
    func saveCurrentTabs(
        forProject projectPath: String,
        state: EditorState,
        sessionStore: EditorSessionStore
    ) {
        let activeTabPath = state.currentFileURL?.path
        tabStore.saveTabs(
            projectPath: projectPath,
            tabs: sessionStore.tabs,
            activeTabPath: activeTabPath
        )
    }

    /// 从持久化存储恢复标签页
    func restoreTabs(
        forProject projectPath: String,
        state: EditorState,
        selectFile: @MainActor (URL) -> Void
    ) {
        let (persistedTabs, activeTabPath) = tabStore.loadTabs(forProject: projectPath)
        EditorPlugin.logger.info("\(EditorPlugin.t)恢复标签页, projectPath=\(projectPath, privacy: .public), persistedCount=\(persistedTabs.count), activeTabPath=\(activeTabPath ?? "nil", privacy: .public)")

        // 过滤掉不存在的文件
        let validTabs = persistedTabs.compactMap { tab -> URL? in
            guard let url = tab.fileURL,
                  FileManager.default.isReadableFile(atPath: url.path) else {
                EditorPlugin.logger.warning("\(EditorPlugin.t)跳过不可读文件: \(tab.path, privacy: .public)")
                return nil
            }
            return url
        }

        EditorPlugin.logger.info("\(EditorPlugin.t)有效标签页数=\(validTabs.count)")
        guard !validTabs.isEmpty else { return }

        // 先打开最后一个保存的活跃标签
        if let activePath = activeTabPath,
           let activateURL = validTabs.first(where: { $0.path == activePath }) {
            EditorPlugin.logger.info("\(EditorPlugin.t)选择活跃标签: \(activateURL.path, privacy: .public)")
            selectFile(activateURL)
        } else if let fallbackURL = validTabs.first {
            EditorPlugin.logger.info("\(EditorPlugin.t)选择第一个标签: \(fallbackURL.path, privacy: .public)")
            selectFile(fallbackURL)
        }
    }

    /// 防抖保存当前标签页（2 秒延迟，避免频繁写入）
    func scheduleTabSave(
        projectPath: String,
        state: EditorState,
        sessionStore: EditorSessionStore
    ) {
        tabSaveTask?.cancel()
        tabSaveTask = Task { [weak self] in
            try? await Task.sleep(for: Duration.seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveCurrentTabs(
                forProject: projectPath,
                state: state,
                sessionStore: sessionStore
            )
        }
    }

    /// 取消标签页恢复任务
    func cancelTabRestore() {
        tabRestoreTask?.cancel()
        tabRestoreTask = nil
    }

    /// 取消标签页保存任务
    func cancelTabSave() {
        tabSaveTask?.cancel()
    }

    // MARK: - Session 管理

    /// 打开或激活一个编辑器会话
    func openOrActivateSession(
        for fileURL: URL?,
        state: EditorState,
        sessionStore: EditorSessionStore,
        projectRootPath: String?,
        currentProjectPath: String
    ) {
        EditorPlugin.logger.info("\(EditorPlugin.t)打开或激活 session, fileURL=\(fileURL?.path ?? "nil", privacy: .public), currentProjectPath=\(currentProjectPath, privacy: .public)")
        state.projectRootPath = projectRootPath
        refreshProjectContext(for: currentProjectPath, state: state)

        guard let session = sessionStore.openOrActivate(fileURL: fileURL) else {
            EditorPlugin.logger.info("\(EditorPlugin.t)session 为 nil → loadFile(nil), fileURL=\(fileURL?.path ?? "nil", privacy: .public)")
            state.loadFile(from: nil)
            return
        }

        EditorPlugin.logger.info("\(EditorPlugin.t)加载 session 文件: \(session.fileURL?.path ?? "nil", privacy: .public), sessionID=\(session.id)")
        state.loadFile(from: session.fileURL)
        restoreInteractionState(for: session, state: state)
        scheduleTabSave(
            projectPath: currentProjectPath,
            state: state,
            sessionStore: sessionStore
        )
    }

    /// 激活指定标签页对应的会话
    func activateSession(
        _ tab: EditorTab,
        sessionStore: EditorSessionStore,
        selectFile: @MainActor (URL) -> Void
    ) {
        _ = sessionStore.activate(sessionID: tab.sessionID)
        if let fileURL = tab.fileURL {
            selectFile(fileURL)
        }
    }

    /// 激活 Open Editor 列表中的条目
    func activateOpenEditor(
        _ item: EditorOpenEditorItem,
        sessionStore: EditorSessionStore,
        selectFile: @MainActor (URL) -> Void
    ) {
        _ = sessionStore.activate(sessionID: item.sessionID)
        if let fileURL = item.fileURL {
            selectFile(fileURL)
        }
    }

    /// 通过 Quick Open 打开文件
    func openFileFromQuickOpen(
        _ url: URL,
        target: CursorPosition?,
        highlightLine: Bool,
        state: EditorState,
        sessionStore: EditorSessionStore,
        projectRootPath: String?,
        currentProjectPath: String
    ) {
        openOrActivateSession(
            for: url,
            state: state,
            sessionStore: sessionStore,
            projectRootPath: projectRootPath,
            currentProjectPath: currentProjectPath
        )
        guard let target else { return }
        state.performNavigation(.definition(url, target, highlightLine: highlightLine))
    }

    /// 关闭指定标签页的会话
    func closeSession(
        _ tab: EditorTab,
        state: EditorState,
        sessionStore: EditorSessionStore,
        clearFileSelection: @MainActor () -> Void,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        let wasActive = session.id == sessionStore.activeSessionID
        if wasActive, state.hasUnsavedChanges {
            state.saveNow()
        }

        let nextSession = sessionStore.close(sessionID: session.id)
        guard wasActive else { return }

        if let nextFileURL = nextSession?.fileURL {
            selectFile(nextFileURL)
        } else {
            clearFileSelection()
        }
    }

    /// 关闭除指定标签页外的所有会话
    func closeOtherSessions(
        _ tab: EditorTab,
        state: EditorState,
        sessionStore: EditorSessionStore,
        clearFileSelection: @MainActor () -> Void,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        if state.currentFileURL != session.fileURL, state.hasUnsavedChanges {
            state.saveNow()
        }

        let keptSession = sessionStore.closeOthers(keeping: session.id)
        if let fileURL = keptSession?.fileURL {
            selectFile(fileURL)
        } else {
            clearFileSelection()
        }
    }

    /// 导航后退
    func navigateBack(
        sessionStore: EditorSessionStore,
        state: EditorState,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = sessionStore.goBack(),
              let fileURL = session.fileURL else { return }
        selectFile(fileURL)
        restoreInteractionState(for: session, state: state)
    }

    /// 导航前进
    func navigateForward(
        sessionStore: EditorSessionStore,
        state: EditorState,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = sessionStore.goForward(),
              let fileURL = session.fileURL else { return }
        selectFile(fileURL)
        restoreInteractionState(for: session, state: state)
    }

    /// 切换标签页固定状态
    func togglePinned(sessionID: EditorSession.ID, sessionStore: EditorSessionStore) {
        sessionStore.togglePinned(sessionID: sessionID)
    }

    /// 拖拽排序 — 开始拖拽
    func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    /// 拖拽排序 — 放下
    func dropDraggedTabInActiveStrip(
        before targetTab: EditorTab?,
        sessionStore: EditorSessionStore
    ) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        _ = sessionStore.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }

    // MARK: - 项目上下文

    /// 刷新项目上下文
    func refreshProjectContext(for projectPath: String, state: EditorState) {
        let trimmedPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            state.refreshProjectContextSnapshot()
            return
        }
        Task { @MainActor in
            await state.projectContextCapability?.projectOpened(at: trimmedPath)
            state.refreshProjectContextSnapshot()
        }
    }

    // MARK: - 面包屑

    /// 更新面包屑桥接
    func updateBreadcrumbBridge(state: EditorState) {
        let activeSymbolTrail = state.documentSymbolProvider.activeItems(for: state.cursorLine)
        EditorBreadcrumbContextBridge.shared.update(
            currentFileURL: state.currentFileURL,
            activeSymbolTrail: activeSymbolTrail,
            openSymbol: { [weak state] symbol in
                state?.performOpenItem(.documentSymbol(symbol))
            }
        )
    }

    /// 清空面包屑桥接
    func clearBreadcrumbBridge() {
        EditorBreadcrumbContextBridge.shared.update(
            currentFileURL: nil,
            activeSymbolTrail: [],
            openSymbol: nil
        )
    }

    // MARK: - 打开的编辑器列表

    /// 获取排序后的打开编辑器列表
    var openEditorItems: (EditorSessionStore) -> [EditorOpenEditorItem] {
        return { sessionStore in
            sessionStore.tabs.map { tab in
                EditorOpenEditorItem(
                    sessionID: tab.sessionID,
                    fileURL: tab.fileURL,
                    title: tab.title,
                    isDirty: tab.isDirty,
                    isPinned: tab.isPinned,
                    isActive: tab.sessionID == sessionStore.activeSessionID,
                    recentActivationRank: sessionStore.recentActivationRank(for: tab.sessionID)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive && !rhs.isActive
                }
                if lhs.recentActivationRank != rhs.recentActivationRank {
                    return (lhs.recentActivationRank ?? .max) < (rhs.recentActivationRank ?? .max)
                }
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    // MARK: - 项目上下文警告

    /// 项目上下文警告信息（用于文件信息 Banner 显示）
    func projectContextWarningMessage(state: EditorState) -> String? {
        guard let snapshot = state.projectContextSnapshot, snapshot.isStructuredProject else { return nil }
        switch snapshot.contextStatus {
        case .unavailable, .needsResync:
            return String(localized: "Project semantic context is not ready, cross-file semantic capabilities may be unstable.", table: "LumiEditor")
        default:
            break
        }
        guard state.currentFileURL != nil else { return nil }
        if !snapshot.currentFileIsInTarget {
            return String(localized: "Current file is not bound to any build target, cross-file navigation and diagnostics may be unavailable.", table: "LumiEditor")
        }
        if let activeScheme = snapshot.activeScheme,
           let currentTarget = snapshot.currentFilePrimaryTarget,
           !currentTarget.isEmpty,
           !snapshot.activeSchemeBuildableTargets.isEmpty,
           !snapshot.activeSchemeBuildableTargets.contains(currentTarget) {
            return String(localized: "Current file belongs to target '\(currentTarget)', but current scheme '\(activeScheme)' may not cover it.", table: "LumiEditor")
        }
        if snapshot.currentFileMatchedTargets.count > 1 {
            if let preferredTarget = snapshot.currentFilePrimaryTarget, !preferredTarget.isEmpty {
                return String(localized: "Current file belongs to multiple targets; the editor is currently parsing with '\(preferredTarget)' context.", table: "LumiEditor")
            }
            let targets = snapshot.currentFileMatchedTargets.joined(separator: ", ")
            return String(localized: "Current file belongs to multiple targets (\(targets)); semantic results depend on current scheme and configuration.", table: "LumiEditor")
        }
        return nil
    }

    // MARK: - 命令处理

    /// 处理编辑器命令事件
    func handleEditorCommandEvent(
        _ commandID: String,
        state: EditorState,
        isFileSelected: Bool
    ) {
        guard isFileSelected else { return }
        state.performEditorCommand(id: commandID)
    }

    // MARK: - 私有方法

    /// 恢复交互状态
    private func restoreInteractionState(for session: EditorSession, state: EditorState) {
        let snapshot = session

        guard let fileURL = snapshot.fileURL else { return }

        let canRestoreImmediately =
            state.currentFileURL == fileURL &&
            state.content != nil &&
            state.focusedTextView != nil

        if canRestoreImmediately {
            state.applySessionRestore(snapshot)
            return
        }

        if state.currentFileURL != fileURL {
            state.loadFile(from: fileURL)
        }
    }
}
