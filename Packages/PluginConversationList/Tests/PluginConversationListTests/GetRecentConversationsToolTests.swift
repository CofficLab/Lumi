import Foundation
import KitAgentTool
import ProviderConversation
import ProviderProject
import Testing
@testable import PluginConversationList

@Test @MainActor func emptyConversationListReturnsHelpfulStatus() async throws {
    let tool = GetRecentConversationsTool(conversations: DefaultConversationManager(), project: nil)

    let result = try await tool.execute(arguments: [:])

    #expect(result.contains("No conversations found"))
    #expect(result.contains("Start a new conversation"))
}

@Test @MainActor func recentConversationTableEscapesTitlesAndMarksCurrentProject() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/Current")
    let currentID = try conversations.createConversation(
        title: "Road | map\nnext",
        projectPath: "/workspace/Current",
        providerID: nil,
        modelName: nil
    )
    _ = try conversations.createConversation(
        title: "Other",
        projectPath: "/workspace/Other",
        providerID: nil,
        modelName: nil
    )
    let tool = GetRecentConversationsTool(conversations: conversations, project: project)

    let result = try await tool.execute(arguments: [:])

    #expect(result.contains("showing 2 of 2 total"))
    #expect(result.contains(currentID.uuidString))
    #expect(result.contains("Road \\| map next"))
    #expect(result.contains("Current (current)"))
    #expect(result.contains("Other"))
}

@Test @MainActor func recentConversationLimitDefaultsAndClampsToOneThroughTwenty() async throws {
    let conversations = DefaultConversationManager()
    for index in 0..<22 {
        _ = try conversations.createConversation(
            title: "Conversation \(index)",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
    }
    let tool = GetRecentConversationsTool(conversations: conversations, project: nil)

    let defaultResult = try await tool.execute(arguments: [:])
    let lowerBoundResult = try await tool.execute(arguments: ["limit": ToolArgument(0)])
    let upperBoundResult = try await tool.execute(arguments: ["limit": ToolArgument(99)])

    #expect(defaultResult.contains("showing 5 of 22 total"))
    #expect(lowerBoundResult.contains("showing 1 of 22 total"))
    #expect(!lowerBoundResult.contains("| 2 |"))
    #expect(upperBoundResult.contains("showing 20 of 22 total"))
    #expect(upperBoundResult.contains("| 20 |"))
    #expect(!upperBoundResult.contains("| 21 |"))
}

@Test func recentConversationToolMetadataSupportsBothLanguages() {
    let tool = GetRecentConversationsTool(conversations: nil, project: nil)

    #expect(tool.name == "get_recent_conversations")
    #expect(tool.description(for: .chinese).contains("最近的对话列表"))
    #expect(tool.description(for: .english).contains("most recent conversations"))
    #expect(tool.displayDescription(for: [:]) == "获取最近的对话列表")
    #expect(tool.permissionRiskLevel(arguments: [:]) == .safe)

    for language in [LanguagePreference.chinese, .english] {
        let schema = tool.inputSchema(for: language)
        let properties = schema["properties"] as? [String: [String: Any]]
        let limit = properties?["limit"]
        #expect(schema["type"] as? String == "object")
        #expect(limit?["minimum"] as? Int == 1)
        #expect(limit?["maximum"] as? Int == 20)
    }
}
