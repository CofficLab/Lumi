import Testing
import Foundation
@testable import AgentRulesPlugin

@MainActor
    @Test func packageLoads() async throws {
    #expect(AgentRulesPlugin().id == "com.coffic.lumi.plugin.agent-rules")
}

@MainActor
    @Test func pluginHasRequiredMetadata() throws {
    let plugin = AgentRulesPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.agent-rules")
    #expect(plugin.name == "Agent Rules")
    #expect(plugin.order == 50)
    #expect(plugin.policy == .disabled)
    #expect(plugin.category == .general)
    #expect(plugin.stage == .stable)
}

@MainActor
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

@MainActor
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

@MainActor
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
}

@MainActor
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
    #expect(rule.content == content)
}
