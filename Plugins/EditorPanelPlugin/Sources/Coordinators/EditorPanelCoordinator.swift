import Combine
import EditorService
import LumiKernel
import SwiftUI
import os

/// 编辑器面板协调器
///
/// 负责管理 EditorPanelView 的生命周期事件（`onAppear`/`onDisappear`/`onChange`）
/// 和编辑器命令通知的路由。将视图层的副作用编排逻辑从 EditorPanelView 中提取出来。
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
/// coordinator.configure(panelService: service, projectPath: ..., ...)
/// ```
@MainActor
public final class EditorPanelCoordinator: ObservableObject {

    // MARK: - 属性

    /// 面板业务逻辑服务
    private var panelService: EditorPanelService?

    /// 编辑器服务门面
    private var service: EditorService?

    /// 核心服务访问（weak 防止循环引用）
    private weak var kernel: LumiKernel?

    /// Combine 订阅令牌
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 配置

    /// 配置协调器的依赖（在视图 onAppear 时调用）
    public func configure(
        panelService: EditorPanelService,
        service: EditorService
    ) {
        self.panelService = panelService
        self.service = service
    }

    // MARK: - 生命周期

    /// 视图出现时的初始化逻辑
    public func handleAppear() {
        guard let panelService, let service else { return }
        let projectPath = kernel?.project?.currentProject?.path ?? ""

        if EditorPanelPlugin.verbose {
            EditorPanelPlugin.logger.info(
                "onAppear, currentProjectPath=\(projectPath, privacy: .public)"
            )
        }

        service.projectRootPath = projectRootPath(from: projectPath)
        panelService.refreshProjectContext(for: projectPath, service: service)

        if service.sessions.activeSessionID != nil || service.files.currentFileURL != nil {
            panelService.openOrActivateSession(
                for: service.files.currentFileURL ?? service.sessions.activeSession?.fileURL,
                service: service,
                projectRootPath: projectRootPath(from: projectPath),
                currentProjectPath: projectPath
            )
            service.lsp.refreshDocumentOutline()
        }
    }

    /// 视图消失时的清理逻辑
    public func handleDisappear() {
        guard let service else { return }

        if service.files.hasUnsavedChanges { service.files.saveNow() }
    }

    /// App 切到后台时保存当前脏文件，匹配 VS Code 的 focus-change auto save 行为。
    public func handleApplicationDidResignActive() {
        guard let service, service.files.hasUnsavedChanges else { return }
        service.files.saveNow()
    }

    // MARK: - 项目路径变化

    /// 处理项目路径变化
    public func handleProjectPathChange(oldPath: String, newPath: String) {
        guard let panelService, let service else { return }

        if EditorPanelPlugin.verbose {
            EditorPanelPlugin.logger.info(
                "项目路径变化, oldPath=\(oldPath, privacy: .public), newPath=\(newPath, privacy: .public)"
            )
        }

        // 保存未保存的变更后关闭所有编辑器会话
        if service.files.hasUnsavedChanges { service.files.saveNow() }
        service.sessions.closeAllSessions()
        service.files.loadFile(from: nil)
        service.projectRootPath = projectRootPath(from: newPath)
        panelService.refreshProjectContext(for: newPath, service: service)
    }

    // MARK: - 当前文件 / 光标 / 符号变化

    /// 处理当前文件 URL 变化（state 层面）
    public func handleCurrentFileURLChange() {
        guard let service else { return }
        service.lsp.refreshDocumentOutline()
    }

    // MARK: - 命令通知订阅

    /// 订阅所有编辑器命令通知，返回视图修饰器
    public func subscribeEditorCommands(
        isCommandPalettePresented: Binding<Bool>
    ) -> AnyPublisher<EditorCommandEvent, Never> {
        let notificationMap: [(Notification.Name, String)] = [
            (.lumiEditorUndo, "builtin.undo"),
            (.lumiEditorRedo, "builtin.redo"),
            (.lumiEditorSave, "builtin.save"),
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
                .compactMap { [weak self] notification -> EditorCommandEvent? in
                    guard self?.isTargeted(notification) == true else { return nil }
                    return EditorCommandEvent.command(commandID)
                }
                .eraseToAnyPublisher()
        }

        let commandPalettePublisher = NotificationCenter.default.publisher(for: .lumiEditorShowCommandPalette)
            .compactMap { [weak self] notification -> EditorCommandEvent? in
                guard self?.isTargeted(notification) == true else { return nil }
                return EditorCommandEvent.showCommandPalette
            }
            .eraseToAnyPublisher()

        return Publishers.MergeMany(commandPublishers + [commandPalettePublisher])
            .eraseToAnyPublisher()
    }

    /// 处理编辑器命令事件
    public func handleCommandEvent(_ event: EditorCommandEvent) {
        guard let panelService, let service else { return }

        switch event {
        case .command(let commandID):
            panelService.handleEditorCommandEvent(
                commandID,
                service: service,
                isFileSelected: service.sessions.activeSessionID != nil || service.files.currentFileURL != nil
            )
        case .showCommandPalette:
            panelService.isCommandPalettePresented = true
        }
    }

    private func isTargeted(_ notification: Notification) -> Bool {
        guard let targetWindowId = notification.userInfo?["windowId"] as? UUID else {
            return true
        }
        return service?.state.windowId == targetWindowId
    }

    private func projectRootPath(from path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - EditorCommandEvent

/// 编辑器命令事件
public enum EditorCommandEvent {
    case command(String)
    case showCommandPalette
}
