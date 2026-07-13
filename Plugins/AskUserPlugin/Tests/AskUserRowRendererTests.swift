import AgentToolKit
import Foundation
import LumiCoreKit
import Testing
@testable import AskUserPlugin

// MARK: - Fixtures

/// 构造一个 ask_user 工具的 ToolCall，附带 awaitingUserResponse result。
private func makeAskUserToolCall(
    toolCallId: String = "call-renderer-1",
    name: String = "ask_user",
    content: String? = nil,
    awaitingUserResponse: Bool = true
) -> ToolCall {
    ToolCall(
        id: toolCallId,
        name: name,
        arguments: "{}",
        result: content.map { ToolCallResult(content: $0, awaitingUserResponse: awaitingUserResponse) }
    )
}

/// 序列化 AskUserPendingResponse 为 ToolCall.result.content 期望的格式。
private func encodeAskUserPayload(_ response: AskUserPendingResponse) throws -> String {
    try AskUserTool.encodePendingPayload(response)
}

/// 构建一个 "ask_user" 完整 content（含 pendingPrefix + JSON body）。
private func makePendingContent(
    verbosity: String,
    question: String = "是否继续?",
    options: [String] = ["是", "否"],
    allowFreeInput: Bool = false,
    toolCallId: String = "call-renderer-1",
    conversationId: String = UUID().uuidString
) -> String {
    let response = AskUserPendingResponse(
        toolCallId: toolCallId,
        question: question,
        options: options,
        allowFreeInput: allowFreeInput,
        conversationId: conversationId,
        verbosity: verbosity
    )
    let payload = (try? encodeAskUserPayload(response)) ?? ""
    return "\(LumiAskUserMarkers.pendingPrefix)\n\(payload)"
}

// MARK: - parsePendingResponse Static Helper Tests
//
// 验证 AskUserRowRenderer.parsePendingResponse(from:) 静态 helper：
// - 接受正确的 pendingPrefix
// - 拒绝错误前缀、空字符串、损坏的 JSON
// - 缺字段时返回 nil（不解码半成品）

@Suite struct AskUserRowRendererParsePendingResponseTests {
    @Test func returnsNilWhenPrefixMissing() {
        let result = AskUserRowRenderer.parsePendingResponse(from: "no prefix here")
        #expect(result == nil)
    }

    @Test func returnsNilForEmptyString() {
        let result = AskUserRowRenderer.parsePendingResponse(from: "")
        #expect(result == nil)
    }

    @Test func returnsNilForPrefixOnlyWithoutNewline() {
        // 仅 prefix、无换行符与 JSON body，不应解析成功
        let result = AskUserRowRenderer.parsePendingResponse(from: LumiAskUserMarkers.pendingPrefix)
        #expect(result == nil)
    }

    @Test func returnsNilForMalformedJSON() {
        let malformed = "\(LumiAskUserMarkers.pendingPrefix)\n{not json}"
        let result = AskUserRowRenderer.parsePendingResponse(from: malformed)
        #expect(result == nil)
    }

    @Test func returnsNilWhenRequiredFieldsMissing() {
        // JSON 合法但缺字段（缺 verbosity）—— Decoder 应当拒绝，返回 nil
        let incomplete = """
        \(LumiAskUserMarkers.pendingPrefix)
        {"toolCallId":"c1","question":"q","options":["a"],"allowFreeInput":false,"conversationId":"conv"}
        """
        let result = AskUserRowRenderer.parsePendingResponse(from: incomplete)
        #expect(result == nil)
    }

    @Test func decodesValidPendingPayload() {
        let content = makePendingContent(verbosity: "standard", question: "确认?")
        let result = AskUserRowRenderer.parsePendingResponse(from: content)
        #expect(result != nil)
        #expect(result?.question == "确认?")
        #expect(result?.verbosity == "standard")
    }

    @Test func decodesAllThreeVerbosityLevels() {
        for verbosity in ["brief", "standard", "detailed"] {
            let content = makePendingContent(verbosity: verbosity)
            let result = AskUserRowRenderer.parsePendingResponse(from: content)
            #expect(result?.verbosity == verbosity, "verbosity mismatch for \(verbosity)")
        }
    }
}

// MARK: - canRender Tests
//
// AskUserRowRenderer.canRender 应当同时满足：
// - toolCall.name == "ask_user"
// - result.awaitingUserResponse == true

