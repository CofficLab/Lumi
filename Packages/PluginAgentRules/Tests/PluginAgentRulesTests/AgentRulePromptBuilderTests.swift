import ProviderAgentRules
import ProviderLLMContext
import Testing
@testable import PluginAgentRules

struct AgentRulePromptBuilderTests {
    @Test("项目规则优先于同 ID 的插件规则")
    func projectRulesTakePrecedence() {
        let project = AgentRuleDefinition(
            id: "icon-workflow",
            title: "Project Icon Workflow",
            description: "",
            content: "project-content"
        )
        let plugin = AgentRuleDefinition(
            id: "icon-workflow",
            title: "Plugin Icon Workflow",
            description: "",
            content: "plugin-content"
        )

        let prompt = AgentRulePromptBuilder.buildPrompt(
            projectRules: [project],
            contributedRules: [plugin]
        )

        #expect(prompt?.contains("project-content") == true)
        #expect(prompt?.contains("plugin-content") == false)
    }

    @Test("没有规则时不生成空 system prompt")
    func emptyRulesProduceNoPrompt() {
        #expect(AgentRulePromptBuilder.buildPrompt(projectRules: [], contributedRules: []) == nil)
    }

    @Test("规则超过注入预算时被截断")
    func oversizedRulesAreTrimmedToBudget() throws {
        let huge = AgentRuleDefinition(
            id: "huge-rule",
            title: "Huge Rule",
            description: "",
            content: String(repeating: "klausula-", count: 20_000)
        )

        let prompt = AgentRulePromptBuilder.buildPrompt(
            projectRules: [huge],
            contributedRules: [],
            maxTokens: 500
        )

        let injected = try #require(prompt)
        #expect(injected.contains("## Agent Rules"))
        #expect(injected.contains("rules truncated"))
        #expect(injected.count < huge.content.count)
        #expect(LLMContextTokenEstimator.estimate(text: injected) <= 500)
    }

    @Test("规则在预算内时保持完整")
    func rulesWithinBudgetAreKeptIntact() throws {
        let rule = AgentRuleDefinition(
            id: "small-rule",
            title: "Small Rule",
            description: "",
            content: "always run the tests"
        )

        let prompt = AgentRulePromptBuilder.buildPrompt(
            projectRules: [rule],
            contributedRules: [],
            maxTokens: 1_000
        )

        let injected = try #require(prompt)
        #expect(injected.contains("always run the tests"))
        #expect(!injected.contains("rules truncated"))
    }
}
