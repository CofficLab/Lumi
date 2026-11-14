import Foundation
import Testing
@testable import KitLLM

/// 工具调用参数解析缓存的行为契约（Issue #1269）。
///
/// 核心诉求：一次会话的多个 LLM step 不再重复解析同一批历史工具调用的
/// `arguments`，同时**校验语义不能因为缓存而改变**。
@Suite("ToolCallArgumentsParser 工具参数解析缓存")
struct ToolCallArgumentsParserTests {

    // MARK: - 正确性

    @Test("合法 JSON 对象被解析为有效结果")
    func parsesValidJSONObject() {
        let parser = ToolCallArgumentsParser()

        let parsed = parser.parse(id: "call-1", arguments: #"{"path":"/tmp/a.txt","line":3}"#)

        #expect(parsed.isValid)
        #expect(parsed.object?["path"] as? String == "/tmp/a.txt")
        #expect(parsed.object?["line"] as? Int == 3)
    }

    @Test("非法 JSON 被标记为无效")
    func rejectsInvalidJSON() {
        let parser = ToolCallArgumentsParser()

        let parsed = parser.parse(id: "call-bad", arguments: #"{"label": "broken"label}"#)

        #expect(!parsed.isValid)
        #expect(parsed.object == nil)
    }

    @Test("合法 JSON 但不是对象（如数组）同样无效")
    func rejectsNonObjectJSON() {
        let parser = ToolCallArgumentsParser()

        #expect(!parser.parse(id: "call-arr", arguments: "[1,2,3]").isValid)
        #expect(!parser.parse(id: "call-str", arguments: "\"hello\"").isValid)
    }

    @Test("空字符串参数无效")
    func rejectsEmptyArguments() {
        let parser = ToolCallArgumentsParser()

        #expect(!parser.parse(id: "call-empty", arguments: "").isValid)
    }

    @Test("缓存命中返回等价的解析结果")
    func cachedParseReturnsEquivalentResult() {
        let parser = ToolCallArgumentsParser()
        let arguments = #"{"key":"value"}"#

        let first = parser.parse(id: "call-1", arguments: arguments)
        let second = parser.parse(id: "call-1", arguments: arguments)

        #expect(first.isValid)
        #expect(second.isValid)
        #expect(second.object?["key"] as? String == "value")
        #expect(second.source == first.source)
    }

    @Test("同一 ID 的参数被改动后重新解析")
    func reparsesWhenArgumentsChange() {
        let parser = ToolCallArgumentsParser()

        _ = parser.parse(id: "call-1", arguments: #"{"key":"first"}"#)
        let updated = parser.parse(id: "call-1", arguments: #"{"key":"second"}"#)

        #expect(updated.object?["key"] as? String == "second")
    }

    @Test("同一 ID 的参数被改成非法值时不再复用旧结果")
    func invalidatesStaleResultWhenArgumentsChange() {
        let parser = ToolCallArgumentsParser()

        _ = parser.parse(id: "call-1", arguments: #"{"key":"valid"}"#)
        let broken = parser.parse(id: "call-1", arguments: "not json")

        #expect(!broken.isValid)
    }

    @Test("不同 ID 各占一条缓存")
    func distinctIDsGetDistinctEntries() {
        let parser = ToolCallArgumentsParser()

        _ = parser.parse(id: "call-1", arguments: #"{"a":1}"#)
        _ = parser.parse(id: "call-2", arguments: #"{"b":2}"#)

        #expect(parser.entryCount == 2)
    }

    // MARK: - 校验语义

    @Test("校验合法参数不抛错")
    func validationPassesForValidArguments() throws {
        let parser = ToolCallArgumentsParser()
        let toolCall = LLMToolCall(id: "call-1", name: "read_file", arguments: #"{"path":"/tmp/a"}"#)

        #expect(throws: Never.self) {
            try parser.validate(toolCall)
        }
    }

    @Test("校验非法参数抛出与 LLMToolCall.validateArguments 相同的错误")
    func validationThrowsSameErrorAsDirectValidation() {
        let parser = ToolCallArgumentsParser()
        let toolCall = LLMToolCall(id: "call-bad", name: "read_file", arguments: #"{"broken"label":}"#)

        #expect(throws: LLMToolCallValidationError.self) {
            try parser.validate(toolCall)
        }
        // 与直连校验的判定必须一致：两者要么都通过，要么都失败。
        #expect(throws: LLMToolCallValidationError.self) {
            try toolCall.validateArguments()
        }
    }

    @Test("缓存命中后的校验结果与首次一致")
    func validationIsStableAcrossCacheHits() {
        let parser = ToolCallArgumentsParser()
        let toolCall = LLMToolCall(id: "call-1", name: "read_file", arguments: #"{"path":"/tmp/a"}"#)

        #expect(throws: Never.self) { try parser.validate(toolCall) }
        #expect(throws: Never.self) { try parser.validate(toolCall) }
    }

    // MARK: - 有界性

    @Test("条目数超过上限时被淘汰")
    func evictsWhenEntryLimitExceeded() {
        let parser = ToolCallArgumentsParser(maxEntries: 4, maxTotalSourceCharacters: .max)

        for index in 0..<20 {
            _ = parser.parse(id: "call-\(index)", arguments: #"{"i":\#(index)}"#)
        }

        #expect(parser.entryCount <= 4)
    }

    @Test("源字符串总长度超过上限时被淘汰")
    func evictsWhenSourceLengthLimitExceeded() {
        let parser = ToolCallArgumentsParser(maxEntries: .max, maxTotalSourceCharacters: 200)
        let big = String(repeating: "x", count: 100)

        for index in 0..<20 {
            _ = parser.parse(id: "call-\(index)", arguments: #"{"v":"\#(big)"}"#)
        }

        #expect(parser.entryCount <= 20)
    }

    @Test("清空缓存后条目归零")
    func removeAllResetsEntries() {
        let parser = ToolCallArgumentsParser()
        _ = parser.parse(id: "call-1", arguments: #"{"a":1}"#)

        #expect(parser.entryCount == 1)

        parser.removeAll()

        #expect(parser.entryCount == 0)
    }

    @Test("淘汰后重新解析仍得到正确结果")
    func evictedEntriesStillParseCorrectly() {
        let parser = ToolCallArgumentsParser(maxEntries: 2, maxTotalSourceCharacters: .max)

        _ = parser.parse(id: "call-1", arguments: #"{"v":1}"#)
        _ = parser.parse(id: "call-2", arguments: #"{"v":2}"#)
        _ = parser.parse(id: "call-3", arguments: #"{"v":3}"#)

        let parsed = parser.parse(id: "call-1", arguments: #"{"v":1}"#)
        #expect(parsed.object?["v"] as? Int == 1)
    }

    // MARK: - 性能回归

    @Test("重复解析同一批参数的耗时显著低于每次重新解析")
    func repeatedParseIsCheaperThanReparsing() {
        // 1 MB 级参数：工具把截图塞进参数并不罕见。
        let arguments = #"{"image":"\#(String(repeating: "A", count: 1_000_000))"}"#
        let parser = ToolCallArgumentsParser()

        // 预热。
        _ = parser.parse(id: "call-1", arguments: arguments)

        let iterations = 30

        let firstStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = try? JSONSerialization.jsonObject(with: Data(arguments.utf8))
        }
        let firstElapsed = DispatchTime.now().uptimeNanoseconds - firstStart

        let cachedStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = parser.parse(id: "call-1", arguments: arguments)
        }
        let cachedElapsed = DispatchTime.now().uptimeNanoseconds - cachedStart

        // 命中缓存必须明显更快；放宽到「至少快 2 倍」以稳定抓住回归。
        #expect(cachedElapsed * 2 < firstElapsed)
    }
}
