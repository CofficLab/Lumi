import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #417：快照/交互脚本曾在页面全局声明 `const __OPTS`，
/// 同一页面第二次 `evaluateJavaScript` 会因重复声明全局词法绑定抛 SyntaxError，
/// 后续快照或交互全部失效。配置必须落在脚本自身的函数作用域内，可任意次数重复执行。
///
/// 用 `JSContext` 复现 WKWebView 的同一全局词法环境：多次 `evaluateScript`
/// 共享全局声明，因此重复的顶层 `const` 会在这里同样抛 SyntaxError。
@Suite("Browser 脚本可在同一页面重复执行")
struct BrowserScriptRepeatedEvaluationTests {

    @Test("快照脚本可在同一 JS 环境重复执行")
    func snapshotScriptRunsRepeatedly() throws {
        let context = try makeContext()
        context.evaluateScript(Self.pageStub)
        let script = BrowserAccessibilityScript.script(operation: "snapshot")

        let first = evaluate(context, script)
        #expect(context.exception == nil)
        #expect(first?.objectForKeyedSubscript("total")?.toInt32() == 0)

        let second = evaluate(context, script)
        #expect(context.exception == nil)
        #expect(second?.objectForKeyedSubscript("total")?.toInt32() == 0)
    }

    @Test("find 脚本可在同一 JS 环境重复执行")
    func findScriptRunsRepeatedly() throws {
        let context = try makeContext()
        context.evaluateScript(Self.pageStub)
        let script = BrowserAccessibilityScript.script(operation: "find", options: ["role": "button"])

        _ = evaluate(context, script)
        #expect(context.exception == nil)

        let second = evaluate(context, script)
        #expect(context.exception == nil)
        #expect(second?.objectForKeyedSubscript("total")?.toInt32() == 0)
    }

    @Test("交互脚本可在同一 JS 环境重复执行")
    func interactionScriptRunsRepeatedly() throws {
        let context = try makeContext()
        context.evaluateScript(Self.pageStub)
        let script = BrowserInteractionScript.script(action: .scroll, ref: nil, text: "down")

        let first = evaluate(context, script)
        #expect(context.exception == nil)
        #expect(first?.objectForKeyedSubscript("ok")?.toBool() == true)

        let second = evaluate(context, script)
        #expect(context.exception == nil)
        #expect(second?.objectForKeyedSubscript("ok")?.toBool() == true)
    }

    @Test("先快照后交互共享同一页面不重复声明")
    func snapshotThenInteractionSharePage() throws {
        let context = try makeContext()
        context.evaluateScript(Self.pageStub)

        let snapshot = evaluate(context, BrowserAccessibilityScript.script(operation: "snapshot"))
        #expect(context.exception == nil)
        #expect(snapshot?.objectForKeyedSubscript("total")?.toInt32() == 0)

        let interact = evaluate(context, BrowserInteractionScript.script(action: .scroll, ref: nil, text: "down"))
        #expect(context.exception == nil)
        #expect(interact?.objectForKeyedSubscript("ok")?.toBool() == true)
    }

    // MARK: - Harness

    private enum HarnessError: Error { case contextUnavailable }

    private func makeContext() throws -> JSContext {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        return context
    }

    private func evaluate(_ context: JSContext, _ script: String) -> JSValue? {
        context.exception = nil
        return context.evaluateScript(script)
    }

    /// 最小页面替身：空 body 让快照直接返回空树；scrollBy 让整页滚动可执行。
    private static let pageStub = #"""
    var window = { scrollBy: function () {} };
    var document = { body: null, documentElement: null, activeElement: null };
    """#
}