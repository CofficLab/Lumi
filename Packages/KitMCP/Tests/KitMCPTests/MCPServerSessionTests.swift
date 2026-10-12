import Foundation
import MCP
import Testing
@testable import KitMCP

@Suite("MCPServerSession")
struct MCPServerSessionTests {
    /// 用 InMemoryTransport 在进程内构造一个真正的 MCP Server（mock）。
    /// 返回客户端侧 transport，以及可选的服务器停止回调。
    private func makeMockServer() async throws -> MCPPreparedTransport {
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()

        let server = Server(name: "MockServer", version: "1.0.0")

        try await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [
                Tool(
                    name: "echo",
                    title: "Echo",
                    description: "Echo the provided text back",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "text": .object(["type": .string("string")])
                        ]),
                        "required": .array([.string("text")]),
                    ]),
                    annotations: .init(
                        title: nil,
                        readOnlyHint: true,
                        destructiveHint: false,
                        idempotentHint: true,
                        openWorldHint: false
                    )
                ),
                Tool(
                    name: "boom",
                    description: "Always errors",
                    inputSchema: .object([:])
                ),
            ])
        }

        try await server.withMethodHandler(CallTool.self) { parameters in
            if parameters.name == "boom" {
                return CallTool.Result(
                    content: [.text(text: "failed", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            let text = parameters.arguments?["text"]?.stringValue ?? ""
            return CallTool.Result(
                content: [.text(text: "echo: \(text)", annotations: nil, _meta: nil)],
                isError: false
            )
        }

        try await server.start(transport: serverTransport)
        return MCPPreparedTransport(transport: clientTransport)
    }

    private func makeSession(prepared: MCPPreparedTransport) -> MCPServerSession {
        let config = MCPServerConfig(
            name: "Mock",
            command: "/bin/echo",
            arguments: []
        )
        return MCPServerSession(config: config, prepare: { _ in prepared })
    }

    @Test("连接后列出工具并调用")
    func listAndCallTool() async throws {
        let prepared = try await makeMockServer()
        let session = makeSession(prepared: prepared)

        try await session.connect()
        #expect(await session.isConnected)

        let tools = try await session.listTools()
        #expect(tools.count == 2)

        let echo = try #require(tools.first { $0.name == "echo" })
        #expect(echo.title == "Echo")
        #expect(echo.readOnlyHint == true)
        #expect(echo.destructiveHint == false)
        #expect(echo.description?.contains("Echo") == true)
        let schema = try #require(echo.inputSchemaDictionary())
        #expect(schema["type"] as? String == "object")

        let result = try await session.callTool(
            name: "echo",
            arguments: ["text": .string("hi")]
        )
        #expect(result.isError == false)
        #expect(result.text == "echo: hi")

        await session.disconnect()
        #expect(!(await session.isConnected))
    }

    @Test("服务器报错时 isError 透传")
    func errorResult() async throws {
        let prepared = try await makeMockServer()
        let session = makeSession(prepared: prepared)

        try await session.connect()
        let result = try await session.callTool(name: "boom", arguments: [:])
        #expect(result.isError == true)

        await session.disconnect()
    }

    @Test("未连接时调用抛 notConnected")
    func notConnected() async throws {
        let prepared = try await makeMockServer()
        let session = makeSession(prepared: prepared)

        await #expect(throws: MCPClientError.notConnected) {
            _ = try await session.listTools()
        }
        await #expect(throws: MCPClientError.notConnected) {
            _ = try await session.callTool(name: "echo", arguments: [:])
        }
    }

    @Test("重复连接是幂等的")
    func connectIdempotent() async throws {
        let prepared = try await makeMockServer()
        let session = makeSession(prepared: prepared)

        try await session.connect()
        try await session.connect()
        #expect(await session.isConnected)

        await session.disconnect()
    }
}
