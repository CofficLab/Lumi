import Foundation
import KitAgentTool
import KitMCP
import Testing
@testable import PluginMCP

@Suite("MCPServerRegistry")
@MainActor
struct MCPServerRegistryTests {
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginMCPTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeRegistry(contributions: [MCPServerConfig] = []) -> (MCPServerRegistry, URL) {
        let dir = makeTempDirectory()
        let contributor = MCPServerContributor()
        for server in contributions { contributor.contribute(server) }
        let registry = MCPServerRegistry(directory: dir, contributor: contributor)
        return (registry, dir)
    }

    @Test("贡献的内置预设（Xcode 与 GitHub）以禁用态落库")
    func seedsPreset() {
        let (registry, _) = makeRegistry(contributions: [
            MCPServerTemplate.xcodeNative,
            MCPServerTemplate.github,
        ])
        #expect(registry.servers.count == 2)

        let xcode = try! #require(registry.servers.first { $0.name == "Xcode (native)" })
        #expect(xcode.command == "xcrun")
        #expect(xcode.arguments == ["mcpbridge"])
        #expect(xcode.enabled == false)

        let github = try! #require(registry.servers.first { $0.name == "GitHub (official)" })
        #expect(github.command == "docker")
        #expect(github.arguments.contains("ghcr.io/github/github-mcp-server"))
        #expect(github.environment["GITHUB_PERSONAL_ACCESS_TOKEN"] != nil)
        #expect(github.enabled == false)
    }

    @Test("CRUD：新增 / 更新 / 删除")
    func crud() {
        let (registry, _) = makeRegistry()
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
    func persistenceRoundTrip() throws {
        let dir = makeTempDirectory()
        let first = MCPServerRegistry(directory: dir)
        let added = first.addServer(MCPServerConfig(
            name: "Persist",
            command: "npx",
            arguments: ["-y", "server"],
            transport: .stdio,
            autoStart: true,
            enabled: true
        ))

        let second = MCPServerRegistry(directory: dir)
        let restored = try #require(second.server(id: added.id))
        #expect(restored.name == "Persist")
        #expect(restored.command == "npx")
        #expect(restored.autoStart == true)
        #expect(restored.enabled == true)
    }

    @Test("重复初始化不重复写入贡献预设")
    func noDuplicateSeed() {
        let dir = makeTempDirectory()
        let contributor = MCPServerContributor()
        contributor.contribute(MCPServerTemplate.xcodeNative)

        _ = MCPServerRegistry(directory: dir, contributor: contributor)
        let second = MCPServerRegistry(directory: dir, contributor: contributor)
        #expect(second.servers.filter { $0.name == "Xcode (native)" }.count == 1)
    }

    @Test("加载时按 id 去重（自愈历史重复数据）")
    func loadDeduplicatesById() throws {
        let dir = makeTempDirectory()
        let dupID = UUID().uuidString
        let a = MCPServerConfig(id: dupID, name: "test", command: "python3", arguments: ["a.py"])
        let b = MCPServerConfig(id: dupID, name: "test", command: "python3", arguments: ["b.py"])
        let c = MCPServerConfig(id: UUID().uuidString, name: "Other", command: "/bin/echo")
        let data = try JSONEncoder().encode([a, b, c])
        try data.write(to: dir.appendingPathComponent("mcp-servers.json"))

        let registry = MCPServerRegistry(directory: dir)
        #expect(registry.servers.filter { $0.id == dupID }.count == 1)
        // 保留第一条出现的内容。
        #expect(registry.servers.first { $0.id == dupID }?.arguments == ["a.py"])
    }

    @Test("更新时替换全部同 id 条目，不产生重复")
    func updateReplacesAllSameId() {
        let (registry, _) = makeRegistry()
        let dupID = UUID().uuidString
        let a = MCPServerConfig(id: dupID, name: "test", command: "python3", arguments: ["a.py"])
        let b = MCPServerConfig(id: dupID, name: "test", command: "python3", arguments: ["b.py"])
        registry.addServer(a)
        registry.addServer(b)
        #expect(registry.servers.filter { $0.id == dupID }.count == 2)

        var updated = a
        updated.command = "/opt/homebrew/bin/python3"
        registry.updateServer(updated)
        #expect(registry.servers.filter { $0.id == dupID }.count == 1)
        #expect(registry.servers.first { $0.id == dupID }?.command == "/opt/homebrew/bin/python3")
    }

    @Test("模拟 boot 序列：先贡献 Xcode 再贡献 GitHub，两个都应 seed")
    func simulateBootContributions() async {
        let dir = makeTempDirectory()
        let contributor = MCPServerContributor()
        let registry = MCPServerRegistry(directory: dir, contributor: contributor)

        // PluginXcodeMCP.boot（order 280）
        contributor.contribute(MCPServerConfig(
            name: "Xcode (native)",
            command: "xcrun",
            arguments: ["mcpbridge"]
        ))
        await Task.yield()

        // PluginGithubMCP.boot（order 281）
        contributor.contribute(MCPServerTemplate.github)
        await Task.yield()
        await Task.yield()

        #expect(registry.servers.contains { $0.command == "xcrun" }, "Xcode 应被 seed")
        #expect(registry.servers.contains { $0.command == "docker" }, "GitHub 应被 seed")
    }
}
