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
    func crud() throws {
        let (registry, _) = makeRegistry()
        let added = try registry.addServer(MCPServerConfig(name: "Test", command: "/bin/echo"))
        #expect(!added.id.isEmpty)
        #expect(registry.server(id: added.id)?.command == "/bin/echo")

        var updated = added
        updated.command = "/usr/bin/true"
        updated.arguments = ["--flag"]
        try registry.updateServer(updated)
        let stored = registry.server(id: added.id)
        #expect(stored?.command == "/usr/bin/true")
        #expect(stored?.arguments == ["--flag"])

        try registry.removeServer(id: added.id)
        #expect(registry.server(id: added.id) == nil)
        #expect(!registry.servers.contains { $0.id == added.id })
    }

    @Test("持久化往返：重建实例后状态一致")
    func persistenceRoundTrip() throws {
        let dir = makeTempDirectory()
        let first = MCPServerRegistry(directory: dir)
        let added = try first.addServer(MCPServerConfig(
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
    func updateReplacesAllSameId() throws {
        let (registry, _) = makeRegistry()
        let dupID = UUID().uuidString
        let a = MCPServerConfig(id: dupID, name: "test", command: "python3", arguments: ["a.py"])
        let b = MCPServerConfig(id: dupID, name: "test", command: "python3", arguments: ["b.py"])
        try registry.addServer(a)
        try registry.addServer(b)
        #expect(registry.servers.filter { $0.id == dupID }.count == 2)

        var updated = a
        updated.command = "/opt/homebrew/bin/python3"
        try registry.updateServer(updated)
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

    @Test("删除的内置模板重启后不再被自动 seed（回归 #295）")
    func deletedBuiltInTemplateStaysDeletedAcrossRestart() throws {
        let dir = makeTempDirectory()
        let contributor = MCPServerContributor()
        contributor.contribute(MCPServerTemplate.xcodeNative)

        let first = MCPServerRegistry(directory: dir, contributor: contributor)
        let xcode = try #require(first.servers.first { $0.command == "xcrun" && $0.arguments == ["mcpbridge"] })
        try first.removeServer(id: xcode.id)
        #expect(first.server(id: xcode.id) == nil)

        // 模拟重启：同一数据目录 + 同一贡献者重新构建注册表。
        let second = MCPServerRegistry(directory: dir, contributor: contributor)
        #expect(!second.servers.contains { $0.command == "xcrun" && $0.arguments == ["mcpbridge"] })
    }

    @Test("删除一个内置模板不影响其他内置模板的 seed")
    func deletingOneTemplateDoesNotBlockOthers() throws {
        let dir = makeTempDirectory()
        let contributor = MCPServerContributor()
        contributor.contribute(MCPServerTemplate.xcodeNative)
        contributor.contribute(MCPServerTemplate.github)

        let first = MCPServerRegistry(directory: dir, contributor: contributor)
        let xcode = try #require(first.servers.first { $0.command == "xcrun" })
        try first.removeServer(id: xcode.id)

        let second = MCPServerRegistry(directory: dir, contributor: contributor)
        #expect(!second.servers.contains { $0.command == "xcrun" })
        #expect(second.servers.contains { $0.command == "docker" })
    }

    // MARK: - 解码失败不得清空写回（回归 #531）

    @Test("解码失败保留原文件，不被 seed 覆盖")
    func corruptFileIsPreservedOnLoad() throws {
        let dir = makeTempDirectory()
        let fileURL = dir.appendingPathComponent("mcp-servers.json")
        // 合法 JSON 但类型不符（对象而非数组）→ 解码抛错。
        let corrupt = Data(#"{ "unexpected": true }"#.utf8)
        try corrupt.write(to: fileURL)

        let contributor = MCPServerContributor()
        contributor.contribute(MCPServerTemplate.xcodeNative)
        let registry = MCPServerRegistry(directory: dir, contributor: contributor)

        #expect(registry.loadFailed)
        // 原文件字节必须原封不动：seed 不得原子覆盖用户配置。
        let after = try Data(contentsOf: fileURL)
        #expect(after == corrupt)
    }

    @Test("解码失败后 CRUD 报错且不覆盖原文件（回归 #531 / #532）")
    func corruptFileSurvivesCRUD() throws {
        let dir = makeTempDirectory()
        let fileURL = dir.appendingPathComponent("mcp-servers.json")
        // 截断/损坏的字节 → 读取或解码抛错。
        let corrupt = Data("][ truncated".utf8)
        try corrupt.write(to: fileURL)

        let registry = MCPServerRegistry(directory: dir)
        #expect(registry.loadFailed)

        // 加载失败后禁止写回，但必须把失败抛给调用方，不能静默「保存成功」（#532）。
        let config = MCPServerConfig(id: UUID().uuidString, name: "New", command: "/bin/echo")
        #expect(throws: MCPServerRegistryError.self) { try registry.addServer(config) }
        #expect(throws: MCPServerRegistryError.self) { try registry.updateServer(config) }
        #expect(throws: MCPServerRegistryError.self) { try registry.removeServer(id: config.id) }
        #expect(registry.servers.isEmpty)

        let after = try Data(contentsOf: fileURL)
        #expect(after == corrupt)
    }

    @Test("文件缺失视为首次运行，允许 seed 落库")
    func missingFileAllowsSeed() throws {
        let dir = makeTempDirectory()
        let contributor = MCPServerContributor()
        contributor.contribute(MCPServerTemplate.xcodeNative)
        let registry = MCPServerRegistry(directory: dir, contributor: contributor)

        #expect(!registry.loadFailed)
        #expect(registry.servers.contains { $0.command == "xcrun" })
        // 落库成功：重建后仍在。
        let second = MCPServerRegistry(directory: dir)
        #expect(second.servers.contains { $0.command == "xcrun" })
    }

    @Test("合法文件加载不置 loadFailed")
    func validFileDoesNotSetLoadFailed() throws {
        let dir = makeTempDirectory()
        let first = MCPServerRegistry(directory: dir)
        try first.addServer(MCPServerConfig(name: "OK", command: "npx"))

        let second = MCPServerRegistry(directory: dir)
        #expect(!second.loadFailed)
        #expect(second.servers.contains { $0.name == "OK" })
    }

    // MARK: - 写回失败必须抛出且不得污染内存（回归 #532）

    /// 先正常加载一份配置，再把配置文件路径换成目录：之后的原子写必然失败，
    /// 且与运行用户 / 目录权限无关。
    private func makeRegistryWithExisting() throws -> (MCPServerRegistry, URL, MCPServerConfig) {
        let dir = makeTempDirectory()
        let existing = MCPServerConfig(id: UUID().uuidString, name: "Existing", command: "/bin/echo")
        try JSONEncoder().encode([existing]).write(to: dir.appendingPathComponent("mcp-servers.json"))
        return (MCPServerRegistry(directory: dir), dir, existing)
    }

    private func breakWritePath(in dir: URL) throws {
        let fileURL = dir.appendingPathComponent("mcp-servers.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
    }

    private func restoreWritePath(in dir: URL) throws {
        try FileManager.default.removeItem(at: dir.appendingPathComponent("mcp-servers.json"))
    }

    @Test("新增写回失败必须抛出，内存列表与磁盘原配置都不变")
    func addServerWriteFailureThrowsAndKeepsList() throws {
        let (registry, dir, existing) = try makeRegistryWithExisting()
        #expect(!registry.loadFailed)
        try breakWritePath(in: dir)

        #expect(throws: MCPServerRegistryError.self) {
            try registry.addServer(MCPServerConfig(name: "New", command: "/bin/true"))
        }
        #expect(registry.servers.map(\.id) == [existing.id])

        // 恢复可写后重试：新增确实落库，重启可见。
        try restoreWritePath(in: dir)
        let added = try registry.addServer(MCPServerConfig(name: "New", command: "/bin/true"))
        let second = MCPServerRegistry(directory: dir)
        #expect(second.server(id: added.id)?.command == "/bin/true")
    }

    @Test("更新写回失败必须抛出，列表保留原配置")
    func updateServerWriteFailureKeepsStoredConfig() throws {
        let (registry, dir, existing) = try makeRegistryWithExisting()
        try breakWritePath(in: dir)

        var edited = existing
        edited.command = "/bin/true"
        edited.enabled = false
        #expect(throws: MCPServerRegistryError.self) { try registry.updateServer(edited) }
        #expect(registry.server(id: existing.id)?.command == "/bin/echo")
        #expect(registry.server(id: existing.id)?.enabled == true)
        #expect(registry.servers.count == 1)
    }

    @Test("删除写回失败必须抛出，服务器与内置模板墓碑都保持不变")
    func removeServerWriteFailureKeepsServerAndTemplate() throws {
        let dir = makeTempDirectory()
        let contributor = MCPServerContributor()
        contributor.contribute(MCPServerTemplate.xcodeNative)
        let registry = MCPServerRegistry(directory: dir, contributor: contributor)
        let xcode = try #require(registry.servers.first { $0.command == "xcrun" })
        try breakWritePath(in: dir)

        #expect(throws: MCPServerRegistryError.self) { try registry.removeServer(id: xcode.id) }
        #expect(registry.server(id: xcode.id) != nil)
        // 墓碑只在删除确实落库后记录：失败的删除不得永久屏蔽该内置模板。
        let tombstone = dir.appendingPathComponent("mcp-deleted-templates.json")
        #expect(!FileManager.default.fileExists(atPath: tombstone.path))

        try restoreWritePath(in: dir)
        try registry.removeServer(id: xcode.id)
        #expect(registry.server(id: xcode.id) == nil)
        #expect(FileManager.default.fileExists(atPath: tombstone.path))
    }
}