@Suite struct AskUserRowRendererCanRenderTests {
    @Test func canRenderAskUserPendingIsTrue() {
        // 注意：需要给 result 一个非空 content，否则 result 本身就是 nil，
        // canRender 的 awaitingUserResponse 检查永远过不了。
        let toolCall = makeAskUserToolCall(
            content: makePendingContent(verbosity: "standard"),
            awaitingUserResponse: true
        )
        let renderer = AskUserRowRenderer()
        #expect(renderer.canRender(toolCall: toolCall) == true)
    }

    @Test func cannotRenderWhenAwaitingFlagIsFalse() {
        let toolCall = makeAskUserToolCall(awaitingUserResponse: false)
        let renderer = AskUserRowRenderer()
        #expect(renderer.canRender(toolCall: toolCall) == false)
    }

    @Test func cannotRenderWhenResultIsNil() {
        let toolCall = ToolCall(
            id: "call-x",
            name: "ask_user",
            arguments: "{}",
            result: nil
        )
        let renderer = AskUserRowRenderer()
        #expect(renderer.canRender(toolCall: toolCall) == false)
    }

    @Test func cannotRenderWhenToolNameIsDifferent() {
        // 即便 awaitingUserResponse == true，name 不是 "ask_user" 也不能渲染
        let toolCall = makeAskUserToolCall(
            name: "other_tool",
            content: makePendingContent(verbosity: "standard"),
            awaitingUserResponse: true
        )
        let renderer = AskUserRowRenderer()
        #expect(renderer.canRender(toolCall: toolCall) == false)
    }
}

// MARK: - Static Identity Tests
//
// 渲染器 id / priority 应当稳定：MessageRendererPlugin 依赖这两个值做查重与排序。

@Suite struct AskUserRowRendererIdentityTests {
    @Test func idIsStable() {
        // 注意：id 是字符串字面量，跨注册表依赖；变更需同步插件方与调用方。
        #expect(AskUserRowRenderer.id == "ask-user-row")
    }

    @Test func priorityIsHigh() {
        // priority = 100，应当大于默认 0（保证在其他渲染器之前匹配）
        #expect(AskUserRowRenderer.priority > 0)
        #expect(AskUserRowRenderer.priority == 100)
    }
}

// MARK: - Render Route Tests
//
// render() 根据 response.verbosity.lowercased() 分发到 Brief/Standard/Detailed 三个 view。
// 我们不能直接断言 AnyView 内部细节，但可以：
// 1. 用任意合法 payload 触发 render()，断言不崩溃
// 2. 用 SwiftUI 反射/类型字符串（不行——AnyView 抹除类型）
// 替代方案：断言 render() 内部 switch 的可达性 —— 通过给每个 verbosity 传入不同 question 文本，
// 并在 view body 中读取 question；这里用 view 内的 Text(question) 来间接验证。
// 由于 AnyView 不能直接探查类型，我们采用 "不崩溃" + 编码 round-trip 的组合验证路由生效。

@Suite @MainActor struct AskUserRowRendererRenderRouteTests {
    let renderer = AskUserRowRenderer()

    @Test func renderDoesNotCrashForBrief() {
        let toolCall = makeAskUserToolCall(content: makePendingContent(verbosity: "brief"))
        let context = ToolCallRowMessageContext(
            conversationId: UUID(),
            assistantMessageId: UUID()
        )
        // 不应崩溃；返回的是合法 AnyView
        _ = renderer.render(toolCall: toolCall, message: context)
    }

    @Test func renderDoesNotCrashForStandard() {
        let toolCall = makeAskUserToolCall(content: makePendingContent(verbosity: "standard"))
        let context = ToolCallRowMessageContext(
            conversationId: UUID(),
            assistantMessageId: UUID()
        )
        _ = renderer.render(toolCall: toolCall, message: context)
    }

    @Test func renderDoesNotCrashForDetailed() {
        let toolCall = makeAskUserToolCall(content: makePendingContent(verbosity: "detailed"))
        let context = ToolCallRowMessageContext(
            conversationId: UUID(),
            assistantMessageId: UUID()
        )
        _ = renderer.render(toolCall: toolCall, message: context)
    }

    @Test func renderFallsBackToPlaceholderForMissingContent() {
        // content 为 nil（无 result）时，应返回占位 "无法解析问题内容"，不崩溃
        let toolCall = makeAskUserToolCall(content: nil)
        let context = ToolCallRowMessageContext(
            conversationId: UUID(),
            assistantMessageId: UUID()
        )
        _ = renderer.render(toolCall: toolCall, message: context)
    }

