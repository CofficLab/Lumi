import Foundation
import Testing
import KitAgentTool
import ProviderToolManager
import ProviderWebServer
@testable import KitWebAPI

// MARK: - Test Doubles

/// 测试用的最小工具实现。
///
/// 用 class 而非 struct：工具执行时需要把收到的参数记录下来供断言，
/// struct 的不可变语义做不到这点。
private final class StubTool: SuperAgentTool, @unchecked Sendable {
    let name: String
    let resultText: String
    var resultImages: [ImageAttachment] = []
    private(set) var receivedArguments: [String: ToolArgument] = [:]

    init(name: String, resultText: String) {
        self.name = name
        self.resultText = resultText
    }

    func description(for language: LanguagePreference) -> String {
        "Stub tool \(name)"
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": ["value": ["type": "string"]],
            "required": ["value"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "调用 \(name)"
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        receivedArguments = arguments
        return resultText
    }

    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        receivedArguments = arguments
        return ToolCallResult(content: resultText, images: resultImages)
    }
}

/// 测试用的工具管理器替身。
@MainActor
private final class StubToolManager: ToolManagerProviding {
    var registeredTools: [String: any SuperAgentTool] = [:]
    var order: [String] = []
    var groups: [(pluginID: String, tools: [any SuperAgentTool])] = []
    var lastExecutedCall: ToolCall?
    var lastExecutedConversationID: UUID?
    var executeResult: ToolCallResult?
    var authorizationDecisionOverride: ToolAuthorizationDecision?
    private(set) var lastAuthorizationConversationID: UUID?

    func authorizationDecision(
        for toolCall: ToolCall,
        conversationID: UUID
    ) -> ToolAuthorizationDecision {
        lastAuthorizationConversationID = conversationID
        return authorizationDecisionOverride ?? .autoApproved
    }

    func allTools() -> [any SuperAgentTool] {
        order.compactMap { registeredTools[$0] }
    }

    func add(_ tool: any SuperAgentTool, pluginID: String) {
        if registeredTools[tool.name] == nil { order.append(tool.name) }
        registeredTools[tool.name] = tool
        groups.removeAll { $0.pluginID == pluginID }
        let existing = groups.first { $0.pluginID == pluginID }?.tools ?? []
        groups.append((pluginID: pluginID, tools: existing + [tool]))
    }

    func remove(id: String) {
        registeredTools.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }

    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] {
        groups
    }

    func tool(named name: String) -> (any SuperAgentTool)? {
        registeredTools[name]
    }

    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        lastExecutedCall = toolCall
        lastExecutedConversationID = conversationID
        if let executeResult { return executeResult }
        // 未指定固定结果时，真实执行工具——这样测试能验证参数确实传到了工具。
        guard let tool = registeredTools[toolCall.name] else {
            return ToolCallResult(content: "Tool not found: \(toolCall.name)", isError: true)
        }
        let arguments = (try? ToolArgumentCoding.decode(toolCall.arguments)) ?? [:]
        do {
            let result = try await tool.executeResult(arguments: arguments)
            return result
        } catch {
            return ToolCallResult(content: error.localizedDescription, isError: true)
        }
    }

    func displayDescription(for toolCall: ToolCall) -> String? {
        toolCall.name
    }

    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? {
        .safe
    }

    func deleteToolCalls(for conversationID: UUID) async {}

    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        []
    }

    func toolCallResult(for toolCallID: String) async -> ToolCallResult? {
        nil
    }
}

// MARK: - JSONValue Tests

@Suite("JSONValue")
struct JSONValueTests {
    @Test("标量值按 JSON 类型转换")
    func convertsScalars() {
        #expect(JSONValue(from: true) == .bool(true))
        #expect(JSONValue(from: 42) == .number(42))
        #expect(JSONValue(from: 3.5) == .number(3.5))
        #expect(JSONValue(from: "text") == .string("text"))
    }

    @Test("非 JSON 类型降级为 null")
    func degradesUnsupportedTypes() {
        #expect(JSONValue(from: Date()) == .null)
    }

