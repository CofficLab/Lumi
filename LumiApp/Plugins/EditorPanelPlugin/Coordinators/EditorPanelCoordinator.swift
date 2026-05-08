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
/// - 项目路径变化时：清理 → 刷新上下文
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

    /// 编辑器服务门面
    private var service: EditorService?

    /// 项目 ViewModel（弱引用避免循环引用）
    private weak var projectVM: ProjectVM?

    /// Combine 订阅令牌
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 配置

    /// 配置协调器的依赖（在视图 onAppear 时调用）
    func configure(
        panelService: EditorPanelService,
        service: EditorService,
        projectVM: ProjectVM
    ) {
        self.panelService = panelService
        self.service = service
        self.projectVM = projectVM
    }

    // MARK: - 生命周期

    /// 视图出现时的初始化逻辑
    func handleAppear() {
        guard let panelService, let service, let projectVM else { return }

        EditorPlugin.logger.info(
            "\(EditorPlugin.t)onAppear, currentProjectPath=\(projectVM.currentProjectPath, privacy: .public), activeSessionID=\(service.activeSessionID?.uuidString ?? "nil", privacy: .public), currentFileURL=\(service.currentFileURL?.path ?? "nil", privacy: .public)"
        )

        service.projectRootPath = projectVM.currentProject?.path
        panelService.refreshProjectContext(for: projectVM.currentProjectPath, service: service)

        service.onActiveSessionChanged = { snapshot in
            service.syncActiveSession(from: snapshot)
        }

        if service.activeSessionID != nil || service.currentFileURL != nil {
            panelService.openOrActivateSession(
                for: service.currentFileURL ?? service.activeSession?.fileURL,
                service: service,
                projectRootPath: projectVM.currentProject?.path,
                currentProjectPath: projectVM.currentProjectPath
            )
            service.refreshDocumentOutline()
        }

        panelService.updateBreadcrumbBridge(service: service)
    }

    /// 视图消失时的清理逻辑
    func handleDisappear() {
        guard let panelService, let service else { return }

        if service.hasUnsavedChanges { service.saveNow() }
        service.onActiveSessionChanged = nil
        panelService.clearBreadcrumbBridge()
    }

    // MARK: - 项目路径变化

    /// 处理项目路径变化
    func handleProjectPathChange(oldPath: String, newPath: String) {
        guard let panelService, let service else { return }

        EditorPlugin.logger.info("\(EditorPlugin.t)项目路径变化, oldPath=\(oldPath, privacy: .public), newPath=\(newPath, privacy: .public)")

        // 保存未保存的变更后关闭所有编辑器会话
        if service.hasUnsavedChanges { service.saveNow() }
        service.closeAllSessions()
        service.loadFile(from: nil)
        panelService.refreshProjectContext(for: newPath, service: service)
    }

    // MARK: - 当前文件 / 光标 / 符号变化

    /// 处理当前文件 URL 变化（state 层面）
    func handleCurrentFileURLChange() {
        guard let panelService, let service else { return }
        service.refreshDocumentOutline()
        panelService.updateBreadcrumbBridge(service: service)
    }

    /// 处理光标行变化
    func handleCursorLineChange() {
        guard let panelService, let service else { return }
        panelService.updateBreadcrumbBridge(service: service)
    }

    /// 处理文档符号变化
    func handleDocumentSymbolsChange() {
        guard let panelService, let service else { return }
        panelService.updateBreadcrumbBridge(service: service)
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
        guard let panelService, let service else { return }

        switch event {
        case .command(let commandID):
            panelService.handleEditorCommandEvent(
                commandID,
                service: service,
                isFileSelected: service.activeSessionID != nil || service.currentFileURL != nil
            )
        case .showCommandPalette:
            panelService.isCommandPalettePresented = true
        case .toggleOutlinePanel:
            service.performPanelCommand(.toggleOutline)
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
