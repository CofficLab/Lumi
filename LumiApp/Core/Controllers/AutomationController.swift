import AppKit
import Combine
import Foundation
import MagicAlert
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

        Self.logger.info("🤖 Routing action: \(action, privacy: .public)")

        switch action {
        // Inline Preview 操作
        case "inline_preview.start_stream", "inline_preview.startStream":
            handleInlinePreviewStartStream(payload: payload)
        case "inline_preview.stop_stream", "inline_preview.stopStream":
            handleInlinePreviewStopStream(payload: payload)

        // 导航操作
        case "navigate.to", "navigateTo":
            handleNavigateTo(payload: payload)

        // 编辑器操作
        case "editor.openFile", "editor.open_file":
            handleEditorOpenFile(payload: payload)

        // 通用按钮点击（通过 plugin + view id）
        case "button.click", "buttonClick":
            handleButtonClick(payload: payload)

        // 项目持久化自测
        case "project.select", "projectSelect":
            handleProjectSelect(payload: payload)
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
    private func handleInlinePreviewStartStream(payload: [String: Any]?) {
        Self.logger.info("🤖 Handling inline_preview.startStream")

        ensureEditorPanelActive()
        ensureInlinePreviewBottomTabActive()
        InlinePreviewAutomationState.shared.sessionAction = .start
        alert_info("自动化测试：启动预览流")
    }

    /// 处理 Inline Preview 停止流
    private func handleInlinePreviewStopStream(payload: [String: Any]?) {
        Self.logger.info("🤖 Handling inline_preview.stopStream")

        ensureEditorPanelActive()
        ensureInlinePreviewBottomTabActive()
        InlinePreviewAutomationState.shared.sessionAction = .stop
        alert_info("自动化测试：停止预览流")
    }

    /// 处理导航到指定面板
    private func handleNavigateTo(payload: [String: Any]?) {
        guard let panel = payload?["panel"] as? String else {
            Self.logger.warning("🤖 navigate.to: missing 'panel' in payload")
            return
        }

        Self.logger.info("🤖 Navigating to panel: \(panel, privacy: .public)")

        switch panel {
        case "editor", "code", "codeEditor":
            ensureEditorPanelActive()
            alert_info("自动化测试：切换到编辑器面板")
        case "chat", "agent":
            ensureAgentPanelActive()
            alert_info("自动化测试：切换到 Agent 面板")
        default:
            Self.logger.warning("🤖 Unknown panel: \(panel, privacy: .public)")
        }
    }

    /// 处理编辑器打开文件
    private func handleEditorOpenFile(payload: [String: Any]?) {
        guard let path = payload?["path"] as? String else {
            Self.logger.warning("🤖 editor.openFile: missing 'path' in payload")
            return
        }

        let url = URL(fileURLWithPath: path)
        Self.logger.info("🤖 Opening file: \(url.path, privacy: .public)")

        ensureEditorPanelActive()

        // 直接通过 EditorService 打开文件，触发完整流程：
        // 1. EditorService.open(at:) → 创建/激活 session + 加载内容
        // 2. EditorPreviewDetailView.onChange(of: currentFileURL) → setActiveFile
        // 3. EditorPreviewViewModel.autoBuildIfPossible → 扫描 #Preview + 自动编译
        let editorService = RootContainer.shared.editorVM.service
        editorService.open(at: url)

        Self.logger.info("🤖 File opened: \(url.lastPathComponent, privacy: .public)")
        alert_info("自动化测试：打开文件 \(url.lastPathComponent)")
    }

    /// 模拟用户选择当前窗口项目并触发持久化
    private func handleProjectSelect(payload: [String: Any]?) {
        guard let path = payload?["path"] as? String, !path.isEmpty else {
            Self.logger.warning("🤖 project.select: missing 'path' in payload")
            return
        }

        guard let scope = RootContainer.shared.windowManagerVM.activeWindowContainer else {
            Self.logger.warning("🤖 project.select: no active window scope")
            return
        }

        let name = URL(fileURLWithPath: path).lastPathComponent
        scope.projectVM.switchProject(
            to: Project(name: name, path: path, lastUsed: Date()),
            reason: "automationSelectProject"
        )
        NotificationCenter.default.post(name: .windowStateShouldPersist, object: nil)
        NotificationCenter.postCurrentProjectDidChange(name: name, path: path)

        Self.logger.info("🤖 project.select: \(path, privacy: .public)")
        alert_info("自动化测试：选择项目 \(name)")
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
        themeVM.selectTheme(themeId)

        Self.logger.info("🤖 Theme switched to: \(themeId, privacy: .public)")
        alert_info("自动化测试：切换主题到 \(themeId)")
    }

    /// 处理通用按钮点击
    private func handleButtonClick(payload: [String: Any]?) {
        guard let buttonId = payload?["buttonId"] as? String else {
            Self.logger.warning("🤖 button.click: missing 'buttonId' in payload")
            return
        }

        Self.logger.info("🤖 Button click: \(buttonId, privacy: .public)")
        alert_info("自动化测试：点击按钮 \(buttonId)")
    }

    // MARK: - Helpers

    /// 确保编辑器面板处于活动状态
    private func ensureEditorPanelActive() {
        RootContainer.shared.windowManagerVM.activeWindowContainer?.layoutVM.activeViewContainerIcon = "chevron.left.forwardslash.chevron.right"
        Self.logger.info("🤖 Activated editor panel")
    }

    /// 确保底部面板的 Inline Preview tab 被激活
    private func ensureInlinePreviewBottomTabActive() {
        NotificationCenter.default.post(
            name: .automationActivateBottomTab,
            object: nil,
            userInfo: ["tabId": "editor-bottom-inline-preview"]
        )
        Self.logger.info("🤖 Activated inline preview bottom tab")
    }

    /// 确保 Agent 面板处于活动状态
    private func ensureAgentPanelActive() {
        // Agent 面板通常是默认面板
        RootContainer.shared.windowManagerVM.activeWindowContainer?.layoutVM.activeViewContainerIcon = nil
    }
}

// MARK: - InlinePreviewAutomationState

/// 自动化测试专用的共享状态
///
/// 供 `AutomationController` 写入操作结果，供 `EditorPreviewDetailView` 读取并响应。
/// 这样即使 View 层在 AutomationController 之后才渲染，也能获取到之前的操作结果。
@MainActor
final class InlinePreviewAutomationState: ObservableObject {
    static let shared = InlinePreviewAutomationState()

    /// Session 操作指令（start / stop）
    @Published var sessionAction: SessionAction?

    /// 待打开的文件 URL
    @Published var pendingFileURL: URL?

    private init() {}

    enum SessionAction {
        case start
        case stop
    }
}
