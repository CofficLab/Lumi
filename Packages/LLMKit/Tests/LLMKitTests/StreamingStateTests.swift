import Testing
import Foundation
@testable import LLMKit

@Suite("StreamingState Tests")
struct StreamingStateTests {

    private func makeState(maxThinkingLength: Int = 100_000) -> StreamingState {
        StreamingState(startTime: CFAbsoluteTimeGetCurrent(), maxThinkingLength: maxThinkingLength)
    }

    // MARK: - appendContent

    @Test("appendContent 累积文本块")
    func appendContent() async {
        let state = makeState()
        await state.appendContent("Hello ")
        await state.appendContent("World")
        let chunks = await state.accumulatedContentChunks
        #expect(chunks == ["Hello ", "World"])
        #expect(await state.accumulatedContentLength == 11)
    }

    // MARK: - appendThinking

    @Test("appendThinking 累积思考内容")
    func appendThinking() async {
        let state = makeState()
        await state.appendThinking("思考中")
        await state.appendThinking("继续")
        let result = await state.getFinalThinking()
        #expect(result == "思考中继续")
    }

    @Test("appendThinking 忽略空字符串")
    func appendThinkingEmpty() async {
        let state = makeState()
        await state.appendThinking("")
        #expect(await state.accumulatedThinkingChunks.isEmpty)
    }

    @Test("appendThinking 受 maxThinkingLength 限制截断")
    func appendThinkingTruncation() async {
        let state = makeState(maxThinkingLength: 5)
        await state.appendThinking("abc")
        await state.appendThinking("defgh") // 只会取 "de"（剩余 2 字符）
        let result = await state.getFinalThinking()
        // "abc"(3) + "de"(2) = 5
        #expect(result == "abcde")
        #expect(await state.accumulatedThinkingLength == 5)
    }

    @Test("appendThinking 超出限制后不再追加")
    func appendThinkingOverLimit() async {
        let state = makeState(maxThinkingLength: 3)
        await state.appendThinking("abc")
        await state.appendThinking("def") // 全部被截断
        #expect(await state.getFinalThinking() == "abc")
    }

    // MARK: - recordFirstToken

    @Test("recordFirstToken 返回 TTFT 毫秒数")
    func recordFirstToken() async {
        let state = makeState()
        let ttft = await state.recordFirstToken()
        #expect(ttft != nil)
        #expect(ttft! >= 0)
    }

    @Test("recordFirstToken 仅首次返回非 nil")
    func recordFirstTokenIdempotent() async {
        let state = makeState()
        let first = await state.recordFirstToken()
        let second = await state.recordFirstToken()
        #expect(first != nil)
        #expect(second == nil)
    }

    // MARK: - Tool Calls

    @Test("完整的工具调用流程：start → append → save")
    func toolCallFlow() async {
        let state = makeState()
        await state.startNewToolCall(id: "call_1", name: "read_file", arguments: "")
        await state.appendToolCallArguments("{\"path\":")
        await state.appendToolCallArguments("\"/tmp\"}")
        await state.saveCurrentToolCall()

        let result = await state.getFinalToolCalls()
        #expect(result?.count == 1)
        #expect(result?.first?.id == "call_1")
        #expect(result?.first?.name == "read_file")
        #expect(result?.first?.arguments == "{\"path\":\"/tmp\"}")
    }

    @Test("startNewToolCall 带 hasPartialJson=false 且有 arguments 时保留")
    func toolCallWithArgumentsNoPartialJson() async {
        let state = makeState()
        await state.startNewToolCall(id: "call_2", name: "run", hasPartialJson: false, arguments: "{\"cmd\":\"ls\"}")
        await state.saveCurrentToolCall()

        let result = await state.getFinalToolCalls()
        #expect(result?.first?.arguments == "{\"cmd\":\"ls\"}")
    }

