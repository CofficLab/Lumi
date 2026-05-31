import Testing
import Foundation
import MCPKit
@testable import PluginAgentMCPTools

@Test func packageLoads() async throws {
    #expect(AgentMCPToolsPlugin.id == "AgentMCPTools")
}

@Test func localStoreReportsSaveResultAndReloadsMCPConfigs() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentMCPLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let configs = [
        MCPServerConfig(name: "filesystem", command: "npx", args: ["server"], env: ["A": "B"])
    ]
    let data = try JSONEncoder().encode(configs)
    let store = AgentMCPPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(data, forKey: "MCPService_Configs") == true)

    let reloadedStore = AgentMCPPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.mcpServerConfigs(forKey: "MCPService_Configs") == configs)
}

@Test func localStoreReturnsEmptyConfigsForInvalidJSON() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentMCPLocalStore-InvalidJSON-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = AgentMCPPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(Data("not json".utf8), forKey: "MCPService_Configs") == true)
    #expect(store.mcpServerConfigs(forKey: "MCPService_Configs").isEmpty)
}

@Test func localStoreQuarantinesInvalidSettingsFileAndRecoversOnSave() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentMCPLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = AgentMCPPluginLocalStore(settingsDirectory: directory)

    let configs = [
        MCPServerConfig(name: "filesystem", command: "npx", args: ["server"], env: [:])
    ]
    let data = try JSONEncoder().encode(configs)

    #expect(store.set(data, forKey: "MCPService_Configs") == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.mcpServerConfigs(forKey: "MCPService_Configs") == configs)
}

@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentMCPLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = AgentMCPPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set(Data("[]".utf8), forKey: "MCPService_Configs") == false)
    #expect(store.mcpServerConfigs(forKey: "MCPService_Configs").isEmpty)
}
