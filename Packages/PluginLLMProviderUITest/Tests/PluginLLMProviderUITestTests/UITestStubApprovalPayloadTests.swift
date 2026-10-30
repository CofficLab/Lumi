import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderUITest

/// 锁定「高风险工具授权」桩场景的两段式响应形态。
///
/// 与 ask_user 场景同构（见 `UITestStubAskUserPayloadTests`）：
///
/// - 首轮（用户还没决定）：发出 `edit_file` 工具调用 → 回合挂起 → 界面弹出授权卡片；
/// - 次轮（用户已决定）：发出收尾文本 → 回合结束。
///
/// 分发信号是**请求体里有没有 `role=tool` 消息**，而非请求次数——
/// 见 `UITestStubNetwork.hasToolResult`。
///
/// 这里锁的是「桩产出的原始事件块」：UI 测试失败时需要能立刻区分
/// 是桩写错了，还是生产链路（风险判定 / 挂起 / 授权落库 / 恢复）有 bug。
@MainActor
@Suite("UI 测试桩高风险授权场景")
struct UITestStubApprovalPayloadTests {

    // MARK: - 首轮：请求授权

    @Test("首轮发出 edit_file 工具调用，arguments 分两片下发")
    func firstRoundEmitsHighRiskToolCall() throws {
        let events = try UITestStubNetwork.sseEvents(for: .approval, alreadyAnswered: false)
        let fragments = try argumentsFragments(in: events)

        #expect(fragments.count == 2, "arguments 应分两片，实际 \(fragments.count) 片")
        #expect(
            fragments.joined() == UITestFixtures.approvalToolArguments,
            "分片拼接后未还原原始 arguments：\(fragments.joined())"
        )
    }

    @Test("首轮首片带工具名与固定 call id")
    func firstRoundCarriesToolIdentity() throws {
        let events = try UITestStubNetwork.sseEvents(for: .approval, alreadyAnswered: false)
        let object = try jsonObject(of: #require(events.first))
        let delta = try #require((object["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])
        let call = try #require((delta["tool_calls"] as? [[String: Any]])?.first)
        let function = try #require(call["function"] as? [String: Any])

        #expect(call["id"] as? String == UITestFixtures.approvalToolCallID)
        #expect(function["name"] as? String == UITestFixtures.approvalToolName)
        #expect(call["index"] as? Int == 0)
    }

    @Test("首轮 finish_reason 为 tool_calls，不产出任何正文")
    func firstRoundStopsOnToolCalls() throws {
        let events = try UITestStubNetwork.sseEvents(for: .approval, alreadyAnswered: false)
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

    @Test("用户已决定后产出固定收尾正文，并以 stop 正常结束")
    func secondRoundEmitsFollowUpText() throws {
        let events = try UITestStubNetwork.sseEvents(for: .approval, alreadyAnswered: true)
        let deltas = try contentDeltas(in: events)

        #expect(deltas.joined() == UITestFixtures.approvalFollowUpResponse)
        #expect(UITestFixtures.approvalFollowUpResponse == "UI Testing Approval Resolved")
        // 已决定后不得再发工具调用，否则会再次挂起、界面反复弹授权卡片。
        #expect(
            try argumentsFragments(in: events).isEmpty,
            "次轮不应再次调用高风险工具"
        )
        #expect(try dataPayload(of: #require(events.last)) == "[DONE]")
    }

    @Test("两段响应互不相同（避免首轮被误判为收尾）")
    func twoRoundsDiffer() throws {
        let first = try UITestStubNetwork.sseEvents(for: .approval, alreadyAnswered: false)
        let second = try UITestStubNetwork.sseEvents(for: .approval, alreadyAnswered: true)
        #expect(first != second, "两段响应不应完全相同")
    }

    // MARK: - 场景元数据

    @Test("授权场景的参数是合法 JSON 且带 edit_file 的必填字段")
    func approvalArgumentsAreWellFormed() throws {
        let raw = UITestFixtures.approvalToolArguments
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        )
        #expect(object["file_path"] as? String != nil, "缺 file_path")
        #expect(object["old_string"] as? String != nil, "缺 old_string")
        #expect(object["new_string"] as? String != nil, "缺 new_string")
    }

    @Test("授权场景声明支持工具，且可被供应商目录查到")
    func approvalModelIsRegistered() {
        #expect(
            UITestScenario.approval.model.supportsTools,
            "授权场景必须声明 supportsTools，否则请求体不带 tools"
        )
        #expect(UITestScenario.approval.isApproval)

        let provider = UITestProvider()
        #expect(
            provider.providerInfo.contains(model: UITestScenario.approval.rawValue),
            "授权场景未注册到模型目录"
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