    @Test("嵌套结构递归转换")
    func convertsNestedStructures() {
        let value = JSONValue(from: ["a": 1, "b": [true, "x"]])
        #expect(value == .object([
            "a": .number(1),
            "b": .array([.bool(true), .string("x")]),
        ]))
    }

    @Test("往返编解码保持一致")
    func roundTrips() throws {
        let original = JSONValue.object([
            "name": .string("lumi"),
            "count": .number(3),
            "flag": .bool(true),
            "items": .array([.string("a")]),
            "missing": .null,
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == original)
    }

    @Test("anyValue 还原为 JSON 兼容值")
    func restoresAnyValue() {
        let value = JSONValue.object(["a": .number(1), "b": .string("x")])
        let restored = value.anyValue as? [String: Any]
        #expect(restored?["a"] as? Double == 1)
        #expect(restored?["b"] as? String == "x")
    }
}

// MARK: - Argument Encoding Tests

@Suite("工具参数编码")
struct WebToolArgumentEncodingTests {
    @Test("空参数编码为空对象")
    func encodesEmptyArguments() {
        #expect(WebToolBridge.encodeArguments([:]) == "{}")
    }

    @Test("参数编码为 JSON 字符串")
    func encodesArguments() throws {
        let encoded = WebToolBridge.encodeArguments(["path": "/tmp/file.txt", "count": 3])
        // JSON 会把 `/` 转义成 `\/`，因此按解码后的值断言而非原始字符串。
        let decoded = try JSONSerialization.jsonObject(with: Data(encoded.utf8))
        let object = try #require(decoded as? [String: Any])
        #expect(object["path"] as? String == "/tmp/file.txt")
        #expect(object["count"] as? Double == 3)
    }

    @Test("非法 JSON 参数退化为空对象")
    func degradesInvalidArguments() {
        #expect(WebToolBridge.encodeArguments(["bad": Data()]) == "{}")
    }
}

// MARK: - Bridge Tests

