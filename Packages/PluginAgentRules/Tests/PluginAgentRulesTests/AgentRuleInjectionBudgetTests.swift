import Foundation
import KitLLM
import ProviderAgentRules
import ProviderLifecycleHooks
import ProviderLLMContext
import Testing
@testable import PluginAgentRules

private struct HugeRuleContributor: AgentRuleContributing {
    var providerID: String { "test-contributor" }

    var allRules: [AgentRuleDefinition] {
        [
            AgentRuleDefinition(
                id: "huge-rule",
                title: "Huge Rule",
                description: "",
                content: String(repeating: "rule-body ", count: 30_000)
            )
        ]
    }
}

/// Regression coverage for issue #969: rules are injected after the context
/// budget has been applied, so the hook itself must respect the remaining
/// input budget instead of pushing the request past the model window.
@MainActor
@Suite("Agent Rules 注入预算")
struct AgentRuleInjectionBudgetTests {

    @Test("钩子注入的规则不会超出剩余输入预算")
    func hookHonorsInjectedContentBudget() async throws {
        let provider = DefaultAgentRuleProvider()
        provider.addProvider(HugeRuleContributor())
        let hook = AgentRuleInjectionHook(project: nil, ruleProvider: provider)

        let budget = 600
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "hello")],
            conversationID: UUID(),
            injectedContentTokenBudget: budget
        )

        let result = await hook.apply(to: context)

        #expect(result.messages.count == 2)
        let injected = try #require(result.messages.first?.content)
        #expect(injected.contains("## Agent Rules"))
        #expect(injected.contains("rules truncated"))
        #expect(LLMContextTokenEstimator.estimate(text: injected) <= budget)
    }
}
