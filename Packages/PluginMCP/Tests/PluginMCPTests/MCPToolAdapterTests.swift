import Foundation
import KitAgentTool
import KitMCP
import MCP
import Testing
@testable import PluginMCP

@Suite("MCPToolAdapter")
struct MCPToolAdapterTests {
    /// 用 InMemoryTransport 构造进程内 mock MCP Server。
    /// 返回客户端会话（已连接）与已发现的工具描述。
    private func makeSession() async throws -> (session: MCPServerSession, tools: [MCPToolDescriptor]) {
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()

        let server = Server(name: "MockServer", version: "1.0.0")
        try await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [
                Tool(
                    name: "echo",
                    description: "Echo the provided text back",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object(["text": .object(["type": .string("string")])]),
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
                    name: "write_file",
                    description: "Write content to a file",
                    inputSchema: .object([:]),
                    annotations: .init(
                        title: nil,
                        readOnlyHint: false,
                        destructiveHint: true,
                        idempotentHint: false,
                        openWorldHint: false
                    )
                ),
                Tool(
                    name: "snapshot",
                    description: "Return a screenshot",
                    inputSchema: .object([:]),
                    annotations: .init(
                        title: nil,
                        readOnlyHint: true,
                        destructiveHint: false,
                        idempotentHint: true,
                        openWorldHint: false
                    )
                ),
            ])
        }
        try await server.withMethodHandler(CallTool.self) { parameters in
            switch parameters.name {
            case "echo":
                let text = parameters.arguments?["text"]?.stringValue ?? ""
                return CallTool.Result(
                    content: [.text(text: "echo: \(text)", annotations: nil, _meta: nil)],
                    isError: false
                )
            case "write_file":
                return CallTool.Result(
                    content: [.text(text: "written", annotations: nil, _meta: nil)],
                    isError: false
                )
            case "snapshot":
                let data = Data([0x89, 0x50, 0x4E, 0x47])
                return CallTool.Result(
                    content: [.image(data: data.base64EncodedString(), mimeType: "image/png", annotations: nil, _meta: nil)],
                    isError: false
                )
            default:
                return CallTool.Result(
                    content: [.text(text: "unknown", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
        }
        try await server.start(transport: serverTransport)

        let config = MCPServerConfig(name: "Mock", command: "/bin/echo")
        let session = MCPServerSession(config: config) { _ in
            MCPPreparedTransport(transport: clientTransport)
        }
        try await session.connect()
        let tools = try await session.listTools()
        return (session, tools)
    }

    private func adapter(
        for descriptor: MCPToolDescriptor,
        session: any MCPServerServing,
        policy: MCPPermissionPolicy = MCPPermissionPolicy(),
        override: CommandRiskLevel? = nil
    ) -> MCPToolAdapter {
        MCPToolAdapter(
            serverID: "server-1",
            serverName: "Mock",
            descriptor: descriptor,
            session: session,
            policy: policy,
            riskOverride: override
        )
    }

    @Test("桥接命名空间与 schema 直通")
    func bridgeShape() async throws {
        let (session, tools) = try await makeSession()
        let echo = try #require(tools.first { $0.name == "echo" })
        let adapter = adapter(for: echo, session: session)

        #expect(adapter.name == "server-1.echo")
        #expect(adapter.description(for: .english).contains("Mock"))
        let schema = adapter.inputSchema(for: .english)
        #expect(schema["type"] as? String == "object")
        let properties = schema["properties"] as? [String: Any]
        #expect(properties?["text"] != nil)
    }

    @Test("风险分级：策略判定与用户覆盖")
    func riskLevels() async throws {
        let (session, tools) = try await makeSession()
        let echo = try #require(tools.first { $0.name == "echo" })
        let write = try #require(tools.first { $0.name == "write_file" })

        let policy = MCPPermissionPolicy()
        // echo：注解 readOnlyHint → safe
        #expect(adapter(for: echo, session: session, policy: policy).permissionRiskLevel(arguments: [:]) == .safe)
        // write_file：注解 destructiveHint → high（未在精确表）
        #expect(adapter(for: write, session: session, policy: policy).permissionRiskLevel(arguments: [:]) == .high)
        // 用户覆盖优先
        #expect(adapter(for: write, session: session, policy: policy, override: .medium).permissionRiskLevel(arguments: [:]) == .medium)
    }

    @Test("只读工具声明并行，其余串行")
    func executionCapability() async throws {
        let (session, tools) = try await makeSession()
        let echo = try #require(tools.first { $0.name == "echo" })
        let write = try #require(tools.first { $0.name == "write_file" })

        #expect(adapter(for: echo, session: session).executionCapability == .parallelReadOnly)
        #expect(adapter(for: write, session: session).executionCapability == .serialSideEffect)
    }

    @Test("executeResult 调用回传文本结果")
    func executeText() async throws {
        let (session, tools) = try await makeSession()
        let echo = try #require(tools.first { $0.name == "echo" })
        let adapter = adapter(for: echo, session: session)

        let result = try await adapter.executeResult(
            context: ToolExecutionContext(jobID: "j", conversationID: UUID()),
            arguments: ["text": ToolArgument("hi")]
        )
        #expect(result.isError == false)
        #expect(result.content == "echo: hi")
    }

    @Test("图片结果映射为 ImageAttachment")
    func executeImage() async throws {
        let (session, tools) = try await makeSession()
        let snapshot = try #require(tools.first { $0.name == "snapshot" })
        let adapter = adapter(for: snapshot, session: session)

        let result = try await adapter.executeResult(
            context: ToolExecutionContext(jobID: "j", conversationID: UUID()),
            arguments: [:]
        )
        #expect(result.images.count == 1)
        #expect(result.images.first?.mimeType == "image/png")
    }

    @Test("未连接会话调用报错")
    func notConnected() async throws {
        let config = MCPServerConfig(name: "Mock", command: "/bin/echo")
        let session = MCPServerSession(config: config)
        let adapter = adapter(
            for: MCPToolDescriptor(name: "echo", description: "x"),
            session: session
        )
        await #expect(throws: ToolExecutionError.self) {
            _ = try await adapter.executeResult(
                context: ToolExecutionContext(jobID: "j", conversationID: UUID()),
                arguments: [:]
            )
        }
    }
}
