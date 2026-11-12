import Foundation
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import ProviderSkill

/// `willSendToLLM` 钩子：注入可用技能列表（插件贡献 + 内置 + 项目）。
///
/// 项目技能按「请求所属会话」绑定的项目解析，而不是 UI 全局当前项目：
/// 并发切换会话时全局 `currentProject` 会被改写，读它会把别的项目的技能
/// 注入本会话提示词。无绑定项目时仍注入通用底座技能。
@MainActor
final class SkillInjectionHook {
    private let conversations: (any ConversationManaging)?
    private weak var skillProvider: (any SkillProviding)?
    private let skillService: SkillService

    init(
        conversations: (any ConversationManaging)?,
        skillProvider: (any SkillProviding)?,
        skillService: SkillService = .shared
    ) {
        self.conversations = conversations
        self.skillProvider = skillProvider
        self.skillService = skillService
    }

    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        let projectPath = await conversations?.fetchConversation(id: context.conversationID)?.projectPath?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // 底座 = 插件贡献 + 内置（由 SkillProviding 聚合）。
        let baseSkills = skillProvider?.allSkills() ?? []
        let skills = await skillService.listSkills(projectPath: projectPath, baseSkills: baseSkills)
        guard !skills.isEmpty else { return context }
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)
        var ctx = context
        ctx.messages = [LLMMessage(role: .system, content: prompt)] + ctx.messages
        return ctx
    }
}