@MainActor
@Suite("WebToolBridge")
struct WebToolBridgeTests {
    @Test("列出全部工具及其 schema 与归属插件")
    func listsToolDescriptors() {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "ok"), pluginID: "com.test.fs")
        let bridge = WebToolBridge(toolManager: manager)

        let descriptors = bridge.toolDescriptors()
        #expect(descriptors.count == 1)
        #expect(descriptors.first?.name == "read_file")
        #expect(descriptors.first?.pluginID == "com.test.fs")
        #expect(descriptors.first?.schema == .object([
            "type": .string("object"),
            "properties": .object([
                "value": .object(["type": .string("string")]),
            ]),
            "required": .array([.string("value")]),
        ]))
    }

    @Test("桥接创建后注册的工具，单个查询仍返回真实归属插件")
    func descriptorUsesPluginIDForToolRegisteredLater() throws {
        let manager = StubToolManager()
        let bridge = WebToolBridge(toolManager: manager)

        manager.add(
            StubTool(name: "open_in_cursor", resultText: "ok"),
            pluginID: "com.coffic.lumi.plugin.open-in-cursor"
        )

        let descriptor = try #require(bridge.toolDescriptor(named: "open_in_cursor"))
        #expect(descriptor.pluginID == "com.coffic.lumi.plugin.open-in-cursor")
    }

    @Test("桥接创建后注册的工具，列表仍返回真实归属插件")
    func listUsesPluginIDForToolRegisteredLater() throws {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "ok"), pluginID: "com.test.fs")
        let bridge = WebToolBridge(toolManager: manager)

        manager.add(
            StubTool(name: "open_in_cursor", resultText: "ok"),
            pluginID: "com.coffic.lumi.plugin.open-in-cursor"
        )

        let descriptors = bridge.toolDescriptors()
        let added = try #require(descriptors.first { $0.name == "open_in_cursor" })
        #expect(added.pluginID == "com.coffic.lumi.plugin.open-in-cursor")
        #expect(descriptors.first { $0.name == "read_file" }?.pluginID == "com.test.fs")
    }

    @Test("未知工具返回 nil")
    func returnsNilForUnknownTool() {
        let bridge = WebToolBridge(toolManager: StubToolManager())
        #expect(bridge.toolDescriptor(named: "missing") == nil)
    }

    @Test("调用工具时透传参数与会话")
    func invokesTool() async throws {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "file-content"), pluginID: "com.test.fs")
        let bridge = WebToolBridge(toolManager: manager)

        let conversationID = UUID()
        let result = try await bridge.invoke(
            tool: "read_file",
            arguments: ["path": "/tmp/a.txt"],
            conversationID: conversationID
        )

        #expect(result.tool == "read_file")
        #expect(result.content == "file-content")
        #expect(result.isError == false)
        #expect(manager.lastExecutedConversationID == conversationID)
        #expect(manager.lastExecutedCall?.name == "read_file")
    }

    @Test("调用工具时透传图片附件")
    func passesThroughImageAttachments() async throws {
        let manager = StubToolManager()
        let tool = StubTool(name: "read_image", resultText: "图片已附加到工具结果，可直接查看")
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        tool.resultImages = [
            ImageAttachment(data: png, mimeType: "image/png", fileName: "shot.png")
        ]
        manager.add(tool, pluginID: "builtin.tools")
        let bridge = WebToolBridge(toolManager: manager)

        let result = try await bridge.invoke(
            tool: "read_image",
            arguments: ["path": "/tmp/shot.png"],
            conversationID: UUID()
        )

        #expect(result.isError == false)
        #expect(result.images.count == 1)
        #expect(result.images.first?.data == png)
        #expect(result.images.first?.mimeType == "image/png")
        #expect(result.images.first?.fileName == "shot.png")
    }

    @Test("调用不存在的工具抛出 notFound")
    func throwsNotFoundForUnknownTool() async {
        let bridge = WebToolBridge(toolManager: StubToolManager())
        await #expect(throws: WebAPIError.self) {
            try await bridge.invoke(tool: "missing", arguments: [:], conversationID: UUID())
        }
    }

    @Test("缺少会话上下文时抛出 badRequest")
    func throwsBadRequestWithoutConversation() async {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "ok"), pluginID: "com.test.fs")
        let bridge = WebToolBridge(toolManager: manager)

        await #expect(throws: WebAPIError.self) {
            try await bridge.invoke(tool: "read_file", arguments: [:], conversationID: nil)
        }
    }

    @Test("Chat 会话的策略阻断 HTTP 工具调用")
    func blockedDecisionPreventsExecution() async {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "file-content"), pluginID: "com.test.fs")
        manager.authorizationDecisionOverride = .blocked(
            reason: "Tool execution was blocked because this conversation is in Chat mode."
        )
        let fallback = UUID()
        let bridge = WebToolBridge(toolManager: manager, fallbackConversationID: fallback)

        do {
            _ = try await bridge.invoke(tool: "read_file", arguments: [:], conversationID: nil)
            Issue.record("Chat 会话不应执行工具")
        } catch let error as WebAPIError {
            #expect(error.statusCode == 403)
            #expect(error.code == "forbidden")
            #expect(error.message.contains("Chat mode"))
        } catch {
            Issue.record("应抛出 WebAPIError，实际为 \(error)")
        }
        // 策略判断使用解析后的会话 ID，且工具没有被执行。
        #expect(manager.lastAuthorizationConversationID == fallback)
        #expect(manager.lastExecutedCall == nil)
    }

    @Test("Build 会话中需要用户确认的调用不会经 HTTP 执行")
    func approvalRequiredDecisionPreventsExecution() async {
        let manager = StubToolManager()
        manager.add(StubTool(name: "write_file", resultText: "written"), pluginID: "com.test.fs")
        manager.authorizationDecisionOverride = .requiresUserApproval
        let bridge = WebToolBridge(toolManager: manager)

        do {
            _ = try await bridge.invoke(tool: "write_file", arguments: [:], conversationID: UUID())
            Issue.record("需要用户确认的调用不应经 HTTP 执行")
        } catch let error as WebAPIError {
            #expect(error.statusCode == 403)
            #expect(error.code == "forbidden")
            #expect(error.message.contains("requires user approval"))
        } catch {
            Issue.record("应抛出 WebAPIError，实际为 \(error)")
        }
        #expect(manager.lastExecutedCall == nil)
    }

    @Test("会话解析器优先于缺省会话")
    func prefersResolverOverFallback() async throws {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "ok"), pluginID: "com.test.fs")
        let resolved = UUID()
        let bridge = WebToolBridge(
            toolManager: manager,
            fallbackConversationID: UUID(),
            conversationResolver: { resolved }
        )

        _ = try await bridge.invoke(tool: "read_file", arguments: [:], conversationID: nil)
        #expect(manager.lastExecutedConversationID == resolved)
    }

    @Test("工具执行错误仍返回结果并标记 isError")
    func reportsToolError() async throws {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "ok"), pluginID: "com.test.fs")
        manager.executeResult = ToolCallResult(content: "boom", isError: true)
        let bridge = WebToolBridge(toolManager: manager)

        let result = try await bridge.invoke(tool: "read_file", arguments: [:], conversationID: UUID())
        #expect(result.isError == true)
        #expect(result.content == "boom")
    }
}

