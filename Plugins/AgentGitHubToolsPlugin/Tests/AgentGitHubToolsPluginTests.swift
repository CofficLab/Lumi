import Foundation
import Testing
import AgentToolKit
import GitHubKit
@testable import AgentGitHubToolsPlugin

@Test func packageLoads() async throws {
    #expect(GitHubToolsPlugin.info.id == "com.coffic.lumi.plugin.github-tools")
    #expect(GitHubToolsPlugin.info.displayName.isEmpty == false)
    #expect(GitHubToolsPlugin.info.description.isEmpty == false)
    #expect(GitHubToolsPlugin.iconName == "star.circle.fill")
    #expect(GitHubToolsPlugin.category == .development)
}

@Test func localStoreSavesAndReloadsToken() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitHubPluginLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = GitHubPluginLocalStore(settingsDirectory: directory)

    #expect(store.set("ghp_test", forKey: "GitHubToken") == true)

    let reloadedStore = GitHubPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.accessToken == "ghp_test")
}

@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitHubPluginLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = GitHubPluginLocalStore(settingsDirectory: directory)

    #expect(store.set("ghp_recovered", forKey: "GitHubToken") == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.accessToken == "ghp_recovered")

    let reloadedStore = GitHubPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.accessToken == "ghp_recovered")
}

@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitHubPluginLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = GitHubPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set("ghp_test", forKey: "GitHubToken") == false)
    #expect(store.accessToken == nil)
}

@Test func githubSearchToolClampsLimitToGitHubBounds() {
    #expect(GitHubSearchTool.normalizedLimit(nil) == 5)
    #expect(GitHubSearchTool.normalizedLimit(-1) == 1)
    #expect(GitHubSearchTool.normalizedLimit(0) == 1)
    #expect(GitHubSearchTool.normalizedLimit(12.0) == 12)
    #expect(GitHubSearchTool.normalizedLimit("20") == 20)
    #expect(GitHubSearchTool.normalizedLimit(25) == 25)
    #expect(GitHubSearchTool.normalizedLimit(500) == 100)
}

@Test func githubSearchToolSchemaDeclaresLimitBounds() throws {
    let schema = GitHubSearchTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])
    let limit = try #require(properties["limit"])
    let minStars = try #require(properties["minStars"])

    #expect(limit["type"] as? String == "integer")
    #expect(limit["minimum"] as? Int == GitHubSearchTool.minLimit)
    #expect(limit["maximum"] as? Int == GitHubSearchTool.maxLimit)
    #expect(minStars["type"] as? String == "integer")
    #expect(minStars["minimum"] as? Int == 0)
}

@Test func githubSearchToolFormatsAllReturnedItems() {
    let repos = (1...6).map { makeRepository(id: $0) }
    let result = GitHubSearchResult(totalCount: 6, incompleteResults: false, items: repos)
    let output = GitHubSearchTool.formatSearchResult(result)

    #expect(output.contains("1. **owner/repo-1**"))
    #expect(output.contains("6. **owner/repo-6**"))
}

@Test func githubTrendingToolNormalizesLimitAndSince() {
    #expect(GitHubTrendingTool.normalizedLimit(nil) == 10)
    #expect(GitHubTrendingTool.normalizedLimit(-10) == 1)
    #expect(GitHubTrendingTool.normalizedLimit(0) == 1)
    #expect(GitHubTrendingTool.normalizedLimit(8.0) == 8)
    #expect(GitHubTrendingTool.normalizedLimit("14") == 14)
    #expect(GitHubTrendingTool.normalizedLimit(12) == 12)
    #expect(GitHubTrendingTool.normalizedLimit(250) == 100)

    #expect(GitHubTrendingTool.normalizedSince(nil) == "daily")
    #expect(GitHubTrendingTool.normalizedSince(" weekly ") == "weekly")
    #expect(GitHubTrendingTool.normalizedSince("MONTHLY") == "monthly")
    #expect(GitHubTrendingTool.normalizedSince("yearly") == "daily")
}

@Test func githubTrendingToolSchemaDeclaresLimitBounds() throws {
    let schema = GitHubTrendingTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])
    let limit = try #require(properties["limit"])

    #expect(limit["type"] as? String == "integer")
    #expect(limit["minimum"] as? Int == GitHubTrendingTool.minLimit)
    #expect(limit["maximum"] as? Int == GitHubTrendingTool.maxLimit)
}

@Test func githubIssueListToolNormalizesPagination() throws {
    #expect(GitHubIssueListTool.normalizedPage(nil) == 1)
    #expect(GitHubIssueListTool.normalizedPage(-3) == 1)
    #expect(GitHubIssueListTool.normalizedPage(0) == 1)
    #expect(GitHubIssueListTool.normalizedPage(3.0) == 3)
    #expect(GitHubIssueListTool.normalizedPage("5") == 5)
    #expect(GitHubIssueListTool.normalizedPage(4) == 4)

    #expect(GitHubIssueListTool.normalizedPerPage(nil) == 10)
    #expect(GitHubIssueListTool.normalizedPerPage(-20) == 1)
    #expect(GitHubIssueListTool.normalizedPerPage(0) == 1)
    #expect(GitHubIssueListTool.normalizedPerPage(15.0) == 15)
    #expect(GitHubIssueListTool.normalizedPerPage("30") == 30)
    #expect(GitHubIssueListTool.normalizedPerPage(25) == 25)
    #expect(GitHubIssueListTool.normalizedPerPage(250) == 100)

    let schema = GitHubIssueListTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])
    #expect(properties["page"]?["minimum"] as? Int == 1)
    #expect(properties["perPage"]?["minimum"] as? Int == 1)
    #expect(properties["perPage"]?["maximum"] as? Int == 100)
}

