import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderUITest

/// 锁定 goal 桩两段式响应的形态。
///
/// 与 ask_user 场景同构：首轮（工具未执行）发 `create_goal` 工具调用；
/// 次轮（工具已执行）发收尾文本。分发信号是**请求体里有没有 `role=tool` 消息**，
/// 而非请求次数——见 `UITestStubNetwork.hasToolResult`。
///
/// ## 为什么要有这层测试
///
/// UI 测试跑一次要一分钟，而且失败时只能看到「侧边栏没出现」这种结果层面的现象。
/// 这里锁住桩产出的原始事件块，能立刻区分是桩写错了、还是生产链路
/// （工具注册 / 参数解码 / 目标创建）有 bug。
@MainActor
@Suite("UI 测试桩 goal 场景")
struct UITestStubGoalPayloadTests {

    // MARK: - 首轮：发起 create_goal

    @Test("首轮发出 create_goal 工具调用，arguments 分两片下发")
    func firstRoundEmitsGoalToolCall() throws {
        let events = try UITestStubNetwork.sseEvents(for: .goal, alreadyAnswered: false)
        let fragments = try argumentsFragments(in: events)

        #expect(fragments.count == 2, "arguments 应分两片，实际 \(fragments.count) 片")
        #expect(
            fragments.joined() == UITestFixtures.goalArguments,
            "分片拼接后未还原原始 arguments"
        )
    }

    @Test("首轮首片带工具名与固定 call id")
    func firstRoundCarriesToolIdentity() throws {
        let events = try UITestStubNetwork.sseEvents(for: .goal, alreadyAnswered: false)
        let object = try jsonObject(of: #require(events.first))
        let delta = try #require((object["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])
        let call = try #require((delta["tool_calls"] as? [[String: Any]])?.first)
        let function = try #require(call["function"] as? [String: Any])

        #expect(call["id"] as? String == UITestFixtures.goalToolCallID)
        #expect(function["name"] as? String == UITestFixtures.goalToolName)
        #expect(call["index"] as? Int == 0)
    }

    @Test("首轮 finish_reason 为 tool_calls，不产出任何正文")
    func firstRoundStopsOnToolCalls() throws {
        let events = try UITestStubNetwork.sseEvents(for: .goal, alreadyAnswered: false)
        let stopReasons = try events.compactMap { event -> String? in
            let payload = try dataPayload(of: event)
            guard payload != "[DONE]",
                  let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                  let choice = (object["choices"] as? [[String: Any]])?.first else { return nil }
            return choice["finish_reason"] as? String
        }
        #expect(stopReasons == ["tool_calls"], "首轮应以 tool_calls 收尾")
        #expect(try contentDeltas(in: events).isEmpty, "首轮不应产出正文")
    }

    // MARK: - 次轮：收尾

    @Test("工具执行后产出固定收尾正文，并以 stop 正常结束")
    func secondRoundEmitsFollowUpText() throws {
        let events = try UITestStubNetwork.sseEvents(for: .goal, alreadyAnswered: true)
        let deltas = try contentDeltas(in: events)

        #expect(deltas.joined() == UITestFixtures.goalFollowUpResponse)
        #expect(UITestFixtures.goalFollowUpResponse == "UI Testing Goal Created")
        // 已执行后不得再发工具调用，否则会反复建目标。
        #expect(
            try argumentsFragments(in: events).isEmpty,
            "次轮不应再次调用 create_goal"
        )
        #expect(try dataPayload(of: #require(events.last)) == "[DONE]")
    }

    @Test("两段响应互不相同（避免首轮被误判为收尾）")
    func twoRoundsDiffer() throws {
        let first = try UITestStubNetwork.sseEvents(for: .goal, alreadyAnswered: false)
        let second = try UITestStubNetwork.sseEvents(for: .goal, alreadyAnswered: true)
        #expect(first != second, "两段响应不应完全相同")
    }

    // MARK: - 参数形态

    /// 参数必须符合 `CreateGoalV2Tool.inputSchema`：`title` 与 `tasks` 必填，
    /// `tasks` 的每一项至少要有 `title`。
    ///
    /// 桩不假设宿主如何解析，因此只按 schema 产出参数——这条测试锁住
    /// 「产出的参数真的能被 schema 接受」，否则失败会表现成「工具报参数错误」。
    @Test("goal 参数是合法 JSON，且带 title 与 tasks 必填字段")
    func goalArgumentsAreWellFormed() throws {
        let raw = UITestFixtures.goalArguments
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        )

        #expect(object["title"] as? String == UITestFixtures.goalTitle, "缺 title")
        let tasks = try #require(object["tasks"] as? [[String: Any]], "缺 tasks")
        #expect(tasks.count == UITestFixtures.goalTaskTitles.count, "任务数与 fixture 不一致")
        for (index, task) in tasks.enumerated() {
            #expect(task["title"] as? String == UITestFixtures.goalTaskTitles[index], "第 \(index) 条任务标题不符")
        }
    }

    // MARK: - 场景元数据

    @Test("goal 场景声明支持工具，且展示名可辨识")
    func scenarioMetadataIsConsistent() {
        for scenario in UITestScenario.allCases {
            if scenario.isGoal {
                #expect(
                    scenario.model.supportsTools,
                    "\(scenario.rawValue) 必须声明 supportsTools，否则请求体不带 tools"
                )
                #expect(scenario.displayName.contains("Goal"), "\(scenario.rawValue) 的展示名应可辨识")
            } else {
                #expect(!scenario.isGoal, "\(scenario.rawValue) 不应被当成 goal 场景")
            }
        }
    }

    @Test("goal 场景模型可被供应商目录查到")
    func goalModelIsRegistered() {
        let provider = UITestProvider()
        #expect(
            provider.providerInfo.contains(model: UITestScenario.goal.rawValue),
            "goal 场景未注册到模型目录"
        )
    }

    // MARK: - Helper

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
