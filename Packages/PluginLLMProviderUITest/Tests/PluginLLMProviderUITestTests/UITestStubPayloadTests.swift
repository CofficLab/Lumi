import Foundation
import Testing
@testable import PluginLLMProviderUITest

/// 锁定桩产出的 SSE 事件块格式。
///
/// ## 为什么需要这些断言
///
/// 桩的输出是整条链路上**唯一**由我们手写、而非真实供应商提供的部分。
/// UI 测试失败时需要能立刻区分两种根因：
///
/// - 桩的 payload 写错了（预期内容对不上）
/// - 适配器/累积器有 bug（payload 正确但结果不对）
///
/// 一旦桩的格式被这里锁住，上面两种情况就有明确分界：payload 断言失败 = 桩坏了；
/// payload 断言全过但 UI 测试失败 = 生产链路有 bug。
@Suite("UI 测试桩 SSE payload")
struct UITestStubPayloadTests {

    // MARK: - 通用格式

    @Test("每个事件块都以 data: 前缀开头并以空行结尾")
    func everyEventIsWellFormedSSE() throws {
        for scenario in UITestScenario.allCases {
            for event in try UITestStubNetwork.sseEvents(for: scenario) {
                #expect(
                    event.hasPrefix("data: "),
                    "\(scenario.rawValue) 事件块缺少 data: 前缀：\(event)"
                )
                #expect(
                    event.hasSuffix("\n\n"),
                    "\(scenario.rawValue) 事件块缺少结尾空行：\(event)"
                )
            }
        }
    }

    @Test("每个非终止事件块的 data 载荷都是合法 JSON")
    func everyEventPayloadIsValidJSON() throws {
        for scenario in UITestScenario.allCases {
            for event in try UITestStubNetwork.sseEvents(for: scenario) {
                let payload = try dataPayload(of: event)
                if payload == "[DONE]" { continue }
                #expect(
                    (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) != nil,
                    "\(scenario.rawValue) 事件块 data 不是合法 JSON：\(payload)"
                )
            }
        }
    }

    @Test("成功场景以 [DONE] 收尾，错误场景以单个 error 事件终止")
    func successfulScenariosTerminateWithDone() throws {
        for scenario in UITestScenario.allCases {
            let events = try UITestStubNetwork.sseEvents(for: scenario)
            let last = try #require(events.last)

            if scenario == .error {
                // 错误场景刻意不发 [DONE]：真实供应商报错时流就是直接断掉的，
                // 让累积器走「error → 终止」分支而非「正常收尾」分支。
                #expect(
                    events.count == 1,
                    "\(scenario.rawValue) 应只产出错误事件，实际 \(events.count) 个"
                )
                continue
            }

            #expect(
                try dataPayload(of: last) == "[DONE]",
                "\(scenario.rawValue) 未以 [DONE] 结束"
            )
        }
    }

    // MARK: - 文本场景

    @Test("文本场景的分段拼接后等于约定正文")
    func textChunksConcatenateToExpectedReply() throws {
        let events = try UITestStubNetwork.sseEvents(for: .text)
        let deltas = try contentDeltas(in: events)

        #expect(deltas == UITestFixtures.textChunks.filter { !$0.isEmpty })
        #expect(deltas.joined() == UITestFixtures.textResponse)
        #expect(UITestFixtures.textResponse == "UI Testing Reply")
    }

    @Test("文本场景带 usage 统计与终止信号")
    func textScenarioCarriesUsageAndStop() throws {
        let events = try UITestStubNetwork.sseEvents(for: .text)
        // [DONE] 不是 JSON，先滤掉再找 usage-only 事件（choices 为空但带 usage）。
        let usageObjects = try events
            .filter { try dataPayload(of: $0) != "[DONE]" }
            .map { try jsonObject(of: $0) }
            .filter { $0["usage"] != nil }

        #expect(usageObjects.count == 1, "应恰好有一个 usage-only 事件")
        let usage = try #require(usageObjects.first?["usage"] as? [String: Any])
        #expect(usage["prompt_tokens"] as? Int == 12)
        #expect(usage["completion_tokens"] as? Int == 6)
    }

    // MARK: - 工具场景

    @Test("工具场景把 arguments 分两片下发，覆盖累加路径")
    func toolScenarioSplitsArgumentsAcrossDeltas() throws {
        let events = try UITestStubNetwork.sseEvents(for: .tool)
        var fragments: [String] = []

        for event in events {
            let payload = try dataPayload(of: event)
            guard payload != "[DONE]",
                  let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let toolCalls = delta["tool_calls"] as? [[String: Any]] else { continue }

            for call in toolCalls {
                guard let function = call["function"] as? [String: Any],
                      let arguments = function["arguments"] as? String else { continue }
                fragments.append(arguments)
            }
        }

        #expect(fragments.count == 2, "工具 arguments 应被分成两片，实际 \(fragments.count) 片")
        #expect(
            fragments.joined() == UITestFixtures.toolArguments,
            "分片拼接后应还原原始 arguments，实际：\(fragments.joined())"
        )
        #expect(UITestFixtures.toolArguments == #"{"path":"."}"#)
    }

    @Test("工具场景首片带 id 与 name，finish_reason 为 tool_calls")
    func toolScenarioProvidesIdentityAndStopReason() throws {
        let events = try UITestStubNetwork.sseEvents(for: .tool)

        let first = try jsonObject(of: #require(events.first))
        let firstDelta = try #require((first["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])
        let call = try #require((firstDelta["tool_calls"] as? [[String: Any]])?.first)
        let function = try #require(call["function"] as? [String: Any])

        #expect(call["id"] as? String == "call_ui_test_0001")
        #expect(function["name"] as? String == UITestFixtures.toolName)
        #expect(call["index"] as? Int == 0)

        // finish_reason 事件：stop_reason 是累积器判定流结束的依据。
        let stopReasons = try events.compactMap { event -> String? in
            let payload = try dataPayload(of: event)
            guard payload != "[DONE]",
                  let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                  let choice = (object["choices"] as? [[String: Any]])?.first else { return nil }
            return choice["finish_reason"] as? String
        }
        #expect(stopReasons == ["tool_calls"])
    }

    // MARK: - 错误场景

    @Test("错误场景产出带 error.message 的事件")
    func errorScenarioCarriesMessage() throws {
        let events = try UITestStubNetwork.sseEvents(for: .error)
        #expect(events.count == 1)

        let object = try jsonObject(of: #require(events.first))
        let error = try #require(object["error"] as? [String: Any])

        #expect(error["message"] as? String == UITestFixtures.errorMessage)
        #expect(UITestFixtures.errorMessage == "UI Testing Request Failed")
        // 刻意不带 choices：解析器会先命中 error 分支，不会误当正常 chunk。
        #expect(object["choices"] == nil)
    }

    // MARK: - 长文本场景

    @Test("长文本场景产出约定段数的正文增量")
    func longScenarioEmitsFixedParagraphCount() throws {
        let events = try UITestStubNetwork.sseEvents(for: .long)
        let deltas = try contentDeltas(in: events)

        #expect(deltas.count == UITestFixtures.longParagraphCount)
        #expect(deltas.first == "段落 1。")
        #expect(deltas.last == "段落 \(UITestFixtures.longParagraphCount)。")
    }

    // MARK: - 慢速场景

    @Test("慢速场景复用文本场景的正文，差异只在投递间隔")
    func slowScenarioReusesTextBody() throws {
        // 逐事件 payload 含各自的 model 字段，故不能整体相等；
        // 语义上要相同的是正文增量。
        let slowDeltas = try contentDeltas(in: UITestStubNetwork.sseEvents(for: .slow))
        let textDeltas = try contentDeltas(in: UITestStubNetwork.sseEvents(for: .text))

        #expect(slowDeltas == textDeltas)
        #expect(slowDeltas.joined() == UITestFixtures.textResponse)
        #expect(UITestFixtures.slowChunkDelay > 0)
    }

    // MARK: - 工具

    /// 解析事件块的 `data:` 载荷为 JSON 对象。
    ///
    /// - Note: 单独抽出来是因为 `#require` 宏不能嵌套展开
    ///   （`#require(try #require(...))` 会触发 recursive expansion 编译错误）。
    private func jsonObject(of event: String) throws -> [String: Any] {
        let payload = try dataPayload(of: event)
        #expect(payload != "[DONE]", "该事件是终止事件，不含 JSON 对象：\(payload)")
        return try #require(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    }

    /// 取出 `data: ` 之后的载荷文本。
    private func dataPayload(of event: String) throws -> String {
        var text = event
        for prefix in ["data: ", "data:"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
            break
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 取出所有 `delta.content` 增量。
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
}
