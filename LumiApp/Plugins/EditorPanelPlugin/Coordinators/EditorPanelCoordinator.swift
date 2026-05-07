import Combine
import SwiftUI
import os

/// 编辑器面板协调器
///
/// 负责管理 EditorPanelView 的生命周期事件（`onAppear`/`onDisappear`/`onChange`）
/// 和编辑器命令通知的路由。将视图层的副作用编排逻辑从 EditorPanelView 中提取出来，
/// 使视图专注于纯布局。
///
/// ## 职责
///
/// - 项目路径变化时：保存旧 tab → 清理 → 刷新上下文 → 恢复新 tab
/// - 文件选择变化时：打开或激活对应会话
/// - 编辑器命令通知 → 分发到 EditorState
/// - `onAppear` / `onDisappear` 初始化和清理
///
/// ## 使用方式
///
/// ```swift
/// @StateObject private var coordinator = EditorPanelCoordinator()
/// coordinator.configure(panelService: service, projectVM: projectVM, ...)
/// ```
@MainActor
final class EditorPanelCoordinator: ObservableObject {

    // MARK: - 属性

    /// 面板业务逻辑服务
    private var panelService: EditorPanelService?

    /// 编辑器状态
    private var state: EditorState?

    /// 会话存储
    private var sessionStore: EditorSessionStore?

    /// 项目 ViewModel（弱引用避免循环引用）
    private weak var projectVM: ProjectVM?

    /// Combine 订阅令牌
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 配置

    /// 配置协调器的依赖（在视图 onAppear 时调用）
    func configure(
        panelService: EditorPanelService,
        state: EditorState,
        sessionStore: EditorSessionStore,
        projectVM: ProjectVM
    ) {
        self.panelService = panelService
        self.state = state
        self.sessionStore = sessionStore
        self.projectVM = projectVM
    }

    // MARK: - 生命周期

    /// 视图出现时的初始化逻辑
    func handleAppear() {
        guard let panelService, let state, let sessionStore, let projectVM else { return }

        EditorPlugin.logger.info(
            "\(EditorPlugin.t)onAppear, currentProjectPath=\(projectVM.currentProjectPath, privacy: .public), activeSessionID=\(sessionStore.activeSessionID?.uuidString ?? "nil", privacy: .public), currentFileURL=\(state.currentFileURL?.path ?? "nil", privacy: .public)"
        )

        state.projectRootPath = projectVM.currentProject?.path
        panelService.refreshProjectContext(for: projectVM.currentProjectPath, state: state)

        state.onActiveSessionChanged = { snapshot in
            sessionStore.syncActiveSession(from: snapshot)
        }

        if sessionStore.activeSessionID != nil || state.currentFileURL != nil {
            panelService.openOrActivateSession(
                for: state.currentFileURL ?? sessionStore.activeSession?.fileURL,
                state: state,
                sessionStore: sessionStore,
                projectRootPath: projectVM.currentProject?.path,
                currentProjectPath: projectVM.currentProjectPath
            )
            state.refreshDocumentOutline()
        }

        panelService.updateBreadcrumbBridge(state: state)
    }

    /// 视图消失时的清理逻辑
    func handleDisappear() {
        guard let panelService, let state, let projectVM else { return }

        let projectPath = projectVM.currentProjectPath
        if !projectPath.isEmpty, let sessionStore {
            panelService.saveCurrentTabs(
                forProject: projectPath,
                state: state,
                sessionStore: sessionStore
            )
        }

        if state.hasUnsavedChanges { state.saveNow() }
        state.onActiveSessionChanged = nil
        panelService.clearBreadcrumbBridge()
    }

    // MARK: - 项目路径变化

