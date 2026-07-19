import EditorService
import Foundation
import os
import SuperLogKit
import LumiKernel

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
public final class EditorPanelService: ObservableObject, SuperLog {

    // MARK: - 属性

    /// 命令面板是否展示
    @Published var isCommandPalettePresented: Bool = false

    // MARK: - Session 管理

    /// 打开或激活一个编辑器会话
    ///
    /// 注意：此方法不负责刷新项目上下文，调用方应在此之前单独调用
    /// `refreshProjectContext(for:service:)` 确保上下文就绪。
    public func openOrActivateSession(
        for fileURL: URL?,
        service: EditorService,
        projectRootPath: String?,
        currentProjectPath: String
    ) {
        if EditorPanelPlugin.verbose {
            EditorPanelPlugin.logger.info(
                "打开或激活 session, fileURL=\(fileURL?.path ?? "nil", privacy: .public), currentProjectPath=\(currentProjectPath, privacy: .public)"
            )
        }
        service.projectRootPath = projectRootPath

        guard let fileURL else {
            if EditorPanelPlugin.verbose {
                EditorPanelPlugin.logger.info("\(Self.t)fileURL 为 nil → loadFile(nil)")
            }
            service.files.loadFile(from: nil)
            return
        }

        if EditorPanelPlugin.verbose {
            EditorPanelPlugin.logger.info("\(Self.t)打开文件: \(fileURL.path, privacy: .public)")
        }
        service.sessions.open(at: fileURL)
    }

    /// 通过 Quick Open 打开文件
    public func openFileFromQuickOpen(
        _ url: URL,
        target: CursorPosition?,
        highlightLine: Bool,
        service: EditorService,
        projectRootPath: String?,
        currentProjectPath: String
    ) {
        refreshProjectContext(for: currentProjectPath, service: service)
        openOrActivateSession(
            for: url,
            service: service,
            projectRootPath: projectRootPath,
            currentProjectPath: currentProjectPath
        )
        guard let target else { return }
        service.navigation.performNavigation(.definition(url, target, highlightLine: highlightLine))
    }

    // MARK: - 项目上下文

    /// 刷新项目上下文
    public func refreshProjectContext(for projectPath: String, service: EditorService) {
        let trimmedPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            service.refreshProjectContext()
            return
        }
        Task { @MainActor in
            await service.refreshProjectContext(for: trimmedPath)
        }
    }

    // MARK: - 打开的编辑器列表

    /// 获取排序后的打开编辑器列表
    public func openEditorItems(_ service: EditorService) -> [EditorOpenEditorItem] {
        service.sessions.tabs.map { tab in
            EditorOpenEditorItem(
                sessionID: tab.sessionID,
                fileURL: tab.fileURL,
                title: tab.title,
                isDirty: tab.isDirty,
                isPinned: tab.isPinned,
                isActive: tab.sessionID == service.sessions.activeSessionID,
                recentActivationRank: service.sessions.recentActivationRank(for: tab.sessionID)
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

    // MARK: - 命令处理

    /// 处理编辑器命令事件
    public func handleEditorCommandEvent(
        _ commandID: String,
        service: EditorService,
        isFileSelected: Bool
    ) {
        guard isFileSelected else { return }
        service.commands.performCommand(id: commandID)
    }
}
