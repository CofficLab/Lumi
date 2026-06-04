import AppKit
import Combine
import Foundation
import LumiCoreKit
import os

/// 自动化控制器 — 集中处理自动化测试动作
///
/// 在应用启动时初始化，监听 `.automationActionReceived` 通知，
/// 根据 action 名称路由到相应的处理器。
/// 不依赖任何视图是否可见，直接操作 VM 层。
@MainActor
final class AutomationController: SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - Singleton

    static let shared = AutomationController()

    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "automation.controller"
    )

    private var cancellables: Set<AnyCancellable> = []

    private init() {}

    // MARK: - Lifecycle

    /// 启动自动化控制器，注册通知监听
    func start() {
        NotificationCenter.default.publisher(for: .automationActionReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAction(notification)
            }
            .store(in: &cancellables)

        Self.logger.info("\(Self.t)AutomationController started")
    }

    /// 停止自动化控制器
    func stop() {
        cancellables.removeAll()
        Self.logger.info("\(Self.t)AutomationController stopped")
    }

    // MARK: - Action Routing

    private func handleAction(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? String else {
            return
        }

        let payload = userInfo["payload"] as? [String: Any]
        let targetScope = Self.targetWindowContainer(payload: payload)

        Self.logger.info("🤖 Routing action: \(action, privacy: .public)")

        switch action {
        // Inline Preview 操作
        case "inline_preview.start_stream", "inline_preview.startStream":
            handleInlinePreviewStartStream(payload: payload, scope: targetScope)
        case "inline_preview.stop_stream", "inline_preview.stopStream":
            handleInlinePreviewStopStream(payload: payload, scope: targetScope)
        case "inline_preview.demoFrame", "inline_preview.demo_frame":
            handleInlinePreviewDemoFrame(payload: payload, scope: targetScope)

        // 导航操作
        case "navigate.to", "navigateTo":
            handleNavigateTo(payload: payload, scope: targetScope)

        // 编辑器操作
        case "editor.openFile", "editor.open_file":
            handleEditorOpenFile(payload: payload, scope: targetScope)

        // 通用按钮点击（通过 plugin + view id）
        case "button.click", "buttonClick":
            handleButtonClick(payload: payload)

        // 项目持久化自测
        case "project.select", "projectSelect":
            handleProjectSelect(payload: payload, scope: targetScope)
        case "app.terminate", "appTerminate":
            handleAppTerminate()

        // 主题切换
        case "theme.switch", "themeSwitch":
            handleThemeSwitch(payload: payload)

        default:
            Self.logger.info("🤖 Unhandled action: \(action, privacy: .public)")
        }
    }

    // MARK: - Handlers

    /// 处理 Inline Preview 启动流
    private func handleInlinePreviewStartStream(payload: [String: Any]?, scope: WindowContainer?) {
        Self.logger.info("🤖 Handling inline_preview.startStream")

        ensureEditorPanelActive(scope: scope)
        ensureInlinePreviewBottomTabActive(scope: scope)
        InlinePreviewAutomationState.shared.lastSessionActionName = "start"
        InlinePreviewAutomationState.shared.sessionAction = .start
    }

    /// 处理 Inline Preview 停止流
    private func handleInlinePreviewStopStream(payload: [String: Any]?, scope: WindowContainer?) {
        Self.logger.info("🤖 Handling inline_preview.stopStream")

        ensureEditorPanelActive(scope: scope)
        ensureInlinePreviewBottomTabActive(scope: scope)
        InlinePreviewAutomationState.shared.lastSessionActionName = "stop"
        InlinePreviewAutomationState.shared.sessionAction = .stop
    }

    /// 处理 Inline Preview demo frame 自动化请求。
    private func handleInlinePreviewDemoFrame(payload: [String: Any]?, scope: WindowContainer?) {
        Self.logger.info("🤖 Handling inline_preview.demoFrame")

        ensureEditorPanelActive(scope: scope)
        ensureInlinePreviewBottomTabActive(scope: scope)
        InlinePreviewAutomationState.shared.demoFrameRequestCount += 1
        InlinePreviewAutomationState.shared.lastDemoFramePayload = payload ?? [:]
    }

    /// 处理导航到指定面板
    private func handleNavigateTo(payload: [String: Any]?, scope: WindowContainer?) {
        guard let panel = payload?["panel"] as? String else {
            Self.logger.warning("🤖 navigate.to: missing 'panel' in payload")
            return
        }

        Self.logger.info("🤖 Navigating to panel: \(panel, privacy: .public)")

        switch panel {
        case "editor", "code", "codeEditor":
            ensureEditorPanelActive(scope: scope)
        case "chat", "agent":
            ensureAgentPanelActive(scope: scope)
        default:
            Self.logger.warning("🤖 Unknown panel: \(panel, privacy: .public)")
        }
    }

    /// 处理编辑器打开文件
    private func handleEditorOpenFile(payload: [String: Any]?, scope: WindowContainer?) {
        guard let path = payload?["path"] as? String else {
            Self.logger.warning("🤖 editor.openFile: missing 'path' in payload")
            return
        }

        guard let url = Self.existingRegularFileURL(path: path) else {
            Self.logger.warning("🤖 editor.openFile: path is not an existing file: \(path, privacy: .public)")
            return
        }

        Self.logger.info("🤖 Opening file: \(url.path, privacy: .public)")

        guard let scope else {
            Self.logger.warning("🤖 editor.openFile: no target window scope")
            return
        }

        ensureEditorPanelActive(scope: scope)

        // 直接通过 EditorService 打开文件，触发完整流程：
        // 1. EditorService.open(at:) → 创建/激活 session + 加载内容
        // 2. EditorPreviewDetailView.onChange(of: currentFileURL) → setActiveFile
        // 3. EditorPreviewViewModel.autoBuildIfPossible → 扫描 #Preview + 自动编译
        let editorService = scope.editorVM.service
        editorService.open(at: url)

        Self.logger.info("🤖 File opened: \(url.lastPathComponent, privacy: .public)")
    }

    static func existingRegularFileURL(path: String, fileManager: FileManager = .default) -> URL? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard !expandedPath.isEmpty else { return nil }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }

        return URL(fileURLWithPath: expandedPath).standardizedFileURL
    }

    /// 模拟用户选择当前窗口项目并触发持久化
    private func handleProjectSelect(payload: [String: Any]?, scope: WindowContainer?) {
        guard let path = payload?["path"] as? String, !path.isEmpty else {
            Self.logger.warning("🤖 project.select: missing 'path' in payload")
            return
        }

        guard let scope else {
            Self.logger.warning("🤖 project.select: no target window scope")
            return
        }

        guard let projectURL = Self.existingDirectoryURL(path: path) else {
            Self.logger.warning("🤖 project.select: path is not an existing directory: \(path, privacy: .public)")
            return
        }

        let projectPath = projectURL.path
        let name = projectURL.lastPathComponent
        scope.projectVM.switchProject(
            to: Project(name: name, path: projectPath, lastUsed: Date()),
            reason: "automationSelectProject"
        )
        NotificationCenter.default.post(name: .windowStateShouldPersist, object: nil)
        NotificationCenter.postCurrentProjectDidChange(name: name, path: projectPath)

        Self.logger.info("🤖 project.select: \(projectPath, privacy: .public)")
    }

    static func existingDirectoryURL(path: String, fileManager: FileManager = .default) -> URL? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard !expandedPath.isEmpty else { return nil }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        return URL(fileURLWithPath: expandedPath, isDirectory: true).standardizedFileURL
    }

    private static func targetWindowContainer(payload: [String: Any]?) -> WindowContainer? {
        if let windowId = windowId(from: payload),
           let targetWindow = RootContainer.shared.windowManagerVM.getContainer(windowId) {
            return targetWindow
        }
        return RootContainer.shared.windowManagerVM.activeWindowContainer
    }

    private static func windowId(from payload: [String: Any]?) -> UUID? {
        if let windowId = payload?["windowId"] as? UUID {
            return windowId
        }
        if let windowIdString = payload?["windowId"] as? String {
            return UUID(uuidString: windowIdString)
        }
        return nil
    }

    private func handleAppTerminate() {
        Self.logger.info("🤖 app.terminate")
        NSApp.terminate(nil)
    }

    /// 处理主题切换
    private func handleThemeSwitch(payload: [String: Any]?) {
        guard let themeId = payload?["themeId"] as? String else {
            Self.logger.warning("🤖 theme.switch: missing 'themeId' in payload")
            return
        }

        Self.logger.info("🤖 Switching theme to: \(themeId, privacy: .public)")

        // 直接通过 AppThemeVM 切换主题
        let themeVM = RootContainer.shared.themeVM
        guard themeVM.selectTheme(themeId) else {
            Self.logger.warning("🤖 theme.switch: unknown themeId '\(themeId, privacy: .public)'")
            return
        }

        Self.logger.info("🤖 Theme switched to: \(themeId, privacy: .public)")
    }

    /// 处理通用按钮点击
    private func handleButtonClick(payload: [String: Any]?) {
        guard let buttonId = payload?["buttonId"] as? String else {
            Self.logger.warning("🤖 button.click: missing 'buttonId' in payload")
            return
        }

        Self.logger.info("🤖 Button click: \(buttonId, privacy: .public)")
    }

    // MARK: - Helpers

    /// 确保编辑器面板处于活动状态
    private func ensureEditorPanelActive(scope: WindowContainer?) {
        scope?.layoutVM.activeViewContainerIcon = "chevron.left.forwardslash.chevron.right"
        InlinePreviewAutomationState.shared.editorPanelActivationCount += 1
        Self.logger.info("🤖 Activated editor panel")
    }

    /// 确保底部面板的 Inline Preview tab 被激活
    private func ensureInlinePreviewBottomTabActive(scope: WindowContainer?) {
        var userInfo: [String: Any] = ["tabId": "editor-bottom-inline-preview"]
        if let windowId = scope?.id {
            userInfo["windowId"] = windowId
        }

        NotificationCenter.default.post(
            name: .automationActivateBottomTab,
            object: nil,
            userInfo: userInfo
        )
        InlinePreviewAutomationState.shared.inlinePreviewTabActivationCount += 1
        Self.logger.info("🤖 Activated inline preview bottom tab")
    }

    /// 确保 Agent 面板处于活动状态
    private func ensureAgentPanelActive(scope: WindowContainer?) {
        // Agent 面板通常是默认面板
        scope?.layoutVM.activeViewContainerIcon = nil
    }
}
