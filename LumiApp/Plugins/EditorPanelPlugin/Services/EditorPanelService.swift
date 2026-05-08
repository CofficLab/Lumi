import CodeEditSourceEditor
import Foundation
import MagicKit
import os

/// 编辑器面板业务逻辑服务
///
/// 封装 Session 操作、导航、项目上下文刷新等业务逻辑，
/// 从 EditorPanelView 中提取，使视图层保持纯粹的布局职责。
///
/// ## 使用方式
///
/// ```swift
/// @StateObject private var service = EditorPanelService()
///
/// // 在视图中通过 service 调用业务方法
/// service.openOrActivateSession(for: url, service: service, ...)
/// ```
@MainActor
final class EditorPanelService: ObservableObject {

    // MARK: - 属性

    /// 当前拖拽中的标签页 Session ID
    @Published var draggedTabSessionID: UUID?

    /// 命令面板是否展示
    @Published var isCommandPalettePresented: Bool = false

    // MARK: - Session 管理

    /// 打开或激活一个编辑器会话
    func openOrActivateSession(
        for fileURL: URL?,
        service: EditorService,
        projectRootPath: String?,
        currentProjectPath: String
    ) {
        EditorPlugin.logger.info("\(EditorPlugin.t)打开或激活 session, fileURL=\(fileURL?.path ?? "nil", privacy: .public), currentProjectPath=\(currentProjectPath, privacy: .public)")
        service.projectRootPath = projectRootPath
        refreshProjectContext(for: currentProjectPath, service: service)

        guard let session = service.openFile(at: fileURL) else {
            EditorPlugin.logger.info("\(EditorPlugin.t)session 为 nil → loadFile(nil), fileURL=\(fileURL?.path ?? "nil", privacy: .public)")
            service.loadFile(from: nil)
            return
        }

        EditorPlugin.logger.info("\(EditorPlugin.t)加载 session 文件: \(session.fileURL?.path ?? "nil", privacy: .public), sessionID=\(session.id)")
        service.loadFile(from: session.fileURL)
        restoreInteractionState(for: session, service: service)
    }

    /// 激活指定标签页对应的会话
    func activateSession(
        _ tab: EditorTab,
        service: EditorService,
        selectFile: @MainActor (URL) -> Void
    ) {
        _ = service.activateSession(id: tab.sessionID)
        if let fileURL = tab.fileURL {
            selectFile(fileURL)
        }
    }

    /// 激活 Open Editor 列表中的条目
    func activateOpenEditor(
        _ item: EditorOpenEditorItem,
        service: EditorService,
        selectFile: @MainActor (URL) -> Void
    ) {
        _ = service.activateSession(id: item.sessionID)
        if let fileURL = item.fileURL {
            selectFile(fileURL)
        }
    }

    /// 通过 Quick Open 打开文件
    func openFileFromQuickOpen(
        _ url: URL,
        target: CursorPosition?,
        highlightLine: Bool,
        service: EditorService,
        projectRootPath: String?,
        currentProjectPath: String
    ) {
        openOrActivateSession(
            for: url,
            service: service,
            projectRootPath: projectRootPath,
            currentProjectPath: currentProjectPath
        )
        guard let target else { return }
        service.performNavigation(.definition(url, target, highlightLine: highlightLine))
    }

    /// 关闭指定标签页的会话
    func closeSession(
        _ tab: EditorTab,
        service: EditorService,
        clearFileSelection: @MainActor () -> Void,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = service.session(for: tab.sessionID) else { return }
        let wasActive = session.id == service.activeSessionID
        if wasActive, service.hasUnsavedChanges {
            service.saveNow()
        }

        let nextSession = service.closeSession(id: session.id)
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
        service: EditorService,
        clearFileSelection: @MainActor () -> Void,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = service.session(for: tab.sessionID) else { return }
        if service.currentFileURL != session.fileURL, service.hasUnsavedChanges {
            service.saveNow()
        }

        let keptSession = service.closeOtherSessions(keeping: session.id)
        if let fileURL = keptSession?.fileURL {
            selectFile(fileURL)
        } else {
            clearFileSelection()
        }
    }

    /// 导航后退
    func navigateBack(
        service: EditorService,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = service.goBack(),
              let fileURL = session.fileURL else { return }
        selectFile(fileURL)
        restoreInteractionState(for: session, service: service)
    }

    /// 导航前进
    func navigateForward(
        service: EditorService,
        selectFile: @MainActor (URL) -> Void
    ) {
        guard let session = service.goForward(),
              let fileURL = session.fileURL else { return }
        selectFile(fileURL)
        restoreInteractionState(for: session, service: service)
    }

    /// 切换标签页固定状态
    func togglePinned(sessionID: UUID, service: EditorService) {
        service.togglePinned(sessionID: sessionID)
    }

    /// 拖拽排序 — 开始拖拽
    func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    /// 拖拽排序 — 放下
    func dropDraggedTabInActiveStrip(
        before targetTab: EditorTab?,
        service: EditorService
    ) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        _ = service.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }

    // MARK: - 项目上下文

    /// 刷新项目上下文
    func refreshProjectContext(for projectPath: String, service: EditorService) {
        let trimmedPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            service.refreshProjectContext()
            return
        }
        Task { @MainActor in
            await service.projectContextCapability?.projectOpened(at: trimmedPath)
            service.refreshProjectContext()
        }
    }

    // MARK: - 面包屑

    /// 更新面包屑桥接
    func updateBreadcrumbBridge(service: EditorService) {
        let activeSymbolTrail = service.documentSymbolProvider.activeItems(for: service.cursorLine)
        EditorBreadcrumbContextBridge.shared.update(
            currentFileURL: service.currentFileURL,
            activeSymbolTrail: activeSymbolTrail,
            openSymbol: { [weak service] symbol in
                service?.performOpenItem(.documentSymbol(symbol))
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
    func openEditorItems(_ service: EditorService) -> [EditorOpenEditorItem] {
        service.tabs.map { tab in
            EditorOpenEditorItem(
                sessionID: tab.sessionID,
                fileURL: tab.fileURL,
                title: tab.title,
                isDirty: tab.isDirty,
                isPinned: tab.isPinned,
                isActive: tab.sessionID == service.activeSessionID,
                recentActivationRank: service.recentActivationRank(for: tab.sessionID)
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

    // MARK: - 项目上下文警告

    /// 项目上下文警告信息（用于文件信息 Banner 显示）
    func projectContextWarningMessage(service: EditorService) -> String? {
        guard let snapshot = service.projectContextSnapshot, snapshot.isStructuredProject else { return nil }
        switch snapshot.contextStatus {
        case .unavailable, .needsResync:
            return String(localized: "Project semantic context is not ready, cross-file semantic capabilities may be unstable.", table: "LumiEditor")
        default:
            break
        }
        guard service.currentFileURL != nil else { return nil }
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
        service: EditorService,
        isFileSelected: Bool
    ) {
        guard isFileSelected else { return }
        service.performCommand(id: commandID)
    }

    // MARK: - 私有方法

    /// 恢复交互状态
    private func restoreInteractionState(for session: EditorSession, service: EditorService) {
        let snapshot = session

        guard let fileURL = snapshot.fileURL else { return }

        let canRestoreImmediately =
            service.currentFileURL == fileURL &&
            service.content != nil &&
            service.focusedTextView != nil

        if canRestoreImmediately {
            service.applySessionRestore(snapshot)
            return
        }

        if service.currentFileURL != fileURL {
            service.loadFile(from: fileURL)
        }
    }
}
