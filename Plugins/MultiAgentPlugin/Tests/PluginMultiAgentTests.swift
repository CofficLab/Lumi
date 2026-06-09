import Testing
@testable import MultiAgentPlugin

@Test func packageLoads() async throws {
    #expect(MultiAgentPlugin.info.id == "com.coffic.lumi.plugin.multi-agent")
    #expect(MultiAgentPlugin.info.displayName.isEmpty == false)
    #expect(MultiAgentPlugin.iconName == "person.3.fill")
    #expect(MultiAgentPlugin.info.order == 88)
}

@Test func collectAgentsToolNormalizesTimeout() throws {
    #expect(CollectAgentsTool.normalizedTimeout(nil) == 120)
    #expect(CollectAgentsTool.normalizedTimeout(-10) == 1)
    #expect(CollectAgentsTool.normalizedTimeout(0) == 1)
    #expect(CollectAgentsTool.normalizedTimeout(30) == 30)
    #expect(CollectAgentsTool.normalizedTimeout(30.0) == 30)
    #expect(CollectAgentsTool.normalizedTimeout("30") == 30)
    #expect(CollectAgentsTool.normalizedTimeout(10_000) == 3600)
    #expect(CollectAgentsTool.normalizedTimeout("not-a-number") == 120)

    let schema = CollectAgentsTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])
    #expect(properties["timeout"]?["minimum"] as? Int == 1)
    #expect(properties["timeout"]?["maximum"] as? Int == 3600)
}
