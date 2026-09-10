import Foundation
import KitLLM
import ProviderLifecycleHooks
import ProviderProject
import ProviderSkill

/// `willSendToLLM` 钩子：注入可用技能列表（插件贡献 + 内置 + 项目）。
///
/// 无当前项目时也注入，保证通用技能始终可用。
@MainActor
final class SkillInjectionHook {
    private weak var project: (any ProjectProviding)?
    private weak var skillProvider: (any SkillProviding)?
    private let skillService: SkillService

    init(
        project: (any ProjectProviding)?,
        skillProvider: (any SkillProviding)?,
        skillService: SkillService = .shared
    ) {
        self.project = project
        self.skillProvider = skillProvider
        self.skillService = skillService
    }

    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        let projectPath = project?.currentProject?.path ?? ""
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
