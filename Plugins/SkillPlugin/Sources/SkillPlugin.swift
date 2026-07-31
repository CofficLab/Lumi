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
    public let name = "Skills"
    public let order = 51
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    // MARK: - Status Bar

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        [
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

        // 找到最后一条 user 消息的位置，在其后插入 skill 上下文
        guard let conversationID = messages.last?.conversationID else { return messages }
        let skillMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: prompt
        )

        var result = messages
        if let lastUserIndex = result.lastIndex(where: { $0.role == .user }) {
            result.insert(skillMessage, at: lastUserIndex + 1)
        } else {
            result.append(skillMessage)
        }
        return result
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
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
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
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
