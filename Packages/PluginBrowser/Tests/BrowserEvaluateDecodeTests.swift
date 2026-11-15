import Foundation
import Testing
@testable import BrowserPlugin

/// 回归 issue #1297：`browser_evaluate` 的结果解析（UTF-8 拷贝、JSON 解析、
/// pretty-print）从主 actor 移到后台分离任务执行。这里覆盖纯解析逻辑的正确性，
/// 并验证它可以在非主 actor 上下文处理数 MB 的结果。
@Suite("browser_evaluate 结果解析（#1297）")
struct BrowserEvaluateDecodeTests {

    @Test("字符串结果原样返回")
    func stringValueReturnsAsIs() {
        let decoded = BrowserSession.decodeEvaluateResult(#"{"ok":true,"value":"hello"}"#)
        guard case .success(let text) = decoded else {
            Issue.record("expected success")
            return
        }
        #expect(text == "hello")
    }

    @Test("对象结果被美化输出")
    func objectValueIsPrettyPrinted() {
        let decoded = BrowserSession.decodeEvaluateResult(#"{"ok":true,"value":{"a":1,"b":[1,2]}}"#)
        guard case .success(let text) = decoded else {
            Issue.record("expected success")
            return
        }
        #expect(text.contains("\n"))
        #expect(text.contains("\"a\""))
    }

    @Test("缺失 value 返回 null")
    func missingValueReturnsNull() {
        let decoded = BrowserSession.decodeEvaluateResult(#"{"ok":true}"#)
        guard case .success(let text) = decoded else {
            Issue.record("expected success")
            return
        }
        #expect(text == "null")
    }

    @Test("错误信封映射为 scriptFailed")
    func errorEnvelopeMapsToScriptFailed() {
        let decoded = BrowserSession.decodeEvaluateResult(#"{"ok":false,"error":"boom"}"#)
        guard case .scriptFailed(let reason) = decoded else {
            Issue.record("expected scriptFailed")
            return
        }
        #expect(reason == "boom")
    }

    @Test("非法 JSON 映射为 noPage")
    func malformedJSONMapsToNoPage() {
        let decoded = BrowserSession.decodeEvaluateResult("not json")
        guard case .noPage = decoded else {
            Issue.record("expected noPage")
            return
        }
    }

    @Test("数 MB 结果可在后台线程解析（#1297）")
    func largeResultDecodesOffMain() async {
        let big = String(repeating: "x", count: 2_000_000)
        let envelope = #"{"ok":true,"value":{"blob":""# + big + #""}}"#

        // 在分离任务里调用 nonisolated 解析，证明它不依赖主 actor。
        let decoded = await Task.detached(priority: .userInitiated) {
            BrowserSession.decodeEvaluateResult(envelope)
        }.value

        guard case .success(let text) = decoded else {
            Issue.record("expected success")
            return
        }
        #expect(text.contains(big))
    }
}