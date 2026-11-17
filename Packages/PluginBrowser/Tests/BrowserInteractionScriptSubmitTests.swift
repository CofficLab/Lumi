import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #266：press Enter 曾同时「手动 dispatchEvent(submit)」和
/// 「requestSubmit()」，提交监听器会跑两次，且第一次事件的 preventDefault
/// 拦不住第二次提交流程。
///
/// 修复后只走一条提交链路：有 `requestSubmit` 时完全交给原生语义；
/// 兜底路径手动派发一次可取消 submit，未被取消才调用 `form.submit()`。
///
/// 用 JSContext 搭最小页面替身：表单分别计数 requestSubmit、submit 派发
/// 与原生提交三个入口，断言 Enter 只触发一次提交流程且取消语义被尊重。
@Suite("Browser 交互脚本 Enter 提交链路")
struct BrowserInteractionScriptSubmitTests {

    @Test("press Enter 在有 requestSubmit 时只触发一次原生提交流程（回归 #266）")
    func enterUsesRequestSubmitOnly() throws {
        let context = try makeContext(withRequestSubmit: true, cancelSubmit: false)
        let script = BrowserInteractionScript.script(action: .press, ref: "e1", text: "Enter")

        let result = context.evaluateScript(script)
        #expect(context.exception == nil)
        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(global(context, "requestSubmitCalls") == 1)
        #expect(global(context, "submitDispatches") == 0, "脚本不应手动派发 submit 事件")
        #expect(global(context, "nativeSubmitCalls") == 0)
    }

    @Test("press Enter 无 requestSubmit 时派发一次可取消 submit，未取消才原生提交（回归 #266）")
    func fallbackDispatchesSingleCancelableSubmit() throws {
        let context = try makeContext(withRequestSubmit: false, cancelSubmit: false)
        let script = BrowserInteractionScript.script(action: .press, ref: "e1", text: "Enter")

        let result = context.evaluateScript(script)
        #expect(context.exception == nil)
        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(global(context, "submitDispatches") == 1, "兜底路径只应派发一次 submit")
        #expect(global(context, "nativeSubmitCalls") == 1)
        #expect(global(context, "requestSubmitCalls") == 0)
    }

    @Test("press Enter 取消 submit 后不启动原生提交（回归 #266）")
    func fallbackRespectsCancellation() throws {
        let context = try makeContext(withRequestSubmit: false, cancelSubmit: true)
        let script = BrowserInteractionScript.script(action: .press, ref: "e1", text: "Enter")

        let result = context.evaluateScript(script)
        #expect(context.exception == nil)
        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(global(context, "submitDispatches") == 1)
        #expect(global(context, "nativeSubmitCalls") == 0, "submit 被取消后不应启动原生提交")
    }

    // MARK: - Harness

    private enum HarnessError: Error { case contextUnavailable }

    private func makeContext(withRequestSubmit: Bool, cancelSubmit: Bool) throws -> JSContext {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.pageStub(withRequestSubmit: withRequestSubmit, cancelSubmit: cancelSubmit))
        #expect(context.exception == nil)
        return context
    }

    private func global(_ context: JSContext, _ name: String) -> Int32 {
        context.globalObject.objectForKeyedSubscript(name).toInt32()
    }

    /// 最小页面替身：一个可见输入元素挂在 fake form 上，form 统计三个提交入口。
    private static func pageStub(withRequestSubmit: Bool, cancelSubmit: Bool) -> String {
        #"""
        function FakeEvent(type, init) {
          this.type = type;
          this.cancelable = !!(init && init.cancelable);
          this.__defaultPrevented = false;
        }
        FakeEvent.prototype.preventDefault = function () { this.__defaultPrevented = true; };
        var Event = FakeEvent;
        var KeyboardEvent = FakeEvent;
        var HTMLInputElement = function () {};
        var HTMLTextAreaElement = function () {};

        var submitListeners = [];
        var submitDispatches = 0;
        var requestSubmitCalls = 0;
        var nativeSubmitCalls = 0;

        var fakeForm = {
          addEventListener: function (type, fn) { if (type === "submit") submitListeners.push(fn); },
          dispatchEvent: function (event) {
            if (event.type !== "submit") return true;
            submitDispatches += 1;
            for (var i = 0; i < submitListeners.length; i++) submitListeners[i](event);
            return !event.__defaultPrevented;
          },
          submit: function () { nativeSubmitCalls += 1; }
        };
        if (WITH_REQUEST_SUBMIT) {
          fakeForm.requestSubmit = function () { requestSubmitCalls += 1; };
        }
        if (CANCEL_SUBMIT) {
          fakeForm.addEventListener("submit", function (event) { event.preventDefault(); });
        }

        var el = {
          focus: function () {},
          dispatchEvent: function (event) { return true; },
          getBoundingClientRect: function () {
            return { width: 10, height: 10, left: 0, top: 0, right: 10, bottom: 10 };
          },
          hasAttribute: function () { return false; },
          getAttribute: function () { return null; },
          isContentEditable: false,
          form: fakeForm
        };
        var document = { querySelectorAll: function () { return [el]; }, activeElement: null };
        var getComputedStyle = function () { return { visibility: "visible", display: "block" }; };
        var window = { scrollBy: function () {} };
        """#
        .replacingOccurrences(of: "WITH_REQUEST_SUBMIT", with: withRequestSubmit ? "true" : "false")
        .replacingOccurrences(of: "CANCEL_SUBMIT", with: cancelSubmit ? "true" : "false")
    }
}
