import Foundation
import KitMCP
import Testing
@testable import PluginMCP

/// 回归 #533：启停开关必须同步 autoStart，启用过的服务器重启后要能自动恢复连接。
///
/// `startAutoStartServers` 只连接 `enabled && autoStart` 的服务器；开关若只写
/// `enabled`，本次运行能连上，重启后却被自动启动逻辑跳过，UI 仍显示已启用。
@MainActor
@Suite("MCP 启停与自动启动同步")
struct MCPAutoStartSyncTests {
    private func makeDirectory() -> URL {
        MCPTestDoubles.makeTemporaryDirectory("mcp-autostart-sync")
    }

    private func write(_ configs: [MCPServerConfig], to dir: URL) throws {
        try JSONEncoder().encode(configs).write(to: dir.appendingPathComponent("mcp-servers.json"))
    }

    private func readFromDisk(_ dir: URL) throws -> [MCPServerConfig] {
        let data = try Data(contentsOf: dir.appendingPathComponent("mcp-servers.json"))
        return try JSONDecoder().decode([MCPServerConfig].self, from: data)
    }

    /// 与 `startAutoStartServers` 完全一致的筛选条件。
    private func autoStartIDs(_ registry: MCPServerRegistry) -> [String] {
        registry.servers.filter { $0.enabled && $0.autoStart }.map(\.id)
    }

    @Test("打开开关后 autoStart 一并落库，重启仍会被自动启动选中")
    func toggleOnPersistsAutoStartForNextLaunch() throws {
        let dir = makeDirectory()
        // 贡献模板以禁用态 seed：enabled=false、autoStart=false。
        let seeded = MCPServerConfig(
            id: UUID().uuidString,
            name: "Xcode (native)",
            command: "xcrun",
            arguments: ["mcpbridge"],
            autoStart: false,
            enabled: false
        )
        try write([seeded], to: dir)
        let registry = MCPServerRegistry(directory: dir)
        #expect(autoStartIDs(registry).isEmpty)

        let message = MCPSettingsView.setEnabled(true, server: seeded, registry: registry)
        #expect(message == nil)
        #expect(registry.server(id: seeded.id)?.autoStart == true)

        // 重启：重新读盘的注册表必须仍把它算进自动启动集合。
        let restarted = MCPServerRegistry(directory: dir)
        #expect(restarted.server(id: seeded.id)?.enabled == true)
        #expect(restarted.server(id: seeded.id)?.autoStart == true)
        #expect(autoStartIDs(restarted) == [seeded.id])
    }

    @Test("关闭开关同时清掉 autoStart，重启不再自动连接")
    func toggleOffClearsAutoStart() throws {
        let dir = makeDirectory()
        let existing = MCPServerConfig(
            id: UUID().uuidString,
            name: "Existing",
            command: "/bin/echo",
            autoStart: true,
            enabled: true
        )
        try write([existing], to: dir)
        let registry = MCPServerRegistry(directory: dir)

        let message = MCPSettingsView.setEnabled(false, server: existing, registry: registry)
        #expect(message == nil)

        let restarted = MCPServerRegistry(directory: dir)
        #expect(restarted.server(id: existing.id)?.enabled == false)
        #expect(restarted.server(id: existing.id)?.autoStart == false)
        #expect(autoStartIDs(restarted).isEmpty)
    }

    @Test("历史遗留的 enabled=true/autoStart=false 在读盘时自愈并写回")
    func legacyEnabledWithoutAutoStartIsRepairedOnLoad() throws {
        let dir = makeDirectory()
        let legacy = MCPServerConfig(
            id: UUID().uuidString,
            name: "Legacy enabled",
            command: "/bin/echo",
            autoStart: false,
            enabled: true
        )
        try write([legacy], to: dir)

        let registry = MCPServerRegistry(directory: dir)
        #expect(registry.server(id: legacy.id)?.autoStart == true)
        #expect(autoStartIDs(registry) == [legacy.id])
        #expect(try readFromDisk(dir).first?.autoStart == true, "自愈结果必须落盘，否则每次启动都要重修")

        let restarted = MCPServerRegistry(directory: dir)
        #expect(autoStartIDs(restarted) == [legacy.id])
    }

    @Test("自愈只修复已启用的服务器，禁用态保持不变")
    func repairDoesNotTouchDisabledServers() throws {
        let dir = makeDirectory()
        let disabled = MCPServerConfig(
            id: UUID().uuidString,
            name: "Disabled",
            command: "/bin/echo",
            autoStart: false,
            enabled: false
        )
        let enabled = MCPServerConfig(
            id: UUID().uuidString,
            name: "Enabled",
            command: "/bin/true",
            autoStart: false,
            enabled: true
        )
        try write([disabled, enabled], to: dir)

        let registry = MCPServerRegistry(directory: dir)
        #expect(registry.server(id: disabled.id)?.autoStart == false)
        #expect(registry.server(id: disabled.id)?.enabled == false)
        #expect(registry.server(id: enabled.id)?.autoStart == true)
        #expect(autoStartIDs(registry) == [enabled.id])
    }

    @Test("写回失败时 autoStart 与 enabled 都保持原值（#532 护栏）")
    func toggleFailureKeepsAutoStartUnchanged() throws {
        let dir = makeDirectory()
        let existing = MCPServerConfig(
            id: UUID().uuidString,
            name: "Existing",
            command: "/bin/echo",
            autoStart: true,
            enabled: true
        )
        try write([existing], to: dir)
        let registry = MCPServerRegistry(directory: dir)

        // 把配置文件路径换成目录，让原子写必然失败。
        let fileURL = dir.appendingPathComponent("mcp-servers.json")
        try FileManager.default.removeItem(at: fileURL)
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)

        let message = MCPSettingsView.setEnabled(false, server: existing, registry: registry)
        #expect(message?.isEmpty == false)
        #expect(registry.server(id: existing.id)?.enabled == true)
        #expect(registry.server(id: existing.id)?.autoStart == true)
    }
}