    @Test("saveCurrentToolCall 在无活跃调用时无副作用")
    func saveCurrentToolCallNoOp() async {
        let state = makeState()
        await state.saveCurrentToolCall() // 无活跃 tool call
        #expect(await state.getFinalToolCalls() == nil)
    }

    @Test("多个工具调用")
    func multipleToolCalls() async {
        let state = makeState()

        await state.startNewToolCall(id: "c1", name: "a", arguments: "{}")
        await state.saveCurrentToolCall()

        await state.startNewToolCall(id: "c2", name: "b", arguments: "{}")
        await state.saveCurrentToolCall()

        let result = await state.getFinalToolCalls()
        #expect(result?.count == 2)
        #expect(result?[0].id == "c1")
        #expect(result?[1].id == "c2")
    }

    @Test("开始新工具调用前保存当前调用")
    func startingNewToolCallSavesCurrentCall() async {
        let state = makeState()

        await state.startNewToolCall(id: "c1", name: "a", arguments: "{\"one\":true}")
        await state.startNewToolCall(id: "c2", name: "b", arguments: "{\"two\":true}")
        await state.saveCurrentToolCall()

        let result = await state.getFinalToolCalls()
        #expect(result == [
            KitToolCall(id: "c1", name: "a", arguments: "{\"one\":true}"),
            KitToolCall(id: "c2", name: "b", arguments: "{\"two\":true}")
        ])
    }

    @Test("空 arguments 默认为 {}")
    func emptyArgumentsDefault() async {
        let state = makeState()
        await state.startNewToolCall(id: "c", name: "n", hasPartialJson: true)
        // no appendToolCallArguments
        await state.saveCurrentToolCall()

        let result = await state.getFinalToolCalls()
        #expect(result?.first?.arguments == "{}")
    }

    // MARK: - setError

    @Test("setError 保存错误信息")
    func setError() async {
        let state = makeState()
        await state.setError("something went wrong")
        #expect(await state.streamError == "something went wrong")
    }

    // MARK: - updateTokens

    @Test("updateTokens 累积设置并自动计算 total")
    func updateTokens() async {
        let state = makeState()
        await state.updateTokens(input: 100, output: nil)
        #expect(await state.inputTokens == 100)
        #expect(await state.totalTokens == nil)

        await state.updateTokens(input: nil, output: 50)
        #expect(await state.outputTokens == 50)
        #expect(await state.totalTokens == 150)
    }

    @Test("updateTokens 覆盖之前的值")
    func updateTokensOverwrite() async {
        let state = makeState()
        await state.updateTokens(input: 100, output: 50)
        await state.updateTokens(input: 200, output: 80)
        #expect(await state.inputTokens == 200)
        #expect(await state.outputTokens == 80)
        #expect(await state.totalTokens == 280)
    }

    // MARK: - setStopReason

    @Test("setStopReason")
    func setStopReason() async {
        let state = makeState()
        await state.setStopReason("stop")
        #expect(await state.stopReason == "stop")
    }

    // MARK: - getStreamingDuration

    @Test("getStreamingDuration 在 recordFirstToken 前返回 nil")
    func streamingDurationBeforeFirstToken() async {
        let state = makeState()
        #expect(await state.getStreamingDuration() == nil)
    }

    @Test("getStreamingDuration 在 recordFirstToken 后返回非 nil")
    func streamingDurationAfterFirstToken() async {
        let state = makeState()
        _ = await state.recordFirstToken()
        let duration = await state.getStreamingDuration()
        #expect(duration != nil)
        #expect(duration! >= 0)
    }

    // MARK: - getFinalThinking

    @Test("getFinalThinking 空内容返回 nil")
    func finalThinkingEmpty() async {
        let state = makeState()
        #expect(await state.getFinalThinking() == nil)
    }

    // MARK: - getFinalToolCalls

    @Test("getFinalToolCalls 空列表返回 nil")
    func finalToolCallsEmpty() async {
        let state = makeState()
        #expect(await state.getFinalToolCalls() == nil)
    }
}
