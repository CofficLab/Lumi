import Foundation
import KitLLM

/// UI 测试专用供应商的桩网络。
///
/// ## 为什么桩在传输层而不是供应商层
///
/// 本桩只替换 `LLMNetworkProviding`（最底层的字节传输），**不** override
/// `complete(_:)` / `streamComplete(_:onChunk:)`。因此一次「模型回复」仍然会走完：
///
/// 1. `OpenAICompatibleProviderAdapter.buildStreamingRequestBody` —— 真实请求序列化
/// 2. `VendorAPIService.sendStreamingChatRequest` —— 真实事件分发与重试判定
/// 3. `OpenAICompatibleProviderAdapter.parseStreamChunk` —— 真实 SSE 解析
/// 4. `StreamingAccumulator` —— 真实增量累积与终止判定
///
/// 只有最后一步「字节从哪来」是假的。相比直接返回 `LLMResponse` 的做法，
/// 这层适配器代码是被真实覆盖到的——适配器本身有 bug 时，测试会失败而不是被绕过。
///
/// ## 请求体即契约
///
/// 桩从**真实序列化后的请求体**里读 `model` 字段来决定场景。这一点是有意的：
/// 若适配器把请求体序列化错了，桩会落到 `.unknown` 场景并产出可辨识的输出，
/// 测试因此能区分「桩坏了」和「适配器坏了」，而不是两者一起静默通过。
final class UITestStubNetwork: NSObject, LLMNetworkProviding, @unchecked Sendable {

    private let lock = NSLock()
    private var _lastRequestBody: Data?
    private var _sentEventCount = 0

    /// 桩收到的最后一次请求体，供单测断言请求确实经过真实序列化。
    var lastRequestBody: Data? {
        lock.lock(); defer { lock.unlock() }
        return _lastRequestBody
    }