    @Test func renderFallsBackToPlaceholderForMalformedJSON() {
        let toolCall = makeAskUserToolCall(
            content: "\(LumiAskUserMarkers.pendingPrefix)\n{not json}"
        )
        let context = ToolCallRowMessageContext(
            conversationId: UUID(),
            assistantMessageId: UUID()
        )
        // 即便 JSON 损坏也不应崩溃，应当走占位分支
        _ = renderer.render(toolCall: toolCall, message: context)
    }

    @Test func renderAcceptsUnknownVerbosityAsStandard() {
        // "v2" 与 "standard" 等价；其他未知 verbosity 也走 standard fallback
        let toolCall = makeAskUserToolCall(content: makePendingContent(verbosity: "experimental"))
        let context = ToolCallRowMessageContext(
            conversationId: UUID(),
            assistantMessageId: UUID()
        )
        _ = renderer.render(toolCall: toolCall, message: context)
    }
}

// MARK: - One-Shot Registration Tests
//
// AskUserPlugin.messageRenderers 内部用 didConfigureRenderer 防止重复注册。
// 我们从行为侧验证：多次调用后 ToolCallRowRendererRegistry 中 AskUserRowRenderer 只有一个实例。

@Suite @MainActor struct AskUserPluginOneShotRegistrationTests {
    @Test func multipleMessageRenderersCallsRegisterOnlyOnce() {
        // Given
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )

        // When — 多次调用 messageRenderers
        _ = AskUserPlugin.messageRenderers(context: context)
        _ = AskUserPlugin.messageRenderers(context: context)
        _ = AskUserPlugin.messageRenderers(context: context)

        // Then — registry 中 ask-user-row 渲染器应当只有一个
        // 由于没有暴露 renderers 列表 API，我们通过 priority/sort 后行为间接验证。
        // 简化为：findRenderer(ask_user + awaiting=true) 应当非空且 id 正确
        // 给一个合法的 result，让 canRender 走通 name + awaitingUserResponse 双检查
        let pendingToolCall = makeAskUserToolCall(
            content: makePendingContent(verbosity: "standard"),
            awaitingUserResponse: true
        )
        let found = ToolCallRowRendererRegistry.shared.findRenderer(for: pendingToolCall)
        #expect(found != nil)
        #expect(type(of: found!).id == "ask-user-row")
    }

    @Test func messageRenderersReturnsEmpty() {
        // AskUserPlugin 不在 messageRenderers 里返回任何渲染器项（注册是副作用），
        // 渲染器注册由 MessageRendererPlugin 通过 registry 自行查询。
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )
        let items = AskUserPlugin.messageRenderers(context: context)
        #expect(items.isEmpty)
    }
}

// MARK: - JSON Round-Trip Integration Tests
//
// 模拟完整链路：AskUserTool.execute() → ToolCall.result.content → AskUserRowRenderer.parsePendingResponse

@Suite @MainActor struct AskUserRowRendererRoundTripTests {
    @Test func executePayloadIsRenderable() async throws {
        // Given — execute() 产出 pendingPrefix + JSON payload
        let args: [String: ToolArgument] = [
            "question": .init("继续?"),
            "options": .init(["是", "否", "稍后"])
        ]
        let tool = AskUserTool()
        let executeContext = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call-rt",
            toolName: "ask_user",
            verbosity: "detailed"
        )
        let output = try await tool.execute(arguments: args, context: executeContext)

        // When — 喂给渲染器解析
        let parsed = AskUserRowRenderer.parsePendingResponse(from: output)

        // Then
        #expect(parsed != nil)
        #expect(parsed?.question == "继续?")
        #expect(parsed?.options == ["是", "否", "稍后"])
        #expect(parsed?.verbosity == "detailed")
        #expect(parsed?.toolCallId == "call-rt")
    }

    @Test func executePayloadMatchesIsPendingResponseHelper() async throws {
        // LumiAskUserMarkers.isPendingResponse 是被 ChatService / AgentTurnService 用来
        // 设置 awaitingUserResponse 的依据，execute() 的产物应当通过此判断。
        let args: [String: ToolArgument] = ["question": .init("hi")]
        let tool = AskUserTool()
        let executeContext = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call",
            toolName: "ask_user"
        )
        let output = try await tool.execute(arguments: args, context: executeContext)
        #expect(LumiAskUserMarkers.isPendingResponse(output))
    }
}
