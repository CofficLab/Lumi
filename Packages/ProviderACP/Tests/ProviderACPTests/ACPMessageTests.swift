import XCTest
@testable import ProviderACP

final class ACPMessageTests: XCTestCase {
    func testDecodeRequest() throws {
        // 文档样例：initialize 请求
        let json = """
        {
         "jsonrpc": "2.0",
         "id": 0,
         "method": "initialize",
         "params": {
           "protocolVersion": 1,
           "clientCapabilities": { "fs": { "readTextFile": true, "writeTextFile": true }, "terminal": true },
           "clientInfo": { "name": "my-client", "title": "My Client", "version": "1.0.0" }
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .request(let id, let method, let params) = message else {
            return XCTFail("应为 request，实际：\(message)")
        }
        XCTAssertEqual(id, .number(0))
        XCTAssertEqual(method, "initialize")
        let decoded: ACPInitializeParams = try XCTUnwrap(params?.decoded())
        XCTAssertEqual(decoded.protocolVersion, 1)
        XCTAssertEqual(decoded.clientCapabilities.fs?.readTextFile, true)
        XCTAssertEqual(decoded.clientCapabilities.fs?.writeTextFile, true)
        XCTAssertEqual(decoded.clientCapabilities.terminal, true)
        XCTAssertEqual(decoded.clientInfo?.name, "my-client")
        XCTAssertEqual(decoded.clientInfo?.title, "My Client")
    }

    func testEncodeRequestRoundTrip() throws {
        let params = ACPInitializeParams(
            protocolVersion: 1,
            clientCapabilities: ACPClientCapabilities(
                fs: ACPFSClientCapabilities(readTextFile: true, writeTextFile: true),
                terminal: true
            ),
            clientInfo: ACPImplementationInfo(name: "lumi", title: "Lumi", version: "5.17.0")
        )
        let message = try ACPMessage.makeRequest(id: 0, method: ACPMethod.initialize, params: params)
        let data = try message.encodedData()
        let decoded = try ACPMessage.decode(data)
        XCTAssertEqual(decoded, message)
    }

    func testDecodeResponseWithResult() throws {
        // 文档样例：session/new 响应
        let json = """
        { "jsonrpc": "2.0", "id": 1, "result": { "sessionId": "sess_abc123def456" } }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .response(let id, let result) = message else {
            return XCTFail("应为 response")
        }
        XCTAssertEqual(id, .number(1))
        let decoded: ACPSessionNewResult = try XCTUnwrap(result?.decoded())
        XCTAssertEqual(decoded.sessionId.rawValue, "sess_abc123def456")
    }

    func testDecodeNullResult() throws {
        // 文档样例：fs/write_text_file 成功响应 result 为 null
        let json = """
        { "jsonrpc": "2.0", "id": 4, "result": null }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .response(_, let result) = message else {
            return XCTFail("应为 response")
        }
        XCTAssertEqual(result, .null)
    }

    func testDecodeErrorResponse() throws {
        let json = """
        { "jsonrpc": "2.0", "id": 2, "error": { "code": -32602, "message": "Invalid params" } }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .error(let id, let error) = message else {
            return XCTFail("应为 error")
        }
        XCTAssertEqual(id, .number(2))
        XCTAssertEqual(error.code, -32602)
        XCTAssertEqual(error.message, "Invalid params")
    }

    func testDecodeNotification() throws {
        // 文档样例：session/update 通知（无 id）
        let json = """
        {
         "jsonrpc": "2.0",
         "method": "session/update",
         "params": {
           "sessionId": "sess_abc123def456",
           "update": {
             "sessionUpdate": "agent_message_chunk",
             "content": { "type": "text", "text": "I'll analyze your code for potential issues." }
           }
         }
        }
        """
        let message = try ACPMessage.decode(Data(json.utf8))
        guard case .notification(let method, let params) = message else {
            return XCTFail("应为 notification，实际：\(message)")
        }
        XCTAssertEqual(method, "session/update")
        XCTAssertNil(message.id)
        let update = try XCTUnwrap(params?.decoded(as: ACPSessionUpdateNotification.self))
        XCTAssertEqual(update.sessionId.rawValue, "sess_abc123def456")
        guard case .agentMessageChunk(let block) = update.update else {
            return XCTFail("应为 agentMessageChunk")
        }
        XCTAssertEqual(block, .text("I'll analyze your code for potential issues."))
    }

    func testRejectNonV2Envelope() throws {
        let json = """
        { "jsonrpc": "1.0", "id": 1, "method": "initialize", "params": {} }
        """
        XCTAssertThrowsError(try ACPMessage.decode(Data(json.utf8)))
    }

    func testRejectBareMessage() throws {
        let json = """
        { "jsonrpc": "2.0" }
        """
        XCTAssertThrowsError(try ACPMessage.decode(Data(json.utf8)))
    }
}

/// `session/update` 通知参数容器。
private struct ACPSessionUpdateNotification: Codable, Equatable {
    var sessionId: ACPSessionId
    var update: SessionUpdate
}
