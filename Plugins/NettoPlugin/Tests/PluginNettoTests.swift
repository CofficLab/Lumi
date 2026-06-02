import Foundation
import NetworkExtension
import Testing
@testable import NettoPlugin

@Test func corruptSettingsFileIsPreservedBeforeSavingNewSettings() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let settingsURL = directory.appendingPathComponent("settings.json")
    try Data("{ invalid json".utf8).write(to: settingsURL)

    let repo = AppSettingRepo(fileURL: settingsURL)

    #expect(repo.settings.isEmpty)
    let backupURL = settingsURL.appendingPathExtension("corrupt")
    #expect(FileManager.default.fileExists(atPath: backupURL.path))
    #expect(try String(contentsOf: backupURL, encoding: .utf8) == "{ invalid json")

    repo.setAllowed(appId: "com.example.App", allowed: false)

    let savedData = try Data(contentsOf: settingsURL)
    let savedSettings = try JSONDecoder().decode([AppSetting].self, from: savedData)
    #expect(savedSettings == [AppSetting(appId: "com.example.App", allowed: false)])
    #expect(try String(contentsOf: backupURL, encoding: .utf8) == "{ invalid json")
}

@Test func loadSettingsKeepsPersistedAllowRules() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let settingsURL = directory.appendingPathComponent("settings.json")
    let original = [
        AppSetting(appId: "com.example.Allow", allowed: true),
        AppSetting(appId: "com.example.Block", allowed: false),
    ]
    try JSONEncoder().encode(original).write(to: settingsURL)

    let repo = AppSettingRepo(fileURL: settingsURL)

    #expect(repo.getSetting(for: "com.example.Allow")?.allowed == true)
    #expect(repo.getSetting(for: "com.example.Block")?.allowed == false)
}

@Test func loadSettingsHandlesDuplicateAppIdsWithoutCrashing() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let settingsURL = directory.appendingPathComponent("settings.json")
    let duplicated = [
        AppSetting(appId: "com.example.App", allowed: true),
        AppSetting(appId: "com.example.App", allowed: false),
    ]
    try JSONEncoder().encode(duplicated).write(to: settingsURL)

    let repo = AppSettingRepo(fileURL: settingsURL)

    #expect(repo.settings.count == 1)
    #expect(repo.getSetting(for: "com.example.App")?.allowed == false)
}

@Test func connectionPromptMessageIncludesDecisionContext() {
    let message = FirewallService.connectionPromptMessage(
        appId: "com.example.App",
        hostname: "example.com",
        port: "443",
        direction: .outbound
    )

    #expect(message.contains("com.example.App"))
    #expect(message.contains("example.com:443"))
    #expect(message.contains("Outgoing"))
}