// MARK: - Route Tests

@MainActor
@Suite("WebToolRoutes")
struct WebToolRoutesTests {
    @Test("生成三个路由且路径正确")
    func generatesRoutes() {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "ok"), pluginID: "com.test.fs")
        let bridge = WebToolBridge(toolManager: manager)

        let routes = WebToolRoutes.makeRoutes(bridge: bridge)
        #expect(routes.count == 3)
        #expect(routes.contains { $0.method == .get && $0.path == "/api/v1/tools" })
        #expect(routes.contains { $0.method == .get && $0.path == "/api/v1/tools/:name" })
        #expect(routes.contains { $0.method == .post && $0.path == "/api/v1/tools/:name/invoke" })
    }

    @Test("列出路由返回工具数组")
    func listRouteReturnsTools() async throws {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "ok"), pluginID: "com.test.fs")
        let bridge = WebToolBridge(toolManager: manager)

        let routes = WebToolRoutes.makeRoutes(bridge: bridge)
        let listRoute = try #require(routes.first { $0.path == "/api/v1/tools" })

        let response = try await listRoute.handler(
            WebRouteRequest(method: .get, path: "/api/v1/tools")
        )
        #expect(response.statusCode == 200)

        struct Envelope: Decodable {
            struct Item: Decodable {
                let name: String
                let pluginID: String
            }
            let data: [Item]
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: response.body)
        #expect(decoded.data.count == 1)
        #expect(decoded.data.first?.name == "read_file")
        #expect(decoded.data.first?.pluginID == "com.test.fs")
    }

    @Test("查看未知工具抛出 notFound，由服务端映射为 404")
    func unknownToolThrowsNotFound() async throws {
        let manager = StubToolManager()
        let bridge = WebToolBridge(toolManager: manager)
        let routes = WebToolRoutes.makeRoutes(bridge: bridge)
        let detailRoute = try #require(routes.first { $0.path == "/api/v1/tools/:name" })

        // 处理器抛出 `WebAPIError.notFound`；HTTP 层负责把它转成 404 与统一错误体。
        await #expect(throws: WebAPIError.self) {
            try await detailRoute.handler(
                WebRouteRequest(
                    method: .get,
                    path: "/api/v1/tools/missing",
                    pathParameters: ["name": "missing"]
                )
            )
        }

        do {
            _ = try await detailRoute.handler(
                WebRouteRequest(
                    method: .get,
                    path: "/api/v1/tools/missing",
                    pathParameters: ["name": "missing"]
                )
            )
            Issue.record("未知工具应当抛出 notFound")
        } catch let error as WebAPIError {
            #expect(error.statusCode == 404)
            #expect(error.code == "not_found")
        }
    }

    @Test("调用路由执行工具并返回结果")
    func invokeRouteRunsTool() async throws {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "file-content"), pluginID: "com.test.fs")
        let bridge = WebToolBridge(toolManager: manager)
        let routes = WebToolRoutes.makeRoutes(bridge: bridge)
        let invokeRoute = try #require(routes.first { $0.path == "/api/v1/tools/:name/invoke" })

        let body = try JSONSerialization.data(withJSONObject: [
            "arguments": ["path": "/tmp/a.txt"],
            "conversationID": UUID().uuidString,
        ])
        let response = try await invokeRoute.handler(
            WebRouteRequest(
                method: .post,
                path: "/api/v1/tools/read_file/invoke",
                pathParameters: ["name": "read_file"],
                body: body
            )
        )
        #expect(response.statusCode == 200)

        struct Envelope: Decodable {
            struct Item: Decodable {
                let tool: String
                let content: String
                let isError: Bool
            }
            let data: Item
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: response.body)
        #expect(decoded.data.tool == "read_file")
        #expect(decoded.data.content == "file-content")
        #expect(decoded.data.isError == false)

        // 无图片的结果不输出空的 images 字段，保持既有响应形状。
        let raw = try #require(String(data: response.body, encoding: .utf8))
        #expect(!raw.contains("\"images\""))
    }

    @Test("invoke 路由把会话策略拒绝映射为 forbidden")
    func invokeRouteRejectsBlockedConversation() async throws {
        let manager = StubToolManager()
        manager.add(StubTool(name: "read_file", resultText: "file-content"), pluginID: "com.test.fs")
        manager.authorizationDecisionOverride = .blocked(
            reason: "Tool execution was blocked because this conversation is in Chat mode."
        )
        let bridge = WebToolBridge(toolManager: manager)
        let routes = WebToolRoutes.makeRoutes(bridge: bridge)
        let invokeRoute = try #require(routes.first { $0.path == "/api/v1/tools/:name/invoke" })

        let body = try JSONSerialization.data(withJSONObject: [
            "arguments": ["path": "/tmp/a.txt"],
            "conversationID": UUID().uuidString,
        ])
        do {
            _ = try await invokeRoute.handler(
                WebRouteRequest(
                    method: .post,
                    path: "/api/v1/tools/read_file/invoke",
                    pathParameters: ["name": "read_file"],
                    body: body
                )
            )
            Issue.record("Chat 会话不应执行工具")
        } catch let error as WebAPIError {
            #expect(error.statusCode == 403)
            #expect(error.code == "forbidden")
        } catch {
            Issue.record("应抛出 WebAPIError，实际为 \(error)")
        }
        #expect(manager.lastExecutedCall == nil)
    }

    @Test("调用路由的响应携带图片附件字节与元数据")
    func invokeRouteReturnsImageAttachments() async throws {
        let manager = StubToolManager()
        let tool = StubTool(name: "read_image", resultText: "图片已附加")
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        tool.resultImages = [
            ImageAttachment(data: png, mimeType: "image/png", fileName: "shot.png")
        ]
        manager.add(tool, pluginID: "builtin.tools")
        let bridge = WebToolBridge(toolManager: manager)
        let routes = WebToolRoutes.makeRoutes(bridge: bridge)
        let invokeRoute = try #require(routes.first { $0.path == "/api/v1/tools/:name/invoke" })

        let body = try JSONSerialization.data(withJSONObject: [
            "arguments": ["path": "/tmp/shot.png"],
            "conversationID": UUID().uuidString,
        ])
        let response = try await invokeRoute.handler(
            WebRouteRequest(
                method: .post,
                path: "/api/v1/tools/read_image/invoke",
                pathParameters: ["name": "read_image"],
                body: body
            )
        )
        #expect(response.statusCode == 200)

        struct Envelope: Decodable {
            struct Image: Decodable {
                let data: Data
                let mimeType: String
                let fileName: String?
            }
            struct Item: Decodable {
                let images: [Image]?
            }
            let data: Item
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: response.body)
        let image = try #require(decoded.data.images?.first)
        #expect(image.data == png)
        #expect(image.mimeType == "image/png")
        #expect(image.fileName == "shot.png")
    }
}
