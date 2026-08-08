import SwiftUI
import LumiKernel
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

    public init() {}

    /// 获取共享的 GoalStateManager
    public nonisolated static func currentManager() -> GoalStateManager? {
        _sharedManager
    }

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
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

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            CreateGoalTool(),
            AddTasksToGoalTool(),
            GetGoalProgressTool(),
            UpdateGoalStatusTool(),
            UpdateTaskStatusTool(),
        ]
    }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        [
            ChatSectionItem(
                id: "\(id).active-goal",
                placement: .stack,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                SidebarView(
                    conversationIdProvider: {
                        kernel.conversations?.selectedConversationID
                    },
                    backgroundColorProvider: {
                        Color(nsColor: .controlBackgroundColor)
                    }
                )
            }
        ]
    }

    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] {
        [
            ChatSectionToolbarItem(id: "\(id).toolbar-button", placement: .trailing) {
                GoalToolbarButton(kernel: kernel)
            }
        ]
    }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {
        await TurnFinishedHook.handle(
            lumiCore: kernel,
            conversationID: conversationID,
            reason: reason
        )
    }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
