import Testing
@testable import ProviderAgentRules

private struct TestContributor: AgentRuleContributing {
    let providerID: String
    let allRules: [AgentRuleDefinition]
}

@MainActor
struct ProviderAgentRulesTests {
    @Test("注册表按贡献顺序聚合并按 ID 去重")
    func aggregatesRulesAndDeduplicates() {
        let provider = DefaultAgentRuleProvider()
        let shared = AgentRuleDefinition(id: "shared", title: "Shared", description: "", content: "shared")
        let first = AgentRuleDefinition(id: "first", title: "First", description: "", content: "first")
        let second = AgentRuleDefinition(id: "second", title: "Second", description: "", content: "second")

        provider.addProvider(TestContributor(providerID: "plugin.a", allRules: [shared, first]))
        provider.addProvider(TestContributor(providerID: "plugin.b", allRules: [shared, second]))

        #expect(provider.allRules().map(\.id) == ["shared", "first", "second"])
        #expect(provider.rulesGroupedByContributor().count == 2)
    }

    @Test("撤回贡献者是幂等的")
    func removesContributorIdempotently() {
        let provider = DefaultAgentRuleProvider()
        provider.addProvider(TestContributor(providerID: "plugin.a", allRules: []))
        provider.removeProvider(providerID: "plugin.a")
        provider.removeProvider(providerID: "plugin.a")

        #expect(provider.contributors.isEmpty)
    }
}