    /// 处理项目路径变化
    func handleProjectPathChange(oldPath: String, newPath: String) {
        guard let panelService, let state, let sessionStore, let projectVM else { return }

        EditorPlugin.logger.info("\(EditorPlugin.t)项目路径变化, oldPath=\(oldPath, privacy: .public), newPath=\(newPath, privacy: .public)")

        // 保存旧项目的标签页
        if !oldPath.isEmpty {
            panelService.saveCurrentTabs(
                forProject: oldPath,
                state: state,
                sessionStore: sessionStore
            )
        }

        // 保存未保存的变更后关闭所有编辑器会话
        if state.hasUnsavedChanges { state.saveNow() }
        sessionStore.closeAll()
        state.loadFile(from: nil)
        panelService.refreshProjectContext(for: newPath, state: state)

        // 恢复新项目的标签页
        if !newPath.isEmpty {
            panelService.restoreTabs(
                forProject: newPath,
                state: state
            ) { url in
                panelService.openOrActivateSession(
                    for: url,
                    state: state,
                    sessionStore: sessionStore,
                    projectRootPath: projectVM.currentProject?.path,
                    currentProjectPath: projectVM.currentProjectPath
                )
            }
        }
    }

    // MARK: - 当前文件 / 光标 / 符号变化

    /// 处理当前文件 URL 变化（state 层面）
    func handleCurrentFileURLChange() {
        guard let panelService, let state else { return }
        state.refreshDocumentOutline()
        panelService.updateBreadcrumbBridge(state: state)
    }

    /// 处理光标行变化
    func handleCursorLineChange() {
        guard let panelService, let state else { return }
        panelService.updateBreadcrumbBridge(state: state)
    }

    /// 处理文档符号变化
    func handleDocumentSymbolsChange() {
        guard let panelService, let state else { return }
        panelService.updateBreadcrumbBridge(state: state)
    }

    // MARK: - 命令通知订阅

    /// 订阅所有编辑器命令通知，返回视图修饰器
    func subscribeEditorCommands(
        isCommandPalettePresented: Binding<Bool>
    ) -> AnyPublisher<EditorCommandEvent, Never> {
        let notificationMap: [(Notification.Name, String)] = [
            (.lumiEditorUndo, "builtin.undo"),
            (.lumiEditorRedo, "builtin.redo"),
            (.lumiEditorFormatDocument, "builtin.format-document"),
            (.lumiEditorFindReferences, "builtin.find-references"),
            (.lumiEditorQuickFix, "builtin.quick-fix"),
            (.lumiEditorRenameSymbol, "builtin.rename-symbol"),
            (.lumiEditorWorkspaceSymbols, "builtin.workspace-symbols"),
            (.lumiEditorCallHierarchy, "builtin.call-hierarchy"),
            (.lumiEditorToggleFind, "builtin.find"),
            (.lumiEditorSearchInFiles, "builtin.search-in-files"),
            (.lumiEditorFindNext, "builtin.find-next"),
            (.lumiEditorFindPrevious, "builtin.find-previous"),
            (.lumiEditorReplaceCurrent, "builtin.replace-current"),
            (.lumiEditorReplaceAll, "builtin.replace-all"),
        ]

        let commandPublishers = notificationMap.map { name, commandID in
            NotificationCenter.default.publisher(for: name)
                .map { _ in EditorCommandEvent.command(commandID) }
                .eraseToAnyPublisher()
        }

        let commandPalettePublisher = NotificationCenter.default.publisher(for: .lumiEditorShowCommandPalette)
            .map { _ in EditorCommandEvent.showCommandPalette }
            .eraseToAnyPublisher()

        let toggleOutlinePublisher = NotificationCenter.default.publisher(for: .lumiEditorToggleOutlinePanel)
            .map { _ in EditorCommandEvent.toggleOutlinePanel }
            .eraseToAnyPublisher()

        return Publishers.MergeMany(commandPublishers + [commandPalettePublisher, toggleOutlinePublisher])
            .eraseToAnyPublisher()
    }

    /// 处理编辑器命令事件
    func handleCommandEvent(_ event: EditorCommandEvent) {
        guard let panelService, let state, let sessionStore else { return }

        switch event {
        case .command(let commandID):
            panelService.handleEditorCommandEvent(
                commandID,
                state: state,
                isFileSelected: sessionStore.activeSessionID != nil || state.currentFileURL != nil
            )
        case .showCommandPalette:
            panelService.isCommandPalettePresented = true
        case .toggleOutlinePanel:
            state.performPanelCommand(.toggleOutline)
        }
    }
}

// MARK: - EditorCommandEvent

/// 编辑器命令事件
enum EditorCommandEvent {
    case command(String)
    case showCommandPalette
    case toggleOutlinePanel
}
