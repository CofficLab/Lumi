import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #832：非链接元素被遮挡时 click() 返回 `{ ok:false, message }`
/// 失败对象，但调用处用 `if (!click())` 做真值判断——JS 对象恒为真，
/// 遮挡失败被当成成功，`el.click()` 从未执行却返回 "Clicked."。
/// 修复后调用处检查 `.ok` 并原样回传失败对象，被遮挡的点击必须报告失败。
@Suite("Browser click 遮挡检测")
struct BrowserInteractionClickOcclusionTests {

    @Test("被遮挡的非链接元素点击必须报告失败且不执行真实点击")
    func coveredClickReportsFailureAndDoesNotClick() throws {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.harness(occluded: true))

        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == false)
        let message = result?.objectForKeyedSubscript("message")?.toString() ?? ""
        #expect(message.contains("covered by another element"))
        // 遮挡分支提前返回，真实 click() 不得执行。
        #expect(context.objectForKeyedSubscript("__clicked")?.toInt32() == 0)
    }

    @Test("未被遮挡的非链接元素点击成功并执行真实点击")
    func uncoveredClickSucceedsAndClicks() throws {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.harness(occluded: false))

        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(result?.objectForKeyedSubscript("message")?.toString() == "Clicked.")
        #expect(context.objectForKeyedSubscript("__clicked")?.toInt32() == 1)
    }

    // MARK: - Harness

    private enum HarnessError: Error {
        case contextUnavailable
    }

    /// 最小 DOM 替身：一个可见、可用、非链接的 BUTTON。
    /// `occluded=true` 时 `elementFromPoint` 命中一个覆盖按钮的全屏 overlay
    /// （既不是 el 也不被 el 包含）；`false` 时命中 el 自身，点击应当成功。
    private static func harness(occluded: Bool) -> String {
        let target = occluded ? "__overlay" : "__el"
        return #"""
        class HTMLInputElement {}
        class HTMLTextAreaElement {}
        class HTMLSelectElement {}

        class Event {
          constructor(type) { this.type = type; }
        }
        class MouseEvent extends Event {
          constructor(type, init) { super(type); this.init = init || {}; }
        }

        var __clicked = 0;
        var __el = {
          tagName: "BUTTON",
          events: [],
          focus: function () {},
          scrollIntoView: function () {},
          getBoundingClientRect: function () {
            return { width: 100, height: 20, left: 0, top: 0 };
          },
          hasAttribute: function () { return false; },
          getAttribute: function () { return null; },
          contains: function (other) { return other === __el; },
          dispatchEvent: function (event) { this.events.push(event.type); return true; },
          click: function () { __clicked += 1; }
        };
        var __overlay = { tagName: "DIV" };

        var document = {
          querySelectorAll: function () { return [__el]; },
          querySelector: function () { return __el; },
          elementFromPoint: function () { return \#(target); },
          addEventListener: function () {},
          removeEventListener: function () {}
        };
        var getComputedStyle = function () { return { visibility: "visible", display: "block" }; };
        """#
    }
}