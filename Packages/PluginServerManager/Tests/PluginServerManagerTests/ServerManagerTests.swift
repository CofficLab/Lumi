import Foundation
import KitAgentTool
import Testing

@testable import PluginServerManager

@Suite
struct ServerBackendTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("server-manager-tests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test
    func addAndPersistRoundTrip() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let backend = ServerBackend(directory: directory)
        try await backend.add(ServerConfig(name: "web-01", host: "10.0.0.1", user: "deploy"))

        let reloaded = ServerBackend(directory: directory)
        let servers = await reloaded.allServers()
        #expect(servers.count == 1)
        #expect(servers[0].name == "web-01")
        #expect(servers[0].destination == "deploy@10.0.0.1")
    }

    @Test
    func removeServerPersists() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let backend = ServerBackend(directory: directory)
        let config = ServerConfig(name: "db-01", host: "10.0.0.2", user: "ops")
        try await backend.add(config)
        try await backend.remove(id: config.id)

        let reloaded = ServerBackend(directory: directory)
        let servers = await reloaded.allServers()
        #expect(servers.isEmpty)
    }

    @Test
    func serverMatchingByNameIsCaseInsensitive() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let backend = ServerBackend(directory: directory)
        try await backend.add(ServerConfig(name: "Prod-Web", host: "10.0.0.3", user: "root"))
        let found = await backend.server(matching: "prod-web")
        #expect(found?.host == "10.0.0.3")
        let missing = await backend.server(matching: "nope")
        #expect(missing == nil)
    }

    @Test
    func probeUnknownServerThrows() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let backend = ServerBackend(directory: directory)
        await #expect(throws: ServerBackendError.self) {
            try await backend.probe(id: UUID())
        }
    }
}

@Suite
struct ServerToolTests {
    private func makeBackend() -> ServerBackend {
        ServerBackend(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("server-manager-tools-\(UUID().uuidString)", isDirectory: true))
    }

    @Test
    func listToolEmptyReturnsEmptyResultText() async throws {
        let tool = ServerListTool(backend: makeBackend())
        let result = try await tool.execute(arguments: [:])
        #expect(result == "No servers configured.")
    }

    @Test
    func listToolRendersConfiguredServers() async throws {
        let backend = makeBackend()
        try await backend.add(ServerConfig(name: "web-01", host: "10.0.0.1", user: "deploy", group: "Prod"))
        let tool = ServerListTool(backend: backend)
        let result = try await tool.execute(arguments: [:])
        #expect(result.contains("web-01"))
        #expect(result.contains("10.0.0.1:22"))
        #expect(result.contains("Prod"))
    }

    @Test
    func statusToolMissingArgumentThrows() async throws {
        let tool = ServerStatusTool(backend: makeBackend())
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: [:])
        }
    }

    @Test
    func statusToolUnknownServerThrows() async throws {
        let tool = ServerStatusTool(backend: makeBackend())
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("does-not-exist")])
        }
    }

    @Test
    func statusToolRiskLevelIsMedium() {
        let tool = ServerStatusTool(backend: makeBackend())
        #expect(tool.permissionRiskLevel(arguments: [:]) == .medium)
        #expect(ServerListTool(backend: makeBackend()).permissionRiskLevel(arguments: [:]) == .safe)
    }
}