import XCTest
@testable import ProviderACP

final class ACPTypesTests: XCTestCase {
    // MARK: - ContentBlock

    func testDecodeTextContent() throws {
        let json = #"{"type":"text","text":"What's the weather like today?"}"#
        let block = try JSONDecoder().decode(ContentBlock.self, from: Data(json.utf8))
        XCTAssertEqual(block, .text("What's the weather like today?"))
    }

    func testDecodeImageContent() throws {
        // 文档样例
        let json = """
        {"type":"image","mimeType":"image/png","data":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB..."}
        """
        let block = try JSONDecoder().decode(ContentBlock.self, from: Data(json.utf8))
        XCTAssertEqual(
            block,
            .image(mimeType: "image/png", data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB...", uri: nil, annotations: nil)
        )
    }

    func testDecodeAudioContent() throws {
        let json = """
        {"type":"audio","mimeType":"audio/wav","data":"UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAAB..."}
        """
        let block = try JSONDecoder().decode(ContentBlock.self, from: Data(json.utf8))
        XCTAssertEqual(
            block,
            .audio(mimeType: "audio/wav", data: "UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAAB...", annotations: nil)
        )
    }

    func testDecodeResourceContent() throws {
        // 文档样例：session/prompt 中的 resource
        let json = """
        {
         "type": "resource",
         "resource": {
           "uri": "file:///home/user/project/main.py",
           "mimeType": "text/x-python",
           "text": "def process_data(items):\\n for item in items:\\n  print(item)"
         }
        }
        """
        let block = try JSONDecoder().decode(ContentBlock.self, from: Data(json.utf8))
        guard case .resource(let resource, _) = block else {
            return XCTFail("应为 resource")
        }
        XCTAssertEqual(resource.uri, "file:///home/user/project/main.py")
        XCTAssertEqual(resource.mimeType, "text/x-python")
        XCTAssertEqual(resource.text, "def process_data(items):\n for item in items:\n  print(item)")
        XCTAssertNil(resource.blob)
    }

    func testDecodeResourceLink() throws {
        let json = """
        {"type":"resource_link","uri":"file:///home/user/document.pdf","name":"document.pdf","mimeType":"application/pdf","size":1024000}
        """
        let block = try JSONDecoder().decode(ContentBlock.self, from: Data(json.utf8))
        XCTAssertEqual(
            block,
            .resourceLink(uri: "file:///home/user/document.pdf", name: "document.pdf", mimeType: "application/pdf", title: nil, description: nil, size: 1024000, annotations: nil)
        )
    }

    func testContentBlockRoundTrip() throws {
        let original: [ContentBlock] = [
            .text("hello"),
            .resource(EmbeddedResource(uri: "file:///a.py", text: "x = 1", mimeType: "text/x-python"), annotations: nil),
            .resourceLink(uri: "file:///b.pdf", name: "b.pdf", mimeType: "application/pdf", title: nil, description: nil, size: nil, annotations: nil),
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([ContentBlock].self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Plan

    func testDecodePlanUpdate() throws {
        // 文档样例：plan 更新
        let json = """
        {
         "sessionUpdate": "plan",
         "entries": [
           { "content": "Check for syntax errors", "priority": "high", "status": "pending" },
           { "content": "Identify potential type issues", "priority": "medium", "status": "pending" }
         ]
        }
        """
        let update = try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
        guard case .plan(let entries) = update else {
            return XCTFail("应为 plan")
        }
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].content, "Check for syntax errors")
        XCTAssertEqual(entries[0].priority, .high)
        XCTAssertEqual(entries[0].status, .pending)
        XCTAssertEqual(entries[1].priority, .medium)
    }

    // MARK: - Tool Call

    func testDecodeToolCall() throws {
        // 文档样例：tool_call 通知载荷
        let json = """
        {
         "sessionUpdate": "tool_call",
         "toolCallId": "call_001",
         "title": "Reading configuration file",
         "kind": "read",
         "status": "pending"
        }
        """
        let update = try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
        guard case .toolCall(let tc) = update else {
            return XCTFail("应为 toolCall")
        }
        XCTAssertEqual(tc.toolCallId, "call_001")
        XCTAssertEqual(tc.title, "Reading configuration file")
        XCTAssertEqual(tc.kind, .read)
        XCTAssertEqual(tc.status, .pending)
    }

    func testDecodeToolCallUpdateWithDiff() throws {
        // 文档样例：tool_call_update + diff 内容
        let json = """
        {
         "sessionUpdate": "tool_call_update",
         "toolCallId": "call_001",
         "status": "in_progress",
         "content": [
           { "type": "content", "content": { "type": "text", "text": "Found 3 configuration files..." } }
         ]
        }
        """
        let update = try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
        guard case .toolCallUpdate(let tc) = update else {
            return XCTFail("应为 toolCallUpdate")
        }
        XCTAssertEqual(tc.toolCallId, "call_001")
        XCTAssertEqual(tc.status, .inProgress)
        XCTAssertEqual(tc.title, nil)
        let content = try XCTUnwrap(tc.content)
        guard case .content(let block) = content[0] else {
            return XCTFail("应为 content 类型")
        }
        XCTAssertEqual(block, .text("Found 3 configuration files..."))
    }

    func testDecodeDiffContent() throws {
        let json = """
        {
         "sessionUpdate": "tool_call_update",
         "toolCallId": "call_002",
         "status": "completed",
         "content": [
           { "type": "diff", "path": "/home/user/project/src/config.json", "oldText": "{\\n \\"debug\\": false\\n}", "newText": "{\\n \\"debug\\": true\\n}" }
         ],
         "locations": [ { "path": "/home/user/project/src/config.json", "line": 42 } ]
        }
        """
        let update = try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
        guard case .toolCallUpdate(let tc) = update else {
            return XCTFail("应为 toolCallUpdate")
        }
        let content = try XCTUnwrap(tc.content)
        guard case .diff(let path, let oldText, let newText) = content[0] else {
            return XCTFail("应为 diff 类型")
        }
        XCTAssertEqual(path, "/home/user/project/src/config.json")
        XCTAssertEqual(oldText, "{\n \"debug\": false\n}")
        XCTAssertEqual(newText, "{\n \"debug\": true\n}")
        XCTAssertEqual(tc.locations?.first?.line, 42)
    }

    func testToolKindEnums() throws {
        XCTAssertEqual(ToolKind.read.rawValue, "read")
        XCTAssertEqual(ToolKind.edit.rawValue, "edit")
        XCTAssertEqual(ToolKind.switchMode.rawValue, "switch_mode")
        XCTAssertEqual(ToolCallStatus.inProgress.rawValue, "in_progress")
    }

    // MARK: - SessionUpdate misc

    func testDecodeCurrentModeUpdate() throws {
        // 文档样例：current_mode_update
        let json = """
        { "sessionUpdate": "current_mode_update", "modeId": "code" }
        """
        let update = try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
        XCTAssertEqual(update, .currentModeUpdate(modeId: "code"))
    }

    func testDecodeUserMessageChunk() throws {
        // 文档样例：session/load 回放
        let json = """
        { "sessionUpdate": "user_message_chunk", "content": { "type": "text", "text": "What's the capital of France?" } }
        """
        let update = try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
        XCTAssertEqual(update, .userMessageChunk(.text("What's the capital of France?")))
    }

    func testSessionUpdateRoundTrip() throws {
        let original: SessionUpdate = .toolCall(
            ToolCallUpdate(
                toolCallId: "call_9",
                title: "Running tests",
                kind: .execute,
                status: .inProgress,
                content: [.terminal(terminalId: "term_xyz789")]
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionUpdate.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - StopReason

    func testStopReasonRawValues() throws {
        XCTAssertEqual(StopReason.endTurn.rawValue, "end_turn")
        XCTAssertEqual(StopReason.maxTokens.rawValue, "max_tokens")
        XCTAssertEqual(StopReason.maxTurnRequests.rawValue, "max_turn_requests")
        XCTAssertEqual(StopReason.refusal.rawValue, "refusal")
        XCTAssertEqual(StopReason.cancelled.rawValue, "cancelled")
    }
}
