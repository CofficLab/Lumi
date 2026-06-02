import Testing
import Foundation
import AgentToolKit
@testable import PluginAgentRules

@Test func packageLoads() async throws {
    #expect(AgentRulesPlugin.id == "AgentRules")
}

@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appending(path: "AgentRules.plist")
    let corruptURL = directory.appending(path: "AgentRules.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = AgentRulesPluginLocalStore(settingsDirectory: directory)

    #expect(store.string(forKey: "rulesDirectoryPath") == nil)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.set("/tmp/.agent/rules", forKey: "rulesDirectoryPath") == true)

    let reloadedStore = AgentRulesPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.string(forKey: "rulesDirectoryPath") == "/tmp/.agent/rules")
}

@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appending(path: "settings")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = AgentRulesPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set("/tmp/.agent/rules", forKey: "rulesDirectoryPath") == false)
    #expect(store.string(forKey: "rulesDirectoryPath") == nil)
}

@Test func listRulesReadsUTF16MarkdownMetadata() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let rulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let ruleURL = rulesURL.appending(path: "style.md")
    try """
    # Coding Style

    Prefer clear names.
    """.write(to: ruleURL, atomically: true, encoding: .utf16)

    let rules = try await AgentRulesService.shared.listRules(projectPath: projectURL.path())
    let rule = try #require(rules.first)

    #expect(rule.filename == "style.md")
    #expect(rule.title == "Coding Style")
    #expect(rule.description == "Prefer clear names.")
}

@Test func listAgentRulesToolClampsNonPositiveLimits() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesToolTests-\(UUID().uuidString)", isDirectory: true)
    let rulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try "# One\n\nFirst rule.".write(to: rulesURL.appending(path: "one.md"), atomically: true, encoding: .utf8)
    try "# Two\n\nSecond rule.".write(to: rulesURL.appending(path: "two.md"), atomically: true, encoding: .utf8)

    let tool = ListAgentRulesTool()
    let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: tool.name)

    let zeroLimitResult = try await tool.execute(
        arguments: [
            "project_path": ToolArgument(projectURL.path()),
            "limit": ToolArgument(0)
        ],
        context: context
    )
    let negativeLimitResult = try await tool.execute(
        arguments: [
            "project_path": ToolArgument(projectURL.path()),
            "limit": ToolArgument(-2)
        ],
        context: context
    )

    #expect(try decodedRuleCount(from: zeroLimitResult) == 0)
    #expect(try decodedRuleCount(from: negativeLimitResult) == 0)
}

@Test func listAgentRulesToolSchemaDeclaresLimitBounds() throws {
    let schema = ListAgentRulesTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])
    let limit = try #require(properties["limit"])

    #expect(limit["type"] as? String == "integer")
    #expect(limit["minimum"] as? Int == ListAgentRulesTool.minLimit)
    #expect(limit["maximum"] as? Int == ListAgentRulesTool.maxLimit)
}

@Test func listAgentRulesToolClampsOversizedLimits() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesToolTests-\(UUID().uuidString)", isDirectory: true)
    let rulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    for index in 1...105 {
        try "# Rule \(index)\n\nGenerated rule.".write(
            to: rulesURL.appending(path: "rule-\(index).md"),
            atomically: true,
            encoding: .utf8
        )
    }

    let tool = ListAgentRulesTool()
    let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_2", toolName: tool.name)
    let result = try await tool.execute(
        arguments: [
            "project_path": ToolArgument(projectURL.path()),
            "limit": ToolArgument(9_999)
        ],
        context: context
    )

    #expect(try decodedRuleCount(from: result) == ListAgentRulesTool.maxLimit)
}

@Test func readRuleReturnsUTF16MarkdownContent() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let rulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let content = """
    # Review Rules

    Check edge cases before shipping.
    """
    try content.write(to: rulesURL.appending(path: "review.md"), atomically: true, encoding: .utf16)

    let rule = try await AgentRulesService.shared.readRule(projectPath: projectURL.path(), filename: "review.md")

    #expect(rule.title == "Review Rules")
    #expect(rule.description == "Check edge cases before shipping.")
    #expect(rule.content == content)
}

private func decodedRuleCount(from json: String) throws -> Int {
    let data = try #require(json.data(using: .utf8))
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return try #require(object?["count"] as? Int)
}
