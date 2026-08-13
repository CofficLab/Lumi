import SwiftUI
import KernelLumi
import LumiUI
import SuperLogKit
import os

/// GoalTaskPlugin 类型别名，便于工具和视图引用
public typealias GoalTaskPlugin = Plugin

@MainActor
public final class Plugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🎯"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.goal-task"
    )

    public let id = "com.coffic.lumi.plugin.goal-task"
    public var name: String {
        LumiPluginLocalization.string("GoalTask", bundle: .module)
    }
    public let order = 91
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = LumiPluginLocalization.string("Goal and task management for multi-step objectives.", bundle: .module)

    /// 共享的 GoalStateManager 实例
    private nonisolated(unsafe) static var _sharedManager: GoalStateManager?

    /// Goal 视图模型,由 Plugin 在初始化时创建并持有。
    /// 作为工具栏弹窗与侧栏的单一数据源,跨 view 重建保留订阅/加载状态;
    /// 通过 `GoalVM.managerProvider` 注入数据源,默认仍走全局单例。
    private let goalVM: GoalVM

    public init() {
        self.goalVM = GoalVM()
    }

    /// 获取共享的 GoalStateManager
    public nonisolated static func currentManager() -> GoalStateManager? {
        _sharedManager
    }

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        // 设置 GoalStateManager
        guard let storage = kernel.storage else {
            Self.logger.error("🎯 Storage service not available")
            return
        }

        let pluginDataDir = storage.pluginDataDirectory(for: "GoalTaskPlugin")
        do {
            Self._sharedManager = try GoalStateManager(databaseRootURL: pluginDataDir)
            if Self.verbose {
                Self.logger.info("🎯 GoalTask 插件初始化完成")
            }
        } catch {
            Self.logger.error("🎯 GoalStateManager 初始化失败: \(error.localizedDescription)")
        }
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            CreateGoalTool(),
            AddTasksToGoalTool(),
            GetGoalProgressTool(),
            UpdateGoalStatusTool(),
            UpdateTaskStatusTool(),
        ]
    }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] {
        [
            ChatSectionItem(
                id: "\(id).active-goal",
                placement: .stack,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                SidebarView(viewModel: self.goalVM)
            }
        ]
    }

    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] {
        [
            ChatSectionToolbarItem(id: "\(id).toolbar-button", placement: .trailing) {
                GoalToolbarButton(viewModel: self.goalVM)
            }
        ]
    }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {
        await TurnFinishedHook.handle(
            lumiCore: kernel,
            conversationID: conversationID,
            reason: reason
        )
    }
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
