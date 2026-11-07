import Foundation
import KitAgentTool
import ProviderConversation
import ProviderProject
import Testing
@testable import PluginConversationList

@Test @MainActor func emptyConversationListReturnsHelpfulStatus() async throws {
    let tool = GetRecentConversationsTool(
        capability: ConversationListQueryCapabilityAdapter(conversations: DefaultConversationManager(), project: nil)
    )

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
    let tool = GetRecentConversationsTool(capability: ConversationListQueryCapabilityAdapter(conversations: conversations, project: project))

    let result = try await tool.execute(arguments: [:])

    #expect(result.contains("showing 2 of 2 total"))
    #expect(result.contains(currentID.uuidString))
    #expect(result.contains("Road \\| map next"))
    #expect(result.contains("Current (current)"))
    #expect(result.contains("Other"))
}

@Test @MainActor func recentConversationTableEscapesProjectNamesAndKeepsFiveColumns() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/Road|Map")
    let pipedID = try conversations.createConversation(
        title: "Piped project",
        projectPath: "/workspace/Road|Map",
        providerID: nil,
        modelName: nil
    )
    _ = try conversations.createConversation(
        title: "Multiline project",
        projectPath: "/workspace/Line\nBreak",
        providerID: nil,
        modelName: nil
    )
    let tool = GetRecentConversationsTool(capability: ConversationListQueryCapabilityAdapter(conversations: conversations, project: project))

    let result = try await tool.execute(arguments: [:])

    #expect(result.contains(pipedID.uuidString))
    #expect(result.contains("Road\\|Map (current)"))
    #expect(!result.contains("Road|Map"))
    #expect(result.contains("Line Break"))
    #expect(!result.contains("Line\nBreak"))

    // 表头 + 2 条数据行；项目名里的换行若不转义会额外拆出行。
    let tableRows = result.split(separator: "\n").filter { $0.hasPrefix("| ") }
    #expect(tableRows.count == 3)
    for row in tableRows {
        let unescapedPipeCount = row
            .replacingOccurrences(of: "\\|", with: "")
            .filter { $0 == "|" }
            .count
        #expect(unescapedPipeCount == 6)
    }
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
    let tool = GetRecentConversationsTool(capability: ConversationListQueryCapabilityAdapter(conversations: conversations, project: nil))

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

@Test @MainActor func recentConversationToolMetadataSupportsBothLanguages() {
    let tool = GetRecentConversationsTool(capability: ConversationListQueryCapabilityAdapter(conversations: nil, project: nil))

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
