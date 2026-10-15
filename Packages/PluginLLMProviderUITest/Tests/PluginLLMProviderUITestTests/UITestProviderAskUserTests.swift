import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderUITest

/// 验证 ask_user 桩经**真实**适配器链路后的两段式行为。
///
/// 与 `UITestProviderTests` 同理：桩只替换字节传输，请求序列化、SSE 解析、
/// 增量累积全是生产代码。这里额外锁住「第二轮是否真的走了不同分支」——
/// 分发信号是请求体里的 `role=tool` 消息，因此必须确认经过真实序列化后
/// 该消息确实能到达桩（如果适配器丢掉了它，第二轮会重复发问、界面无限循环）。
@MainActor
@Suite("UI 测试供应商 ask_user 场景")
struct UITestProviderAskUserTests {

    // MARK: - 首轮

    @Test("首轮经真实 SSE 解析后产出完整的 ask_user 工具调用")
    func firstRoundProducesCompleteToolCall() async throws {
        for scenario in askUserScenarios {
            let provider = makeProvider()

            let response = try await provider.streamComplete(request(scenario: scenario)) { _ in }

            let call = try #require(
                response.toolCalls?.first,
                "\(scenario.rawValue) 首轮应产出工具调用"
            )
            #expect(response.toolCalls?.count == 1)
            #expect(call.id == UITestFixtures.askUserToolCallID)
            #expect(call.name == UITestFixtures.askUserToolName)
            // 分片 arguments 必须被累积器还原成完整 JSON。
            #expect(
                call.arguments == scenario.askUserArguments,
                "\(scenario.rawValue) arguments 未被完整还原"
            )
            #expect(response.stopReason == "tool_calls")
            // 首轮没有正文，避免界面在问题卡片上方多出一段空消息。
            #expect(response.content.isEmpty)
        }
    }

    // MARK: - 次轮

    @Test("请求体含 role=tool 时产出收尾正文，且不再调用工具")
    func secondRoundEmitsFollowUpAfterToolResult() async throws {
        for scenario in askUserScenarios {
            let provider = makeProvider()

            // 构造真实的第二轮请求：assistant 的工具调用 + tool 结果。
            // 这与 AgentLoop 恢复挂起回合后发出的请求形状一致。
            let response = try await provider.streamComplete(
                request(scenario: scenario, includeToolResult: true)
            ) { _ in }

            #expect(
                response.content == UITestFixtures.askUserFollowUpResponse,
                "\(scenario.rawValue) 次轮应产出收尾正文"
            )
            #expect(response.toolCalls?.isEmpty ?? true, "\(scenario.rawValue) 次轮不应再发工具调用")
            // 不发 finish_reason 是桩的一致约定（`.text` / `.long` 等纯文本场景同样如此），
            // 因此这里断言「没有 tool_calls 收尾信号」而不是固定为 "stop"。
            #expect(
                response.stopReason != "tool_calls",
                "\(scenario.rawValue) 次轮不应以 tool_calls 收尾"
            )
        }
    }

    @Test("工具结果确实进入了出站请求体（桩的判据前提成立）")
    func toolResultSurvivesRealSerialization() async throws {
        let stub = UITestStubNetwork()
        let provider = UITestProvider(apiService: VendorAPIService(networkProvider: stub))

        _ = try await provider.streamComplete(
            request(scenario: .askUserYesNo, includeToolResult: true)
        ) { _ in }

        let body = try #require(stub.lastRequestBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let roles = ((object["messages"] as? [[String: Any]]) ?? []).compactMap { $0["role"] as? String }

        // 若真实序列化把 tool 结果丢了，桩会退回首轮分支、界面反复弹问题。
        // 这条断言锁住桩两段式分发所依赖的前提。
        #expect(
            roles.contains("tool"),
            "tool 结果未进入请求体，桩无法区分是否已回答。roles=\(roles)"
        )
        #expect(stub.sentEventCount > 0)
    }

    @Test("无 role=tool 时仍发问（不会误判为已回答）")
    func withoutToolResultStillAsks() async throws {
        for scenario in askUserScenarios {
            let provider = makeProvider()

            // 只有 assistant 工具调用、没有 tool 结果：等价于「用户还没回答」。
            let response = try await provider.streamComplete(
                request(scenario: scenario, includeAssistantToolCall: true, includeToolResult: false)
            ) { _ in }

            #expect(
                response.toolCalls?.first?.name == UITestFixtures.askUserToolName,
                "\(scenario.rawValue) 在没有工具结果时必须继续发问"
            )
        }
    }

    // MARK: - 判据可靠性

    @Test("只有 role=tool 会触发次轮，assistant 的 tool_calls 不会")
    func toolCallAloneDoesNotCountAsAnswered() async throws {
        let provider = makeProvider()

        // assistant 消息里带 tool_calls，但没有 role=tool 结果。
        let response = try await provider.streamComplete(
            request(
                scenario: .askUserYesNo,
                includeAssistantToolCall: true,
                includeToolResult: false
            )
        ) { _ in }

        #expect(response.toolCalls?.first?.name == UITestFixtures.askUserToolName)
    }

    @Test("非流式路径与流式路径在两段上分别等价")
    func nonStreamingMatchesStreamingOnBothRounds() async throws {
        for scenario in askUserScenarios {
            let provider = makeProvider()

            // 首轮：非流式也必须带回工具调用。
            let firstStream = try await provider.streamComplete(request(scenario: scenario)) { _ in }
            let firstComplete = try await provider.complete(request(scenario: scenario))
            #expect(
                firstComplete.toolCalls?.first?.arguments == firstStream.toolCalls?.first?.arguments,
                "\(scenario.rawValue) 首轮流式/非流式 arguments 不一致"
            )

            // 次轮：非流式同样返回收尾正文。
            let secondComplete = try await provider.complete(
                request(scenario: scenario, includeToolResult: true)
            )
            #expect(secondComplete.content == UITestFixtures.askUserFollowUpResponse)
        }
    }

    // MARK: - Helper

    private var askUserScenarios: [UITestScenario] {
        UITestScenario.allCases.filter(\.isAskUser)
    }

    private func makeProvider(stub: UITestStubNetwork = UITestStubNetwork()) -> UITestProvider {
        UITestProvider(apiService: VendorAPIService(networkProvider: stub))
    }

    private func request(
        scenario: UITestScenario,
        includeAssistantToolCall: Bool = false,
        includeToolResult: Bool = false
    ) -> LLMRequest {
        var messages = [LLMMessage(role: .user, content: "UI 测试提示")]

        // 工具结果必须挂在对应的 assistant.tool_calls 之后：
        // `normalizeToolResultOrder` 会把找不到声明的 `role=tool` 消息连同
        // 孤立的 tool_calls 一起从出站请求中移除（见
        // `OpenAICompatibleProviderAdapter.normalizeToolResultOrder`）。
        // 因此 includeToolResult 隐含「也要带上 assistant 工具声明」，
        // 这与 AgentLoop 恢复挂起回合后回传历史的形状一致。
        if includeAssistantToolCall || includeToolResult {
            messages.append(
                LLMMessage(
                    role: .assistant,
                    content: "",
                    toolCalls: [
                        LLMToolCall(
                            id: UITestFixtures.askUserToolCallID,
                            name: UITestFixtures.askUserToolName,
                            arguments: scenario.askUserArguments ?? "{}"
                        )
                    ]
                )
            )

            if includeToolResult {
                messages.append(
                    LLMMessage(
                        role: .tool,
                        content: UITestFixtures.askUserChoiceOptionAccepted,
                        toolCallID: UITestFixtures.askUserToolCallID
                    )
                )
            }
        }

        return LLMRequest(
            conversationID: UUID(),
            providerID: nil,
            messages: messages,
            model: scenario.rawValue,
            tools: nil,
            reasoningEffort: nil
        )
    }
}
