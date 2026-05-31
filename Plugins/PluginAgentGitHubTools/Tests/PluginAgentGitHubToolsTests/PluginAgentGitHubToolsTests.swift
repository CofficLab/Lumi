import Foundation
import Testing
@testable import PluginAgentGitHubTools

@Test func packageLoads() async throws {
    #expect(GitHubToolsPlugin.id == "GitHubTools")
    #expect(GitHubToolsPlugin.displayName.isEmpty == false)
    #expect(GitHubToolsPlugin.description.isEmpty == false)
    #expect(GitHubToolsPlugin.iconName == "star.circle.fill")
    #expect(GitHubToolsPlugin.category == .developerTool)
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
