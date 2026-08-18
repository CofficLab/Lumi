import os
import Foundation
import KernelCore
import SuperLogKit
import ProviderAgentLoop
import ProviderChatSection
import ProviderMessage
import ProviderProject
import SwiftUI

/// 技能插件：扫描 `.agent/skills/` 目录并把技能列表注入 LLM system prompt。
///
/// 复刻自旧版 `Plugins/SkillPlugin`：
/// - 向 AgentLoop 注册消息准备钩子（willSendToLLM）：把项目可用技能列表
///   作为瞬态 system 消息注入（不落库，仅本次请求生效）；
/// - 在 Chat 工具栏注册技能入口（无项目 / 无技能时自动隐藏）。
@MainActor
public final class SkillPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.skill", category: "Skill")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.skill"
    public let order = 51

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Skills",
            description: "Manage skills in .agent/skills directory",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ProjectProviding from kernel")
            return
        }

        // willSendToLLM 钩子：注入项目技能列表。
        if let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) {
            let service = SkillService.shared
            agentLoop.addMessagePreparer { [weak project] messages in
                guard let project else { return messages }
                return await SkillMessagePreparer(project: project, service: service).prepare(messages)
            }
        }

        // Chat 工具栏技能入口。
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            chat.addBarItems([
                ChatSectionBarItem(
                    id: "\(id).toolbar",
                    order: 51,
                    placement: .toolbarTrailing
                ) {
                    SkillChatToolbarView(project: project, service: SkillService.shared)
                },
            ])
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
    }
}

/// 技能消息准备器：把项目技能列表注入为瞬态 system 消息。
@MainActor
struct SkillMessagePreparer {
    let project: any ProjectProviding
    let service: SkillService

    func prepare(_ messages: [Message]) async -> [Message] {
        guard let projectPath = project.currentProject?.path,
              !projectPath.isEmpty,
              let conversationID = messages.last?.conversationID else {
            return messages
        }
        let skills = await service.listSkills(projectPath: projectPath)
        guard !skills.isEmpty else { return messages }

        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)
        let skillMessage = Message(
            conversationID: conversationID,
            role: .system,
            content: prompt
        )
        return [skillMessage] + messages
    }
}

/// Chat 工具栏技能入口：显示当前项目可用技能数量，点击弹出列表。
struct SkillChatToolbarView: View {
    let project: any ProjectProviding
    let service: SkillService

    @State private var isPopoverPresented = false
    @State private var skills: [SkillMetadata] = []

    var body: some View {
        Group {
            if let projectPath = project.currentProject?.path, !projectPath.isEmpty {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .medium))
                        if !skills.isEmpty {
                            Text("\(skills.count)")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(skills.isEmpty ? "无可用技能" : "\(skills.count) 个可用技能")
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Skills")
                            .font(.system(size: 12, weight: .semibold))
                        if skills.isEmpty {
                            Text("当前项目没有配置技能（.agent/skills/）")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(skills, id: \.id) { skill in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 11))
                                                .foregroundColor(.accentColor)
                                                .frame(width: 16)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(skill.title)
                                                    .font(.system(size: 11, weight: .medium))
                                                Text(skill.description)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    }
                                }
                            }
                            .frame(maxHeight: 240)
                        }
                    }
                    .padding(10)
                    .frame(width: 280)
                }
                .task {
                    if let path = project.currentProject?.path {
                        skills = await service.listSkills(projectPath: path)
                    }
                }
            }
        }
    }
}
