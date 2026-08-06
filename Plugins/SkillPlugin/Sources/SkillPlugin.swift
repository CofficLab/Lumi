import Foundation
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class SkillPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🎯"
    public nonisolated static let verbose = false
    nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "plugin.skill")

    public let id = "com.coffic.lumi.plugin.skill"
    public var name: String {
        LumiPluginLocalization.string("Skills", bundle: .module)
    }
    public let order = 51
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .general
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = "Manage skills in .agent/skills directory."

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    // MARK: - Status Bar

    /// 当前活跃的 View Container 支持项目时，状态栏才显示 Skills 按钮；
    /// 否则返回空数组，从源头避免出现"无项目可操作"的按钮。
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        guard kernel.workspace?.currentViewContainer?.supportsProject == true else {
            return []
        }
        return [
            StatusBarItem(
                id: id,
                title: name,
                systemImage: "sparkles",
                placement: .trailing,
                order: order,
                statusBarView: {
                    SkillStatusBarView(
                        projectPath: kernel.project?.currentProject?.path ?? ""
                    )
                }
            ),
        ]
    }

    // MARK: - LLM Prompt Injection

    public func willSendToLLM(kernel: LumiKernel, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        let projectPath = kernel.project?.currentProject?.path ?? ""
        guard !projectPath.isEmpty else { return messages }

        let skills = await SkillService.shared.listSkills(projectPath: projectPath)
        guard !skills.isEmpty else { return messages }

        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        // 注入为 system 消息(由 AgentTurnRunner 合并进顶层 system 前缀):
        // - skill 列表是项目级稳定配置(会话内不变),放 system 前缀可被 DeepSeek 缓存持续命中;
        // - 曾改为合并进「最后一条 user 消息」→ 该消息下一轮在历史中变回原文,
        //   从历史第一条起前缀失配 → 缓存近乎全 miss(实测命中率仅 ~35%)。
        // - system role 消息不进入 messages[](被 partition 提取),不会破坏 tool_use/tool_result 配对。
        guard let conversationID = messages.last?.conversationID else { return messages }
        let skillMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: prompt
        )
        return [skillMessage] + messages
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Skills", bundle: .module),
                systemImage: "sparkles",
                order: order
            ) {
                SkillSettingsView(projectProvider: kernel.project)
            },
        ]
    }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
