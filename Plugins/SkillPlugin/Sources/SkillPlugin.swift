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

        // 仅当末尾已是 user 消息时才合并注入(与记忆注入同一策略):
        // 1) 保持 system 前缀逐轮稳定,最大化 DeepSeek 缓存命中率
        //    (硬盘缓存要求「从第 1 个 token 起」完整匹配前缀单元);
        // 2) 工具调用中间轮次(末尾是 assistant(tool_use) / tool 消息)跳过,
        //    避免在 tool_use 与 tool_result 之间插入 user 文本破坏协议配对。
        guard messages.last?.role == .user else { return messages }
        var result = messages
        let removed = result.removeLast()
        result.append(LumiChatMessage(
            id: removed.id,
            conversationID: removed.conversationID,
            role: removed.role,
            content: removed.content + "\n\n" + prompt,
            turnID: removed.turnID,
            createdAt: removed.createdAt,
            providerID: removed.providerID,
            modelName: removed.modelName,
            isError: removed.isError,
            rawErrorDetail: removed.rawErrorDetail,
            httpStatusCode: removed.httpStatusCode,
            httpBody: removed.httpBody,
            renderKind: removed.renderKind,
            preferredRendererID: removed.preferredRendererID,
            metadata: removed.metadata,
            toolCalls: removed.toolCalls,
            toolCallID: removed.toolCallID,
            reasoningContent: removed.reasoningContent,
            inputTokenCount: removed.inputTokenCount,
            outputTokenCount: removed.outputTokenCount,
            latencyMs: removed.latencyMs,
            timeToFirstTokenMs: removed.timeToFirstTokenMs,
            streamingDurationMs: removed.streamingDurationMs
        ))
        return result
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