    /// 最近一次流式响应实际投递的事件数（受 `onEvent` 提前返回影响会小于产出数）。
    var sentEventCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _sentEventCount
    }

    // MARK: - LLMNetworkProviding

    func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        record(body: body)
        let scenario = Self.scenario(in: body)
        // 非流式路径由 `parseResponse` 解析，期望的是普通 JSON completion，
        // 不是 SSE。因此这里把 SSE 事件折叠成等价的单条响应，而不是直接返回 SSE 字节。
        let completion = try Self.completionObject(for: scenario, alreadyAnswered: Self.hasToolResult(body))
        let data = try Self.json(completion)
        return (Data(data.utf8), Self.makeResponse(for: request, streaming: false))
    }

    func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        record(body: body)
        let scenario = Self.scenario(in: body)
        let alreadyAnswered = Self.hasToolResult(body)

        var delivered = 0
        // 慢恢复场景整体放慢：首轮发问、恢复后的收尾都逐段投递，
        // 让「回合中」与「恢复回合中」两个窗口都长于 XCUITest 的轮询周期。
        let isSlowStream = scenario == .slow || scenario == .verySlow || scenario == .askUserYesNoSlow
        for event in try Self.sseEvents(for: scenario, alreadyAnswered: alreadyAnswered) {
            if isSlowStream {
                try await Task.sleep(nanoseconds: UInt64(UITestFixtures.slowChunkDelay * 1_000_000_000))
            }
            guard await onEvent(Data(Self.encode([event]).utf8)) else { break }
            delivered += 1
        }
        // - Important: 必须用 `withLock` 作用域式加锁。`NSLock.lock()` 在 async
        //   上下文中被 Swift 6 明确禁用（存在 await 间隙时锁可能被跨任务释放）。
        lock.withLock {
            _sentEventCount = delivered
        }
    }

    // MARK: - 请求解析

    private static func scenario(in body: Data) -> UITestScenario {
        guard
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            let model = object["model"] as? String,
            let scenario = UITestScenario(rawValue: model)
        else {
            return .unknown
        }
        return scenario
    }

    /// 请求体里是否已包含工具结果（`role=tool` 消息）。
    ///
    /// 这是 ask_user 两段式响应的判据：用户回答后，AgentLoop 会补一条
    /// `role=tool` 消息再发起第二轮请求（见 `AgentLoopManager.resumeTurn`
    /// 中的 `insertToolResultMessage`）。因此「有没有 tool 消息」精确等价于
    /// 「用户是否已经回答了这次提问」——不需要桩自己维护任何跨请求状态。
    ///
    /// - Note: 不能只看请求次数。真实 App 里同一会话可能先跑别的回合
    ///   （用户手动发消息），用请求序号判定会把无关请求误判成第二轮。
    ///   读请求体是唯一无状态的可靠信号。
    private static func hasToolResult(_ body: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let messages = object["messages"] as? [Any] else {
            return false
        }
        return messages.contains { ($0 as? [String: Any])?["role"] as? String == "tool" }
    }

    private func record(body: Data) {
        lock.lock(); defer { lock.unlock() }
        _lastRequestBody = body
    }

    private static func makeResponse(for request: URLRequest, streaming: Bool) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://ui-test.invalid/v1/chat/completions")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": streaming ? "text/event-stream" : "application/json"]
        )!
    }

    /// 非流式响应体：把 SSE 序列折叠成单条 OpenAI completion。
    ///
    /// 与 `sseEvents` 保持同一份语义来源（同一组 fixture 常量），
    /// 因此流式与非流式路径产出的正文一定一致——`UITestProviderTests` 里
    /// 有一条测试专门锁住这个等价性。
    private static func completionObject(
        for scenario: UITestScenario,
        alreadyAnswered: Bool
    ) throws -> [String: Any] {
        if scenario == .error {
            // 非流式路径的错误形态：OpenAICompatibleResponse 的错误解码分支。
            return ["error": ["message": UITestFixtures.errorMessage, "type": "ui_test_error"]]
        }

        let content: String
        var toolCalls: [[String: Any]]?

        switch scenario {
        case .tool:
            content = ""
            toolCalls = [[
                "id": "call_ui_test_0001",
                "type": "function",
                "function": [
                    "name": UITestFixtures.toolName,
                    "arguments": UITestFixtures.toolArguments,
                ],
            ]]
        case .long:
            content = (1...UITestFixtures.longParagraphCount)
                .map { "段落 \($0)。" }
                .joined()
        case .text, .slow, .verySlow, .unknown:
            content = UITestFixtures.textResponse
        case .error:
            content = ""
        case .askUserYesNo, .askUserChoice, .askUserFreeText, .askUserYesNoSlow:
            if alreadyAnswered {
                content = scenario.askUserFollowUpResponse
            } else {
                content = ""
                toolCalls = [[
                    "id": UITestFixtures.askUserToolCallID,
                    "type": "function",
                    "function": [
                        "name": UITestFixtures.askUserToolName,
                        "arguments": scenario.askUserArguments ?? "{}",
                    ],
                ]]
            }
        case .approval:
            if alreadyAnswered {
                content = UITestFixtures.approvalFollowUpResponse
            } else {
                content = ""
                toolCalls = [[
                    "id": UITestFixtures.approvalToolCallID,
                    "type": "function",
                    "function": [
                        "name": UITestFixtures.approvalToolName,
                        "arguments": UITestFixtures.approvalToolArguments,
                    ],
                ]]
            }
        case .goal:
            if alreadyAnswered {
                content = UITestFixtures.goalFollowUpResponse
            } else {
                content = ""
                toolCalls = [[
                    "id": UITestFixtures.goalToolCallID,
                    "type": "function",
                    "function": [
                        "name": UITestFixtures.goalToolName,
                        "arguments": UITestFixtures.goalArguments,
                    ],
                ]]
            }
        }

        var message: [String: Any] = ["role": "assistant", "content": content]
        if let toolCalls {
            message["tool_calls"] = toolCalls
        }

        let usageValues: [String: Int] = (scenario == .tool || (scenario.isAskUser && !alreadyAnswered) || (scenario.isApproval && !alreadyAnswered) || (scenario.isGoal && !alreadyAnswered))
            ? ["prompt_tokens": 30, "completion_tokens": 10, "total_tokens": 40]
            : ["prompt_tokens": 12, "completion_tokens": 6, "total_tokens": 18]

        return [
            "id": "chatcmpl-ui-test",
            "object": "chat.completion",
            "created": 1_788_000_000,
            "model": scenario.rawValue,
            "choices": [[
                "index": 0,
                "message": message,
                "finish_reason": toolCalls == nil ? "stop" : "tool_calls",
            ]],
            "usage": usageValues,
        ]
    }

    // MARK: - SSE 构造（可被单测直接断言）

    /// 按场景产出 OpenAI SSE 事件块。
    ///
    /// 每个元素是一个完整事件块（含 `data: ` 前缀与结尾空行），
    /// 与 `OpenAICompatibleProviderAdapter.extractSSEData` 期望的输入一致。
    ///
    /// - Parameter alreadyAnswered: 请求体里是否已有 `role=tool` 消息。
    ///   仅对 ask_user 场景有意义——它决定这一轮该「发问」还是「收尾」。
    static func sseEvents(
        for scenario: UITestScenario,
        alreadyAnswered: Bool = false
    ) throws -> [String] {
        switch scenario {
        case .text, .slow, .unknown:
            return try textEvents(model: scenario.rawValue)
        case .tool:
            return try toolEvents(model: scenario.rawValue)
        case .error:
            return [try errorEvent(model: scenario.rawValue)]
        case .long:
            return try longEvents(model: scenario.rawValue)
        case .verySlow:
            return try verySlowEvents(model: scenario.rawValue)
        case .askUserYesNo, .askUserChoice, .askUserFreeText, .askUserYesNoSlow:
            return try askUserEvents(for: scenario, alreadyAnswered: alreadyAnswered)
        case .approval:
            return try approvalEvents(for: scenario, alreadyAnswered: alreadyAnswered)
        case .goal:
            return try goalEvents(for: scenario, alreadyAnswered: alreadyAnswered)
        }
    }

    /// ask_user 场景的两段式响应。
    ///
    /// - 未回答：`ask_user` 工具调用 → AgentLoop 挂起回合 → 界面出现问题卡片。
    /// - 已回答：普通文本 → 回合完成。
    ///
    /// 工具名与参数分片下发，复用与 `.tool` 相同的 arguments 累加路径，
    /// 因此 UI 测试也顺带覆盖了「ask_user 的参数被拆片传输」这一形态。
    private static func askUserEvents(
        for scenario: UITestScenario,
        alreadyAnswered: Bool
    ) throws -> [String] {
        let model = scenario.rawValue

        guard !alreadyAnswered else {
            if scenario == .askUserYesNoSlow {
                return try slowResumeEvents(model: model)
            }
            return [
                try sse(delta: ["content": scenario.askUserFollowUpResponse], model: model),
                try sse(usage: usage(prompt: 30, completion: 10), model: model),
                doneEvent(),
            ]
        }

        let arguments = scenario.askUserArguments ?? "{}"
        let split = arguments.index(
            arguments.startIndex,
            offsetBy: min(12, arguments.count)
        )
        let head = String(arguments[arguments.startIndex..<split])
        let tail = String(arguments[split...])

        return [
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "id": UITestFixtures.askUserToolCallID,
                "type": "function",
                "function": [
                    "name": UITestFixtures.askUserToolName,
                    "arguments": head,
                ],
            ]]], model: model),
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "function": ["arguments": tail],
            ]]], model: model),
            try sse(delta: [:], model: model, finishReason: "tool_calls"),
            try sse(usage: usage(prompt: 30, completion: 10), model: model),
            doneEvent(),
        ]
    }

    /// 慢恢复场景的收尾响应：把正文拆成多段。
    ///
    /// 存在的意义是让「恢复回合中」成为一个可稳定采样的状态：恢复后 AgentLoop
    /// 在跑，但会话状态快照还没收到新事件，用户此时按下停止必须真的停得住。
    private static func slowResumeEvents(model: String) throws -> [String] {
        let text = UITestFixtures.slowResumeFollowUpResponse
        let chunkSize = max(1, text.count / UITestFixtures.slowResumeChunkCount)
        var events: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            events.append(try sse(delta: ["content": String(text[index..<end])], model: model))
            index = end
        }
        events.append(try sse(usage: usage(prompt: 30, completion: 10), model: model))
        events.append(doneEvent())
        return events
    }

    /// 高风险工具授权场景的两段式响应。
    ///
    /// - 未决定：发出 `edit_file` 工具调用 → 回合挂起 → 界面弹出授权卡片。
    /// - 已决定：普通文本 → 回合完成。
    ///
    /// 判据与 ask_user 场景完全一致（请求体里是否已有 `role=tool` 消息），
    /// 因此不需要桩自己维护跨请求状态。
    private static func approvalEvents(
        for scenario: UITestScenario,
        alreadyAnswered: Bool
    ) throws -> [String] {
        let model = scenario.rawValue

        guard !alreadyAnswered else {
            return [
                try sse(delta: ["content": UITestFixtures.approvalFollowUpResponse], model: model),
                try sse(usage: usage(prompt: 30, completion: 10), model: model),
                doneEvent(),
            ]
        }

        let arguments = UITestFixtures.approvalToolArguments
        let split = arguments.index(
            arguments.startIndex,
            offsetBy: min(16, arguments.count)
        )
        let head = String(arguments[arguments.startIndex..<split])
        let tail = String(arguments[split...])

        return [
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "id": UITestFixtures.approvalToolCallID,
                "type": "function",
                "function": [
                    "name": UITestFixtures.approvalToolName,
                    "arguments": head,
                ],
            ]]], model: model),
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "function": ["arguments": tail],
            ]]], model: model),
            try sse(delta: [:], model: model, finishReason: "tool_calls"),
            try sse(usage: usage(prompt: 30, completion: 10), model: model),
            doneEvent(),
        ]
    }

    /// goal 场景的两段式响应。
    ///
    /// - 未执行：发出 `create_goal` 工具调用 → 目标被真正创建 → goal 侧边栏出现。
    /// - 已执行：普通文本 → 回合完成。
    ///
    /// 判据与 ask_user / approval 场景一致：请求体里出现 `role=tool` 消息
    /// （即 `create_goal` 已执行并回传结果）时才收尾。
    private static func goalEvents(
        for scenario: UITestScenario,
        alreadyAnswered: Bool
    ) throws -> [String] {
        let model = scenario.rawValue

        guard !alreadyAnswered else {
            return [
                try sse(delta: ["content": UITestFixtures.goalFollowUpResponse], model: model),
                try sse(usage: usage(prompt: 30, completion: 10), model: model),
                doneEvent(),
            ]
        }

        let arguments = UITestFixtures.goalArguments
        let split = arguments.index(
            arguments.startIndex,
            offsetBy: min(16, arguments.count)
        )
        let head = String(arguments[arguments.startIndex..<split])
        let tail = String(arguments[split...])

        return [
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "id": UITestFixtures.goalToolCallID,
                "type": "function",
                "function": [
                    "name": UITestFixtures.goalToolName,
                    "arguments": head,
                ],
            ]]], model: model),
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "function": ["arguments": tail],
            ]]], model: model),
            try sse(delta: [:], model: model, finishReason: "tool_calls"),
            try sse(usage: usage(prompt: 30, completion: 10), model: model),
            doneEvent(),
        ]
    }

    /// 文本场景：分段正文 + usage-only + `[DONE]`。
    private static func textEvents(model: String) throws -> [String] {
        var events: [String] = []
        for piece in UITestFixtures.textChunks where !piece.isEmpty {
            events.append(try sse(delta: ["content": piece], model: model))
        }
        events.append(try sse(usage: usage(prompt: 12, completion: 6), model: model))
        events.append(doneEvent())
        return events
    }

    /// 长文本场景：多段正文，用于撑开消息列表。
    private static func longEvents(model: String) throws -> [String] {
        var events: [String] = []
        for index in 1...UITestFixtures.longParagraphCount {
            events.append(try sse(delta: ["content": "段落 \(index)。"], model: model))
        }
        events.append(try sse(usage: usage(prompt: 20, completion: 400), model: model))
        events.append(doneEvent())
        return events
    }

    /// 超长回合场景：多段短正文，配合 `stream` 里的段间 sleep。
    ///
    /// 段数与 `slowChunkDelay` 相乘决定回合总时长（约 12s），
    /// 让 UI 测试能把「回合中」当成一个可稳定采样的状态，
    /// 而不是与 XCUITest 的轮询周期赛跑。
    private static func verySlowEvents(model: String) throws -> [String] {
        var events: [String] = []
        for index in 1...UITestFixtures.verySlowParagraphCount {
            events.append(try sse(delta: ["content": "\(index) "], model: model))
        }
        events.append(try sse(usage: usage(prompt: 20, completion: 30), model: model))
        events.append(doneEvent())
        return events
    }

    /// 工具场景：按 OpenAI 分片协议发两次 tool_call delta，最后 `finish_reason`。
    ///
    /// 第一个 delta 带 `id` + `name` + arguments 首段；第二个只带 arguments 余段。
    /// 这正是 `parseToolCallDelta` → `StreamingAccumulator.upsertToolCall` 的
    /// arguments 累加路径，能覆盖到 arguments 被分片拼接的逻辑。
    private static func toolEvents(model: String) throws -> [String] {
        let id = "call_ui_test_0001"
        let arguments = UITestFixtures.toolArguments
        let split = arguments.index(
            arguments.startIndex,
            offsetBy: min(8, arguments.count)
        )
        let head = String(arguments[arguments.startIndex..<split])
        let tail = String(arguments[split...])

        return [
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "id": id,
                "type": "function",
                "function": [
                    "name": UITestFixtures.toolName,
                    "arguments": head,
                ],
            ]]], model: model),
            try sse(delta: ["tool_calls": [[
                "index": 0,
                "function": ["arguments": tail],
            ]]], model: model),
            try sse(delta: [:], model: model, finishReason: "tool_calls"),
            try sse(usage: usage(prompt: 30, completion: 10), model: model),
            doneEvent(),
        ]
    }

    /// 错误场景：单个携带 `error` 的事件。
    ///
    /// 走 SSE 内的 `{"error":{"message":...}}` 形态而非 HTTP 500，
    /// 这样 `VendorAPIService` 的重试策略（对 5xx 会重试）不会介入，
    /// 错误立即到达 AgentLoop —— 与真实供应商「请求被接受但回复失败」的情形一致。
    private static func errorEvent(model: String) throws -> String {
        let payload: [String: Any] = [
            "error": [
                "message": UITestFixtures.errorMessage,
                "type": "ui_test_error",
            ],
        ]
        return event(try json(payload))
    }

    // MARK: - SSE 基元

    /// 构造一个带 delta 的 `data: {json}` 事件块。
    private static func sse(
        delta: [String: Any],
        model: String,
        finishReason: String? = nil
    ) throws -> String {
        var choice: [String: Any] = ["index": 0, "delta": delta]
        choice["finish_reason"] = finishReason ?? NSNull()
        let payload: [String: Any] = [
            "id": "chatcmpl-ui-test",
            "object": "chat.completion.chunk",
            "created": 1_788_000_000,
            "model": model,
            "choices": [choice],
        ]
        return event(try json(payload))
    }

    /// usage-only 事件：适配器会把它解析成纯 token 统计 chunk。
    private static func sse(usage: [String: Any], model: String) throws -> String {
        let payload: [String: Any] = [
            "id": "chatcmpl-ui-test",
            "object": "chat.completion.chunk",
            "created": 1_788_000_000,
            "model": model,
            "choices": [],
            "usage": usage,
        ]
        return event(try json(payload))
    }

    private static func usage(prompt: Int, completion: Int) -> [String: Any] {
        [
            "prompt_tokens": prompt,
            "completion_tokens": completion,
            "total_tokens": prompt + completion,
        ]
    }

    private static func doneEvent() -> String {
        "data: [DONE]\n\n"
    }

    private static func event(_ json: String) -> String {
        "data: \(json)\n\n"
    }

    private static func encode(_ events: [String]) -> String {
        events.joined()
    }

    private static func json(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw VendorAPIError.requestFailed("UI 测试桩无法编码 JSON")
        }
        return text
    }
}
