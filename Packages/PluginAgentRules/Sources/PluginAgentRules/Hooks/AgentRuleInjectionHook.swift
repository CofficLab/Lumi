import KitLLM
import ProviderAgentRules
import ProviderLifecycleHooks
import ProviderProject

/// 在 LLM 请求前注入项目规则和已启用插件贡献的规则。
@MainActor
final class AgentRuleInjectionHook {
    private weak var project: (any ProjectProviding)?
    private weak var ruleProvider: (any AgentRuleProviding)?

    init(
        project: (any ProjectProviding)?,
        ruleProvider: (any AgentRuleProviding)?
    ) {
        self.project = project
        self.ruleProvider = ruleProvider
    }

    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        let projectPath = project?.currentProject?.path ?? ""
        let projectRules = await AgentRulesService.shared.loadRuleDefinitions(projectPath: projectPath)
        let contributedRules = ruleProvider?.allRules() ?? []
        guard let prompt = AgentRulePromptBuilder.buildPrompt(
            projectRules: projectRules,
            contributedRules: contributedRules
        ) else {
            return context
        }

        var result = context
        result.messages = [LLMMessage(role: .system, content: prompt)] + context.messages
        return result
    }
}
