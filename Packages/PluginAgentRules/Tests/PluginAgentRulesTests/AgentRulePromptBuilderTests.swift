import ProviderAgentRules
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
}