@Test func githubIssueNumberNormalizerAcceptsJSONNumberShapes() {
    #expect(GitHubToolArgumentNormalizer.issueNumber(42) == 42)
    #expect(GitHubToolArgumentNormalizer.issueNumber(42.0) == 42)
    #expect(GitHubToolArgumentNormalizer.issueNumber("42") == 42)
    #expect(GitHubToolArgumentNormalizer.issueNumber(0) == nil)
    #expect(GitHubToolArgumentNormalizer.issueNumber(-1.0) == nil)
    #expect(GitHubToolArgumentNormalizer.issueNumber("not-a-number") == nil)

    #expect(GitHubToolArgumentNormalizer.nonNegativeInteger(nil) == 0)
    #expect(GitHubToolArgumentNormalizer.nonNegativeInteger(-1) == 0)
    #expect(GitHubToolArgumentNormalizer.nonNegativeInteger(12.0) == 12)
    #expect(GitHubToolArgumentNormalizer.nonNegativeInteger("14") == 14)
}

@Test func githubIssueToolSchemasDeclareIntegerIssueNumbers() throws {
    let tools: [any SuperAgentTool] = [
        GitHubAddIssueCommentTool(),
        GitHubCloseIssueTool(),
        GitHubIssueCommentsTool(),
        GitHubIssueDetailTool(),
        GitHubReopenIssueTool(),
        GitHubUpdateIssueTool()
    ]

    for tool in tools {
        let schema = tool.inputSchema(for: .english)
        let properties = try #require(schema["properties"] as? [String: [String: Any]])
        let issueNumber = try #require(properties["issueNumber"], "Missing issueNumber schema for \(tool.name)")

        #expect(issueNumber["type"] as? String == "integer")
        #expect(issueNumber["minimum"] as? Int == GitHubToolArgumentNormalizer.minIssueNumber)
    }
}

@Test func githubIssueMutationSchemasDeclareIntegerMilestones() throws {
    let tools: [any SuperAgentTool] = [
        GitHubCreateIssueTool(),
        GitHubUpdateIssueTool()
    ]

    for tool in tools {
        let schema = tool.inputSchema(for: .english)
        let properties = try #require(schema["properties"] as? [String: [String: Any]])
        let milestone = try #require(properties["milestone"], "Missing milestone schema for \(tool.name)")

        #expect(milestone["type"] as? String == "integer")
        #expect(milestone["minimum"] as? Int == 1)
    }
}

private func makeRepository(id: Int) -> GitHubRepository {
    let owner = GitHubUser(
        login: "owner",
        id: id,
        avatarUrl: "https://example.com/avatar.png",
        htmlUrl: "https://github.com/owner",
        type: "User"
    )

    return GitHubRepository(
        id: id,
        name: "repo-\(id)",
        fullName: "owner/repo-\(id)",
        description: "Repository \(id)",
        htmlUrl: "https://github.com/owner/repo-\(id)",
        language: "Swift",
        stargazersCount: id * 10,
        forksCount: id,
        openIssuesCount: nil,
        topics: nil,
        pushedAt: nil,
        archived: false,
        fork: false,
        owner: owner,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
        defaultBranch: "main",
        isPrivate: false
    )
}

@Test func githubIssueCommentsToolNormalizesPagination() throws {
    #expect(GitHubIssueCommentsTool.normalizedPage(nil) == 1)
    #expect(GitHubIssueCommentsTool.normalizedPage(-3) == 1)
    #expect(GitHubIssueCommentsTool.normalizedPage(0) == 1)
    #expect(GitHubIssueCommentsTool.normalizedPage(3.0) == 3)
    #expect(GitHubIssueCommentsTool.normalizedPage("5") == 5)
    #expect(GitHubIssueCommentsTool.normalizedPage(4) == 4)

    #expect(GitHubIssueCommentsTool.normalizedPerPage(nil) == 10)
    #expect(GitHubIssueCommentsTool.normalizedPerPage(-20) == 1)
    #expect(GitHubIssueCommentsTool.normalizedPerPage(0) == 1)
    #expect(GitHubIssueCommentsTool.normalizedPerPage(15.0) == 15)
    #expect(GitHubIssueCommentsTool.normalizedPerPage("30") == 30)
    #expect(GitHubIssueCommentsTool.normalizedPerPage(25) == 25)
    #expect(GitHubIssueCommentsTool.normalizedPerPage(250) == 100)

    let schema = GitHubIssueCommentsTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])
    #expect(properties["page"]?["minimum"] as? Int == 1)
    #expect(properties["perPage"]?["minimum"] as? Int == 1)
    #expect(properties["perPage"]?["maximum"] as? Int == 100)
}
