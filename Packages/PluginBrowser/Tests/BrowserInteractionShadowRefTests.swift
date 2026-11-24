import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #267：快照会深入 open shadow root 并给其中的元素分配
/// ref，但交互脚本此前只做 document 级 querySelectorAll，shadow root 里
/// 的元素永远报 STALE_REF。修复后 document 级查询无命中时按快照同样的
/// 方式深入 open shadow root 解析。
@Suite("Browser 交互脚本 shadow DOM ref 解析")
struct BrowserInteractionShadowRefTests {

    private enum HarnessError: Error {
        case contextUnavailable
    }

    /// shadow root 布局：匹配元素的所在位置。
    private enum ShadowLayout: String {
        case single       // 一层 open shadow root 内
        case nested       // 两层嵌套 open shadow root 内
        case missing      // 任何地方都没有该 ref
        case ambiguous    // 两个 shadow root 各有一个匹配
    }

    @Test("open shadow root 内的 ref 必须可解析并完成点击")
    func shadowRefResolvesIntoOpenShadowRoot() throws {
        try assertClickOutcome(layout: .single, expectedOK: true, expectedClicked: 1)
    }

    @Test("嵌套 open shadow root 内的 ref 必须递归解析")
    func nestedShadowRefResolves() throws {
        try assertClickOutcome(layout: .nested, expectedOK: true, expectedClicked: 1)
    }

    @Test("元素不存在时仍报告 STALE_REF")
    func missingShadowRefStillStale() throws {
        try assertClickOutcome(layout: .missing, expectedOK: false, expectedClicked: 0, expectedMessage: "STALE_REF:")
    }

    @Test("多个 shadow root 同时匹配时必须拒绝执行")
    func ambiguousShadowRefRejected() throws {
        try assertClickOutcome(layout: .ambiguous, expectedOK: false, expectedClicked: 0, expectedMessage: "AMBIGUOUS_REF:")
    }

    // MARK: - 断言辅助

    private func assertClickOutcome(
        layout: ShadowLayout,
        expectedOK: Bool,
        expectedClicked: Int,
        expectedMessage: String? = nil
    ) throws {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.harness(layout: layout))

        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == expectedOK)
        if let expectedMessage {
            let message = result?.objectForKeyedSubscript("message")?.toString() ?? ""
            #expect(message.contains(expectedMessage))
        } else {
            #expect(result?.objectForKeyedSubscript("message")?.toString() == "Clicked.")
        }
        #expect(context.objectForKeyedSubscript("__clicked")?.toInt32() == Int32(expectedClicked))
    }

    // MARK: - Harness

    /// 最小 DOM 替身：document 只含两个带 open shadow root 的宿主，
    /// ref 匹配由布局决定；document 级 ref 查询恒为空（元素都在 shadow root 里）。
    private static func harness(layout: ShadowLayout) -> String {
        #"""
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
        var __layout = "\#(layout.rawValue)";

        var __makeElement = function (tagName) {
          return {
            tagName: tagName,
            events: [],
            shadowRoot: null,
            focus: function () {},
            scrollIntoView: function () {},
            getBoundingClientRect: function () {
              return { width: 100, height: 20, left: 0, top: 0 };
            },
            hasAttribute: function () { return false; },
            getAttribute: function () { return null; },
            contains: function (other) { return other === this; },
            dispatchEvent: function (event) { this.events.push(event.type); return true; },
            click: function () { __clicked += 1; }
          };
        };

        var __shadowEl = __makeElement("BUTTON");
        var __nestedEl = __makeElement("BUTTON");
        var __shadowEl2 = __makeElement("BUTTON");

        var __innerRefMatches = __layout === "nested" ? [__nestedEl] : [];
        var __shadowARefMatches =
          (__layout === "single" || __layout === "ambiguous") ? [__shadowEl] : [];
        var __shadowBRefMatches = __layout === "ambiguous" ? [__shadowEl2] : [];

        var __innerShadow = {
          querySelectorAll: function (sel) {
            if (sel === "*") return [];
            return __innerRefMatches;
          }
        };
        var __innerHost = __makeElement("DIV");
        __innerHost.shadowRoot = __innerShadow;

        var __shadowA = {
          querySelectorAll: function (sel) {
            if (sel === "*") return [__innerHost];
            return __shadowARefMatches;
          }
        };
        var __host = __makeElement("DIV");
        __host.shadowRoot = __shadowA;

        var __shadowB = {
          querySelectorAll: function (sel) {
            if (sel === "*") return [];
            return __shadowBRefMatches;
          }
        };
        var __host2 = __makeElement("DIV");
        __host2.shadowRoot = __shadowB;

        var document = {
          querySelectorAll: function (sel) {
            if (sel === "*") return [__host, __host2];
            return [];
          },
          elementFromPoint: function () {
            return __layout === "nested" ? __nestedEl : __shadowEl;
          }
        };
        var getComputedStyle = function () { return { visibility: "visible", display: "block" }; };
        """#
    }
}
