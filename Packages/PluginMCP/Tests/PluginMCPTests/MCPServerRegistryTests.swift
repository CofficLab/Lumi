import Foundation
import KitAgentTool
import KitMCP
import Testing
@testable import PluginMCP

@Suite("MCPServerRegistry")
@MainActor
struct MCPServerRegistryTests {
    private func makeRegistry() -> MCPServerRegistry {
        let suiteName = "PluginMCPTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return MCPServerRegistry(defaults: defaults)
    }

    @Test("首次初始化落库 Xcode 预设（禁用态）")
    func seedsPreset() {
        let registry = makeRegistry()
        #expect(registry.servers.count == 1)
        let preset = try! #require(registry.servers.first)
        #expect(preset.name == "Xcode (native)")
        #expect(preset.command == "xcrun")
        #expect(preset.arguments == ["mcpbridge"])
        #expect(preset.enabled == false)
    }

    @Test("CRUD：新增 / 更新 / 删除")
    func crud() {
        let registry = makeRegistry()
        let added = registry.addServer(MCPServerConfig(name: "Test", command: "/bin/echo"))
        #expect(!added.id.isEmpty)
        #expect(registry.server(id: added.id)?.command == "/bin/echo")

        var updated = added
        updated.command = "/usr/bin/true"
        updated.arguments = ["--flag"]
        registry.updateServer(updated)
        let stored = registry.server(id: added.id)
        #expect(stored?.command == "/usr/bin/true")
        #expect(stored?.arguments == ["--flag"])

        registry.removeServer(id: added.id)
        #expect(registry.server(id: added.id) == nil)
        #expect(!registry.servers.contains { $0.id == added.id })
    }

    @Test("持久化往返：重建实例后状态一致")
    func persistenceRoundTrip() {
        let suiteName = "PluginMCPTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let first = MCPServerRegistry(defaults: defaults)
        let added = first.addServer(MCPServerConfig(
            name: "Persist",
            command: "npx",
            arguments: ["-y", "server"],
            transport: .stdio,
            autoStart: true,
            enabled: true
        ))
        first.globalEnabled = false
        first.unknownToolDefaultLevel = .medium
        first.setRiskOverride(serverID: added.id, toolName: "write_file", level: .high)

        let second = MCPServerRegistry(defaults: defaults)
        #expect(second.globalEnabled == false)
        #expect(second.unknownToolDefaultLevel == .medium)
        let restored = try! #require(second.server(id: added.id))
        #expect(restored.name == "Persist")
        #expect(restored.command == "npx")
        #expect(restored.autoStart == true)
        #expect(restored.enabled == true)
        #expect(second.riskOverride(serverID: added.id, toolName: "write_file") == .high)
    }

    @Test("风险覆盖：设置与清除")
    func riskOverride() {
        let registry = makeRegistry()
        let added = registry.addServer(MCPServerConfig(name: "T", command: "/bin/echo"))
        #expect(registry.riskOverride(serverID: added.id, toolName: "read_file") == nil)

        registry.setRiskOverride(serverID: added.id, toolName: "read_file", level: .safe)
        #expect(registry.riskOverride(serverID: added.id, toolName: "read_file") == .safe)

        registry.setRiskOverride(serverID: added.id, toolName: "read_file", level: nil)
        #expect(registry.riskOverride(serverID: added.id, toolName: "read_file") == nil)
    }

    @Test("预设模板不重复写入")
    func noDuplicateSeed() {
        let suiteName = "PluginMCPTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        _ = MCPServerRegistry(defaults: defaults)
        let second = MCPServerRegistry(defaults: defaults)
        #expect(second.servers.count == 1)
    }
}
