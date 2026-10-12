import Foundation
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

    // MARK: - AgentRuleDefinition model

    @Test("规则定义使用默认版本号")
    func ruleDefinitionDefaultsVersion() {
        let rule = AgentRuleDefinition(id: "r1", title: "T", description: "D", content: "C")
        #expect(rule.version == "1.0.0")
    }

    @Test("规则定义标识就是其 id")
    func ruleDefinitionIdentity() {
        let rule = AgentRuleDefinition(id: "unique-id", title: "T", description: "", content: "")
        #expect(rule.id == "unique-id")
    }

    @Test("规则定义相等性比较所有字段")
    func ruleDefinitionEquality() {
        let a = AgentRuleDefinition(id: "id", title: "T", description: "D", content: "C", version: "1.0.0")
        let b = AgentRuleDefinition(id: "id", title: "T", description: "D", content: "C", version: "1.0.0")
        let c = AgentRuleDefinition(id: "id", title: "T", description: "D", content: "C", version: "2.0.0")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("规则定义可编码解码")
    func ruleDefinitionCodableRoundtrip() throws {
        let rule = AgentRuleDefinition(
            id: "codable", title: "Title", description: "Desc",
            content: "Body", version: "3.2.1"
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(AgentRuleDefinition.self, from: data)
        #expect(decoded == rule)
    }

    // MARK: - Registration lifecycle

    @Test("初始注册表为空")
    func startsEmpty() {
        let provider = DefaultAgentRuleProvider()
        #expect(provider.contributors.isEmpty)
        #expect(provider.allRules().isEmpty)
        #expect(provider.rulesGroupedByContributor().isEmpty)
    }

    @Test("重复添加相同 providerID 的贡献者不会重复登记")
    func addingSameProviderIDIsIdempotent() {
        let provider = DefaultAgentRuleProvider()
        provider.addProvider(TestContributor(providerID: "dup", allRules: []))
        provider.addProvider(TestContributor(providerID: "dup", allRules: []))
        #expect(provider.contributors.count == 1)
        #expect(provider.isProviderRegistered(providerID: "dup"))
    }

    @Test("isProviderRegistered 反映注册与撤回状态")
    func registrationStatusQueries() {
        let provider = DefaultAgentRuleProvider()
        #expect(!provider.isProviderRegistered(providerID: "missing"))
        provider.addProvider(TestContributor(providerID: "p", allRules: []))
        #expect(provider.isProviderRegistered(providerID: "p"))
        provider.removeProvider(providerID: "p")
        #expect(!provider.isProviderRegistered(providerID: "p"))
    }

    @Test("移除中间贡献者不影响其余贡献者顺序")
    func removingMiddleContributorPreservesOrder() {
        let provider = DefaultAgentRuleProvider()
        provider.addProvider(TestContributor(providerID: "a", allRules: [.init(id: "ra", title: "", description: "", content: "")]))
        provider.addProvider(TestContributor(providerID: "b", allRules: [.init(id: "rb", title: "", description: "", content: "")]))
        provider.addProvider(TestContributor(providerID: "c", allRules: [.init(id: "rc", title: "", description: "", content: "")]))

        provider.removeProvider(providerID: "b")

        #expect(provider.contributors.map(\.providerID) == ["a", "c"])
        #expect(provider.allRules().map(\.id) == ["ra", "rc"])
    }

    // MARK: - Rule filtering & grouping

    @Test("空 id 或纯空白 id 的规则被跳过")
    func rulesWithEmptyIDsAreSkipped() {
        let provider = DefaultAgentRuleProvider()
        provider.addProvider(TestContributor(providerID: "p", allRules: [
            .init(id: "", title: "", description: "", content: "empty"),
            .init(id: "   ", title: "", description: "", content: "whitespace"),
            .init(id: "real", title: "", description: "", content: "real"),
        ]))
        #expect(provider.allRules().map(\.id) == ["real"])
    }

    @Test("没有有效规则的贡献者不出现在分组结果中")
    func groupingOmitsContributorsWithoutValidRules() {
        let provider = DefaultAgentRuleProvider()
        provider.addProvider(TestContributor(providerID: "empty", allRules: []))
        provider.addProvider(TestContributor(providerID: "blank", allRules: [
            .init(id: "  ", title: "", description: "", content: ""),
        ]))
        provider.addProvider(TestContributor(providerID: "valid", allRules: [
            .init(id: "ok", title: "", description: "", content: ""),
        ]))

        let groups = provider.rulesGroupedByContributor()
        #expect(groups.map(\.providerID) == ["valid"])
        #expect(groups.first?.rules.map(\.id) == ["ok"])
    }

    @Test("分组结果保留贡献者注册顺序")
    func groupingPreservesRegistrationOrder() {
        let provider = DefaultAgentRuleProvider()
        provider.addProvider(TestContributor(providerID: "second", allRules: [.init(id: "s", title: "", description: "", content: "")]))
        provider.addProvider(TestContributor(providerID: "first", allRules: [.init(id: "f", title: "", description: "", content: "")]))
        #expect(provider.rulesGroupedByContributor().map(\.providerID) == ["second", "first"])
    }

    // MARK: - Observer notifications

    @Test("注册与撤回贡献者时通知观察者")
    func addRemoveNotifiesObservers() {
        let provider = DefaultAgentRuleProvider()
        var events: [AgentRuleProvidingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.addProvider(TestContributor(providerID: "a", allRules: []))
        provider.addProvider(TestContributor(providerID: "b", allRules: []))
        provider.removeProvider(providerID: "a")

        #expect(events.count == 3)
    }

    @Test("重复添加或撤回不存在的贡献者不通知")
    func noNotificationWhenStateUnchanged() {
        let provider = DefaultAgentRuleProvider()
        var count = 0
        let handle = provider.addObserver { _ in count += 1 }
        defer { handle.cancel() }

        provider.addProvider(TestContributor(providerID: "a", allRules: []))
        provider.addProvider(TestContributor(providerID: "a", allRules: [])) // duplicate
        provider.removeProvider(providerID: "missing")

        #expect(count == 1)
    }

    @Test("取消观察后不再收到事件")
    func cancelledObserverStopsReceiving() {
        let provider = DefaultAgentRuleProvider()
        var count = 0
        let handle = provider.addObserver { _ in count += 1 }
        provider.addProvider(TestContributor(providerID: "first", allRules: []))
        handle.cancel()
        handle.cancel() // idempotent
        provider.addProvider(TestContributor(providerID: "second", allRules: []))
        provider.removeProvider(providerID: "first")

        #expect(count == 1)
    }
}
