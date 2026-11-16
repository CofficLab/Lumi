import Foundation
import KitMCP
import Testing
@testable import PluginMCP

/// 保存 / 启停 / 删除都必须以「确实写进磁盘」为成功前提（#532）。
///
/// 写回失败时注册表抛出、内存列表保持不变，UI 侧拿到错误文案：
/// 编辑页保留、开关回到原值、服务器不被删除，也不触发连接。
@MainActor
@Suite("MCP 配置写回失败")
struct MCPSaveFailureTests {
    private func makeDirectory() -> URL {
        MCPTestDoubles.makeTemporaryDirectory("mcp-save-failure")
    }

    private func makeRegistryWithExisting() throws -> (MCPServerRegistry, URL, MCPServerConfig) {
        let dir = makeDirectory()
        let existing = MCPServerConfig(id: UUID().uuidString, name: "Existing", command: "/bin/echo")
        try JSONEncoder().encode([existing]).write(to: dir.appendingPathComponent("mcp-servers.json"))
        return (MCPServerRegistry(directory: dir), dir, existing)
    }

    /// 把配置文件路径换成目录，让原子写必然失败（与权限 / 运行用户无关）。
    private func breakWritePath(in dir: URL) throws {
        let fileURL = dir.appendingPathComponent("mcp-servers.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
    }

    @Test("编辑页保存：写回失败必须抛出，新增与编辑都不得改动列表")
    func editorSaveThrowsWhenWriteFails() throws {
        let (registry, dir, existing) = try makeRegistryWithExisting()
        try breakWritePath(in: dir)

        #expect(throws: MCPServerRegistryError.self) {
            try MCPServerEditSheet.save(
                MCPServerConfig(name: "New", command: "/bin/true"),
                registry: registry,
                isEditing: false
            )
        }

        var edited = existing
        edited.command = "/bin/true"
        #expect(throws: MCPServerRegistryError.self) {
            try MCPServerEditSheet.save(edited, registry: registry, isEditing: true)
        }

        #expect(registry.servers.map(\.id) == [existing.id])
        #expect(registry.server(id: existing.id)?.command == "/bin/echo")
    }

    @Test("编辑页保存：只有落库成功才返回配置")
    func editorSaveReturnsConfigOnlyAfterDiskWrite() throws {
        let dir = makeDirectory()
        let registry = MCPServerRegistry(directory: dir)

        let saved = try MCPServerEditSheet.save(
            MCPServerConfig(name: "New", command: "/bin/true"),
            registry: registry,
            isEditing: false
        )
        #expect(!saved.id.isEmpty)
        #expect(registry.server(id: saved.id)?.command == "/bin/true")

        let second = MCPServerRegistry(directory: dir)
        #expect(second.server(id: saved.id)?.command == "/bin/true")
    }

    @Test("启停开关：写回失败返回错误文案，enabled 保持原值")
    func toggleFailureReportsErrorAndKeepsState() throws {
        let (registry, dir, existing) = try makeRegistryWithExisting()
        try breakWritePath(in: dir)

        let message = MCPSettingsView.setEnabled(false, server: existing, registry: registry)
        #expect(message?.isEmpty == false)
        #expect(registry.server(id: existing.id)?.enabled == true)
        #expect(registry.servers.count == 1)
    }

    @Test("启停开关：写回成功返回 nil 且 enabled 落库")
    func toggleSuccessPersistsEnabled() throws {
        let (registry, dir, existing) = try makeRegistryWithExisting()

        let message = MCPSettingsView.setEnabled(false, server: existing, registry: registry)
        #expect(message == nil)
        #expect(registry.server(id: existing.id)?.enabled == false)

        let second = MCPServerRegistry(directory: dir)
        #expect(second.server(id: existing.id)?.enabled == false)
    }

    @Test("删除：写回失败返回错误文案，服务器与模板墓碑都保留")
    func deleteFailureReportsErrorAndKeepsServer() throws {
        let (registry, dir, existing) = try makeRegistryWithExisting()
        try breakWritePath(in: dir)

        let message = MCPSettingsView.deleteServer(id: existing.id, registry: registry)
        #expect(message?.isEmpty == false)
        #expect(registry.server(id: existing.id) != nil)
        #expect(!FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("mcp-deleted-templates.json").path
        ))
    }

    @Test("删除：写回成功返回 nil 且服务器不再出现")
    func deleteSuccessRemovesServer() throws {
        let (registry, dir, existing) = try makeRegistryWithExisting()

        let message = MCPSettingsView.deleteServer(id: existing.id, registry: registry)
        #expect(message == nil)
        #expect(registry.server(id: existing.id) == nil)

        let second = MCPServerRegistry(directory: dir)
        #expect(second.server(id: existing.id) == nil)
    }

    @Test("错误文案带上底层原因，加载失败也有可显示的说明")
    func failureMessageIncludesUnderlyingReason() {
        let underlying = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        let message = MCPSettingsView.persistenceFailureMessage(
            MCPServerRegistryError.writeFailed(underlying: underlying)
        )
        #expect(message.contains(underlying.localizedDescription))

        let loadFailedMessage = MCPSettingsView.persistenceFailureMessage(MCPServerRegistryError.loadFailed)
        #expect(!loadFailedMessage.isEmpty)
    }
}