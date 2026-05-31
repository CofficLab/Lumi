import Foundation
import ProjectProfileKit
import Testing
@testable import PluginGitHubInsight

@Test func packageLoads() async throws {
    #expect(GitHubInsightPlugin.id == "GitHubInsight")
}

@Test func queryEcoKBToolSchemaClampsLimit() throws {
    let schema = QueryEcoKBTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: Any])
    let limit = try #require(properties["limit"] as? [String: Any])

    #expect(limit["type"] as? String == "integer")
    #expect(limit["minimum"] as? Int == 1)
    #expect(limit["maximum"] as? Int == QueryEcoKBTool.maxResultLimit)
}

@Test func queryEcoKBToolNormalizesLimit() {
    #expect(QueryEcoKBTool.normalizedLimit(nil) == QueryEcoKBTool.defaultResultLimit)
    #expect(QueryEcoKBTool.normalizedLimit(-10) == 1)
    #expect(QueryEcoKBTool.normalizedLimit(0) == 1)
    #expect(QueryEcoKBTool.normalizedLimit(8) == 8)
    #expect(QueryEcoKBTool.normalizedLimit(999) == QueryEcoKBTool.maxResultLimit)
}

@Test func knowledgeBaseSavesAndReloadsProjectStore() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitHubInsightKB-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = GitHubInsightKnowledgeBaseManager(rootDirectory: root)
    let profile = makeProfile(projectPath: "/tmp/project")
    let entries = [makeEntry(fullName: "owner/repo")]

    try await manager.save(projectPath: profile.projectPath, profile: profile, entries: entries)

    let reloaded = try #require(await manager.loadStore(projectPath: profile.projectPath))
    #expect(reloaded.projectPath == profile.projectPath)
    #expect(reloaded.profile.primaryLanguage == "Swift")
    #expect(reloaded.entries.map(\.fullName) == ["owner/repo"])
    #expect(await manager.loadEntries(projectPath: profile.projectPath).map(\.fullName) == ["owner/repo"])
}

@Test func knowledgeBaseReportsSaveFailureWhenDirectoryIsBlocked() async throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitHubInsightKB-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedRoot = tempRoot.appendingPathComponent("GitHubInsightPlugin", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedRoot, atomically: true, encoding: .utf8)

    let manager = GitHubInsightKnowledgeBaseManager(rootDirectory: blockedRoot)

    await #expect(throws: Error.self) {
        try await manager.save(
            projectPath: "/tmp/project",
            profile: makeProfile(projectPath: "/tmp/project"),
            entries: [makeEntry(fullName: "owner/repo")]
        )
    }
}

@Test func knowledgeBaseSkipsCorruptStoresWhenLoadingAllEntries() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitHubInsightKB-Corrupt-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let manager = GitHubInsightKnowledgeBaseManager(rootDirectory: root)
    try await manager.save(
        projectPath: "/tmp/good",
        profile: makeProfile(projectPath: "/tmp/good"),
        entries: [makeEntry(fullName: "owner/good")]
    )
    try Data("not json".utf8).write(to: root.appendingPathComponent("broken.json"))

    let entries = await manager.loadAllEntries()
    #expect(entries.map(\.fullName) == ["owner/good"])
    #expect(await manager.loadStore(projectPath: "/tmp/missing") == nil)
}

private func makeProfile(projectPath: String) -> GitHubInsightProjectProfile {
    ProjectProfile(
        projectPath: projectPath,
        primaryLanguage: "Swift",
        frameworks: ["SwiftUI"],
        dependencies: ["LumiCoreKit"],
        projectType: .app,
        keywords: ["desktop"],
        description: "Desktop assistant",
        platform: "macOS"
    )
}

private func makeEntry(fullName: String) -> GitHubInsightKBEntry {
    GitHubInsightKBEntry(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        repoURL: "https://github.com/\(fullName)",
        fullName: fullName,
        description: "Useful repository",
        stars: 42,
        language: "Swift",
        topics: ["macos"],
        lastPushedAt: nil,
        relevanceScore: 0.9,
        keyInsights: ["Matches SwiftUI"],
        syncedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
