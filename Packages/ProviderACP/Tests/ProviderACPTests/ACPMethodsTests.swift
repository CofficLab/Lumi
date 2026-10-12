import XCTest
@testable import ProviderACP

final class ACPMethodsTests: XCTestCase {
    // MARK: - initialize 响应（Agent 视角）

    func testDecodeInitializeResult() throws {
        // 文档样例：initialize 响应
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 0,
         "result": {
           "protocolVersion": 1,
           "agentCapabilities": {
             "loadSession": true,
             "promptCapabilities": { "image": true, "audio": true, "embeddedContext": true },
             "mcpCapabilities": { "http": true, "sse": true }
           },
           "agentInfo": { "name": "my-agent", "title": "My Agent", "version": "1.0.0" },
           "authMethods": []
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .response(_, let result) = message else {
            return XCTFail("应为 response")
        }
        let decoded: ACPInitializeResult = try result!.decoded()
        XCTAssertEqual(decoded.protocolVersion, 1)
        XCTAssertEqual(decoded.agentCapabilities.loadSession, true)
        XCTAssertEqual(decoded.agentCapabilities.promptCapabilities?.image, true)
        XCTAssertEqual(decoded.agentCapabilities.promptCapabilities?.embeddedContext, true)
        XCTAssertEqual(decoded.agentCapabilities.mcpCapabilities?.http, true)
        XCTAssertEqual(decoded.agentCapabilities.mcpCapabilities?.sse, true)
        XCTAssertEqual(decoded.agentInfo?.name, "my-agent")
        XCTAssertEqual(decoded.authMethods, [])
    }

    func testDecodeMinimalAgentCapabilities() throws {
        // 能力缺省：所有字段视为不支持/不声明
        let json = """
        { "jsonrpc": "2.0", "id": 0, "result": { "protocolVersion": 1, "agentCapabilities": { "loadSession": false } } }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .response(_, let result) = message else {
            return XCTFail("应为 response")
        }
        let decoded: ACPInitializeResult = try result!.decoded()
        XCTAssertEqual(decoded.agentCapabilities.loadSession, false)
        XCTAssertNil(decoded.agentCapabilities.promptCapabilities)
        XCTAssertNil(decoded.agentCapabilities.mcpCapabilities)
        XCTAssertNil(decoded.agentCapabilities.auth)
    }

    func testDecodeSessionCapabilities() throws {
        // 文档样例：resume / close 能力
        let json = """
        { "jsonrpc": "2.0", "id": 0, "result": { "protocolVersion": 1, "agentCapabilities": { "sessionCapabilities": { "resume": {}, "close": {} } } } }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .response(_, let result) = message else {
            return XCTFail("应为 response")
        }
        let decoded: ACPInitializeResult = try result!.decoded()
        XCTAssertNotNil(decoded.agentCapabilities.sessionCapabilities?.resume)
        XCTAssertNotNil(decoded.agentCapabilities.sessionCapabilities?.close)
    }

    // MARK: - session/new（含 MCP server 配置）

    func testDecodeSessionNewParamsWithStdioMCPServer() throws {
        // 文档样例：stdio MCP server
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 1,
         "method": "session/new",
         "params": {
           "cwd": "/home/user/project",
           "mcpServers": [
             { "name": "filesystem", "command": "/path/to/mcp-server", "args": ["--stdio"], "env": [] }
           ]
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .request(_, let method, let params) = message else {
            return XCTFail("应为 request")
        }
        XCTAssertEqual(method, ACPMethod.sessionNew)
        let decoded: ACPSessionNewParams = try params!.decoded()
        XCTAssertEqual(decoded.cwd, "/home/user/project")
        let server = try XCTUnwrap(decoded.mcpServers?.first)
        guard case .stdio(let name, let command, let args, let env) = server else {
            return XCTFail("应为 stdio")
        }
        XCTAssertEqual(name, "filesystem")
        XCTAssertEqual(command, "/path/to/mcp-server")
        XCTAssertEqual(args, ["--stdio"])
        XCTAssertEqual(env, [])
    }

    func testDecodeSessionNewParamsWithHTTPMCPServer() throws {
        // 文档样例：HTTP MCP server
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 1,
         "method": "session/new",
         "params": {
           "cwd": "/home/user/project",
           "mcpServers": [
             { "type": "http", "name": "api-server", "url": "https://api.example.com/mcp", "headers": [ { "name": "Authorization", "value": "Bearer token123" } ] }
           ]
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .request(_, _, let params) = message else {
            return XCTFail("应为 request")
        }
        let decoded: ACPSessionNewParams = try params!.decoded()
        let server = try XCTUnwrap(decoded.mcpServers?.first)
        guard case .http(let name, let url, let headers) = server else {
            return XCTFail("应为 http")
        }
        XCTAssertEqual(name, "api-server")
        XCTAssertEqual(url, "https://api.example.com/mcp")
        XCTAssertEqual(headers.first?.name, "Authorization")
        XCTAssertEqual(headers.first?.value, "Bearer token123")
    }

    // MARK: - session/prompt

    func testDecodePromptParams() throws {
        // 文档样例：session/prompt
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 2,
         "method": "session/prompt",
         "params": {
           "sessionId": "sess_abc123def456",
           "prompt": [
             { "type": "text", "text": "Can you analyze this code for potential issues?" },
             { "type": "resource", "resource": { "uri": "file:///home/user/project/main.py", "mimeType": "text/x-python", "text": "def process_data(items):\\n for item in items:\\n  print(item)" } }
           ]
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .request(_, let method, let params) = message else {
            return XCTFail("应为 request")
        }
        XCTAssertEqual(method, ACPMethod.sessionPrompt)
        let decoded: ACPPromptParams = try params!.decoded()
        XCTAssertEqual(decoded.sessionId.rawValue, "sess_abc123def456")
        XCTAssertEqual(decoded.prompt.count, 2)
        guard case .text(let first, _) = decoded.prompt[0] else {
            return XCTFail("首个提示应为 text")
        }
        XCTAssertEqual(first, "Can you analyze this code for potential issues?")
        guard case .resource(let resource, _) = decoded.prompt[1] else {
            return XCTFail("第二个提示应为 resource")
        }
        XCTAssertEqual(resource.uri, "file:///home/user/project/main.py")
    }

    func testEncodePromptResult() throws {
        let message = try ACPMessage.makeResponse(id: .number(2), result: ACPPromptResult(stopReason: .endTurn))
        let data = try message.encodedData()
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"stopReason\":\"end_turn\""))
    }

    // MARK: - session/cancel 通知

    func testDecodeCancelNotification() throws {
        let json = """
        { "jsonrpc": "2.0", "method": "session/cancel", "params": { "sessionId": "sess_abc123def456" } }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .notification(let method, let params) = message else {
            return XCTFail("应为 notification")
        }
        XCTAssertEqual(method, ACPMethod.sessionCancel)
        let decoded: ACPCancelParams = try params!.decoded()
        XCTAssertEqual(decoded.sessionId.rawValue, "sess_abc123def456")
    }

    // MARK: - session/request_permission

    func testDecodeRequestPermission() throws {
        // 文档样例
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 5,
         "method": "session/request_permission",
         "params": {
           "sessionId": "sess_abc123def456",
           "toolCall": { "toolCallId": "call_001" },
           "options": [
             { "optionId": "allow-once", "name": "Allow once", "kind": "allow_once" },
             { "optionId": "reject-once", "name": "Reject", "kind": "reject_once" }
           ]
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .request(_, let method, let params) = message else {
            return XCTFail("应为 request")
        }
        XCTAssertEqual(method, ACPMethod.sessionRequestPermission)
        let decoded: ACPRequestPermissionParams = try params!.decoded()
        XCTAssertEqual(decoded.sessionId.rawValue, "sess_abc123def456")
        XCTAssertEqual(decoded.toolCall.toolCallId, "call_001")
        XCTAssertEqual(decoded.options.count, 2)
        XCTAssertEqual(decoded.options[0].optionId, "allow-once")
        XCTAssertEqual(decoded.options[0].kind, .allowOnce)
        XCTAssertEqual(decoded.options[1].kind, .rejectOnce)
    }

    func testDecodePermissionResponseSelected() throws {
        // 文档样例：用户选择 allow-once
        let json = """
        { "jsonrpc": "2.0", "id": 5, "result": { "outcome": { "outcome": "selected", "optionId": "allow-once" } } }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .response(_, let result) = message else {
            return XCTFail("应为 response")
        }
        let decoded: ACPRequestPermissionResult = try result!.decoded()
        XCTAssertEqual(decoded.outcome, .selected(optionId: "allow-once"))
    }

    func testDecodePermissionResponseCancelled() throws {
        let json = """
        { "jsonrpc": "2.0", "id": 5, "result": { "outcome": { "outcome": "cancelled" } } }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .response(_, let result) = message else {
            return XCTFail("应为 response")
        }
        let decoded: ACPRequestPermissionResult = try result!.decoded()
        XCTAssertEqual(decoded.outcome, .cancelled)
    }

    // MARK: - fs 方法

    func testDecodeReadTextFile() throws {
        // 文档样例
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 3,
         "method": "fs/read_text_file",
         "params": {
           "sessionId": "sess_abc123def456",
           "path": "/home/user/project/src/main.py",
           "line": 10,
           "limit": 50
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .request(_, let method, let params) = message else {
            return XCTFail("应为 request")
        }
        XCTAssertEqual(method, ACPMethod.fsReadTextFile)
        let decoded: ACPReadTextFileParams = try params!.decoded()
        XCTAssertEqual(decoded.path, "/home/user/project/src/main.py")
        XCTAssertEqual(decoded.line, 10)
        XCTAssertEqual(decoded.limit, 50)
    }

    func testDecodeWriteTextFile() throws {
        // 文档样例
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 4,
         "method": "fs/write_text_file",
         "params": {
           "sessionId": "sess_abc123def456",
           "path": "/home/user/project/config.json",
           "content": "{\\n \\"debug\\": true,\\n \\"version\\": \\"1.0.0\\"\\n}"
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .request(_, let method, let params) = message else {
            return XCTFail("应为 request")
        }
        XCTAssertEqual(method, ACPMethod.fsWriteTextFile)
        let decoded: ACPWriteTextFileParams = try params!.decoded()
        XCTAssertEqual(decoded.path, "/home/user/project/config.json")
        XCTAssertEqual(decoded.content, "{\n \"debug\": true,\n \"version\": \"1.0.0\"\n}")
    }

    func testEncodeReadTextFileResponse() throws {
        let message = try ACPMessage.makeResponse(
            id: .number(3),
            result: ACPReadTextFileResult(content: "def hello_world():\n print('Hello, world!')\n")
        )
        let data = try message.encodedData()
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"content\":\"def hello_world():"))
    }
}
