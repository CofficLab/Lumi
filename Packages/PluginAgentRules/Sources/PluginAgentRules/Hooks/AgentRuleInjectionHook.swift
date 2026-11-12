import KitLLM
import ProviderAgentRules
import ProviderConversation
import ProviderLifecycleHooks

/// 在 LLM 请求前注入项目规则和已启用插件贡献的规则。
///
/// 项目规则按「请求所属会话」绑定的项目解析，而不是 UI 全局当前项目：
/// 并发切换会话时全局 `currentProject` 会被改写，读它会把别的项目的规则
/// 注入本会话提示词（与工具侧 #619 同根，只是发生在注入钩子）。
@MainActor
final class AgentRuleInjectionHook {
    private let conversations: (any ConversationManaging)?
    private weak var ruleProvider: (any AgentRuleProviding)?

    init(
        conversations: (any ConversationManaging)?,
        ruleProvider: (any AgentRuleProviding)?
    ) {
        self.conversations = conversations
        self.ruleProvider = ruleProvider
    }

    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        let projectPath = await conversations?.fetchConversation(id: context.conversationID)?.projectPath?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let projectRules = await AgentRulesService.shared.loadRuleDefinitions(projectPath: projectPath)
        let contributedRules = ruleProvider?.allRules() ?? []
        guard let prompt = AgentRulePromptBuilder.buildPrompt(
            projectRules: projectRules,
            contributedRules: contributedRules,
            maxTokens: context.injectedContentTokenBudget
        ) else {
            return context
        }

        var result = context
        result.messages = [LLMMessage(role: .system, content: prompt)] + context.messages
        return result
    }
}