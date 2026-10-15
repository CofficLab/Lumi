import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderUITest

/// 锁定 ask_user 桩两段式响应的形态。
///
/// 与其他场景一样，这里锁的是「桩产出的原始事件块」：UI 测试失败时需要能立刻
/// 区分是桩写错了，还是生产链路（工具调度 / 挂起 / 恢复）有 bug。
///
/// ## 两段式的判据
///
/// 首轮（未回答）发 `ask_user` 工具调用；次轮（已回答）发收尾文本。
/// 分发信号是**请求体里有没有 `role=tool` 消息**，而非请求次数——
/// 见 `UITestStubNetwork.hasToolResult`。
///
/// - Note: 标注 `@MainActor` 只是为了读取 `UITestProvider.providerInfo` 的模型目录
///   （该类型是主线程语义）。断言本身不涉及并发。
@MainActor
@Suite("UI 测试桩 ask_user 场景")
struct UITestStubAskUserPayloadTests {

    // MARK: - 首轮：发问

    @Test("首轮发出 ask_user 工具调用，arguments 分两片下发")
    func firstRoundEmitsAskUserToolCall() throws {
        for scenario in askUserScenarios {
            let events = try UITestStubNetwork.sseEvents(for: scenario, alreadyAnswered: false)
            let fragments = try argumentsFragments(in: events)

            #expect(
                fragments.count == 2,
                "\(scenario.rawValue) 的 arguments 应分两片，实际 \(fragments.count) 片"
            )
            #expect(
                fragments.joined() == scenario.askUserArguments,
                "\(scenario.rawValue) 分片拼接后未还原原始 arguments"
            )
        }
    }

    @Test("首轮首片带工具名与固定 call id")
    func firstRoundCarriesToolIdentity() throws {
        for scenario in askUserScenarios {
            let events = try UITestStubNetwork.sseEvents(for: scenario, alreadyAnswered: false)
            let object = try jsonObject(of: #require(events.first))
            let delta = try #require((object["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])
            let call = try #require((delta["tool_calls"] as? [[String: Any]])?.first)
            let function = try #require(call["function"] as? [String: Any])

            #expect(call["id"] as? String == UITestFixtures.askUserToolCallID)
            #expect(function["name"] as? String == UITestFixtures.askUserToolName)
            #expect(call["index"] as? Int == 0)
        }
    }

    @Test("首轮 finish_reason 为 tool_calls，不产出任何正文")
    func firstRoundStopsOnToolCalls() throws {
        for scenario in askUserScenarios {
            let events = try UITestStubNetwork.sseEvents(for: scenario, alreadyAnswered: false)
            let stopReasons = try events.compactMap { event -> String? in
                let payload = try dataPayload(of: event)
                guard payload != "[DONE]",
                      let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                      let choice = (object["choices"] as? [[String: Any]])?.first else { return nil }
                return choice["finish_reason"] as? String
            }
            #expect(stopReasons == ["tool_calls"], "\(scenario.rawValue) 首轮应以 tool_calls 收尾")
            #expect(try contentDeltas(in: events).isEmpty, "\(scenario.rawValue) 首轮不应产出正文")
        }
    }

    // MARK: - 次轮：收尾

    @Test("已回答后产出固定收尾正文，并以 stop 正常结束")
    func secondRoundEmitsFollowUpText() throws {
        for scenario in askUserScenarios {
            let events = try UITestStubNetwork.sseEvents(for: scenario, alreadyAnswered: true)
            let deltas = try contentDeltas(in: events)

            #expect(deltas.joined() == UITestFixtures.askUserFollowUpResponse)
            #expect(UITestFixtures.askUserFollowUpResponse == "UI Testing Ask User Answered")
            // 已回答后不得再发工具调用，否则会再次挂起、界面反复弹问题。
            #expect(
                try argumentsFragments(in: events).isEmpty,
                "\(scenario.rawValue) 次轮不应再次调用 ask_user"
            )
            #expect(try dataPayload(of: #require(events.last)) == "[DONE]")
        }
    }

    @Test("两段响应互不相同（避免首轮被误判为收尾）")
    func twoRoundsDiffer() throws {
        for scenario in askUserScenarios {
            let first = try UITestStubNetwork.sseEvents(for: scenario, alreadyAnswered: false)
            let second = try UITestStubNetwork.sseEvents(for: scenario, alreadyAnswered: true)
            #expect(first != second, "\(scenario.rawValue) 两段响应不应完全相同")
        }
    }

    // MARK: - 场景元数据

    @Test("三个 ask_user 场景的参数都是合法 JSON 且带必填字段")
    func askUserArgumentsAreWellFormed() throws {
        for scenario in askUserScenarios {
            let raw = try #require(scenario.askUserArguments)
            let object = try #require(
                try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
            )
            #expect(object["question"] as? String != nil, "\(scenario.rawValue) 缺 question")
            let mode = try #require(object["mode"] as? String)
            #expect(["yes_no", "choice", "free_text"].contains(mode))

            if mode == "choice" {
                #expect((object["options"] as? [Any])?.isEmpty == false, "choice 必须带 options")
            } else {
                #expect(object["options"] == nil, "\(mode) 不应带 options")
            }
        }
    }

    @Test("非 ask_user 场景没有工具参数，且 ask_user 场景声明支持工具")
    func scenarioMetadataIsConsistent() {
        for scenario in UITestScenario.allCases {
            if scenario.isAskUser {
                #expect(
                    scenario.model.supportsTools,
                    "\(scenario.rawValue) 必须声明 supportsTools，否则请求体不带 tools"
                )
                #expect(scenario.askUserArguments != nil)
            } else {
                #expect(scenario.askUserArguments == nil, "\(scenario.rawValue) 不应有 ask_user 参数")
            }
            #expect(
                !scenario.isAskUser || scenario.displayName.contains("Ask User"),
                "\(scenario.rawValue) 的展示名应可辨识"
            )
        }
    }

    @Test("ask_user 场景模型可被供应商目录查到")
    func askUserModelsAreRegistered() {
        let provider = UITestProvider()
        for scenario in askUserScenarios {
            #expect(
                provider.providerInfo.contains(model: scenario.rawValue),
                "\(scenario.rawValue) 未注册到模型目录"
            )
        }
    }

    // MARK: - Helper

    private var askUserScenarios: [UITestScenario] {
        UITestScenario.allCases.filter(\.isAskUser)
    }

    private func jsonObject(of event: String) throws -> [String: Any] {
        let payload = try dataPayload(of: event)
        #expect(payload != "[DONE]", "该事件是终止事件，不含 JSON 对象：\(payload)")
        return try #require(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    }

    private func dataPayload(of event: String) throws -> String {
        var text = event
        for prefix in ["data: ", "data:"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
            break
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func contentDeltas(in events: [String]) throws -> [String] {
        try events.compactMap { event -> String? in
            let payload = try dataPayload(of: event)
            guard payload != "[DONE]",
                  let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                  let delta = (object["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any]
            else { return nil }
            return delta["content"] as? String
        }
    }

    private func argumentsFragments(in events: [String]) throws -> [String] {
        try events.flatMap { event -> [String] in
            let payload = try dataPayload(of: event)
            guard payload != "[DONE]",
                  let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                  let delta = (object["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any],
                  let toolCalls = delta["tool_calls"] as? [[String: Any]] else { return [] }

            return toolCalls.compactMap { ($0["function"] as? [String: Any])?["arguments"] as? String }
        }
    }
}
