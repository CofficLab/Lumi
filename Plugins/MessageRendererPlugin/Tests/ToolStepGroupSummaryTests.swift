import Testing
import Foundation
import KernelLumi
@testable import MessageRendererPlugin

/// `ToolStepGroupSummary` 的单元测试 —— V1「可折叠工具步骤组」折叠态摘要文案。
@Suite("ToolStepGroupSummary")
struct ToolStepGroupSummaryTests {

    // MARK: - aggregateState

    @Test("任一调用 result 为 nil → loading")
    func loadingWhenAnyResultNil() {
        let calls = [
            call("a", result: .init(content: "ok")),
            call("b", result: nil)
        ]
        #expect(ToolStepGroupSummary.aggregateState(for: calls) == .loading)
    }

    @Test("全部完成、无错误 → completed")
    func completedWhenAllSucceeded() {
        let calls = [
            call("a", result: .init(content: "ok")),
            call("b", result: .init(content: "ok"))
        ]
        #expect(ToolStepGroupSummary.aggregateState(for: calls) == .completed)
    }

    @Test("完成但含错误 → failed")
    func failedWhenAnyError() {
        let calls = [
            call("a", result: .init(content: "ok")),
            call("b", result: .init(content: "boom", isError: true))
        ]
        #expect(ToolStepGroupSummary.aggregateState(for: calls) == .failed)
    }

    @Test("loading 优先于 error(未完成调用先判定)")
    func loadingBeatsError() {
        let calls = [
            call("a", result: .init(content: "boom", isError: true)),
            call("b", result: nil)   // 仍在跑
        ]
        #expect(ToolStepGroupSummary.aggregateState(for: calls) == .loading)
    }

    // MARK: - summaryText

    @Test("进行中:显示 k/N 进度")
    func inProgressSummary() {
        let calls = [
            call("a", result: .init(content: "ok", duration: 0.4)),
            call("b", result: nil)
        ]
        let text = ToolStepGroupSummary.summaryText(for: calls)
        #expect(text == "执行中 · 已完成 1/2 · 400ms")
    }

    @Test("全部完成:数量 + 总耗时(求和)")
    func completedSummary() {
        let calls = [
            call("a", result: .init(content: "ok", duration: 1.0)),
            call("b", result: .init(content: "ok", duration: 0.5))
        ]
        let text = ToolStepGroupSummary.summaryText(for: calls)
        // 1.0 + 0.5 = 1.5
        #expect(text == "执行了 2 个步骤 · 1.5s")
    }

    @Test("含失败:追加失败数")
    func failedSummary() {
        let calls = [
            call("a", result: .init(content: "ok", duration: 2.0)),
            call("b", result: .init(content: "boom", duration: 1.0, isError: true))
        ]
        let text = ToolStepGroupSummary.summaryText(for: calls)
        #expect(text == "执行了 2 个步骤(1 失败) · 3.0s")
    }

    @Test("无耗时数据:省略耗时段")
    func summaryWithoutDuration() {
        let calls = [
            call("a", result: .init(content: "ok")),
            call("b", result: .init(content: "ok"))
        ]
        let text = ToolStepGroupSummary.summaryText(for: calls)
        #expect(text == "执行了 2 个步骤")
    }

    @Test("空列表:退化为 0 个步骤(不崩溃)")
    func emptySummary() {
        #expect(ToolStepGroupSummary.summaryText(for: []) == "执行了 0 个步骤")
    }

    // MARK: - totalDuration

    @Test("totalDuration 求和;无数据为 nil")
    func totalDurationAggregation() {
        #expect(ToolStepGroupSummary.totalDuration(for: [
            call("a", result: .init(content: "x", duration: 2.0)),
            call("b", result: .init(content: "y", duration: 3.5))
        ]) == 5.5)
        #expect(ToolStepGroupSummary.totalDuration(for: [
            call("a", result: nil),
            call("b", result: .init(content: "y"))
        ]) == nil)
    }

    // MARK: - Helper

    private func call(_ id: String, result: LumiToolResult?) -> LumiToolCall {
        LumiToolCall(id: id, name: "tool_\(id)", arguments: "{}", result: result, displayDescription: nil)
    }
}
