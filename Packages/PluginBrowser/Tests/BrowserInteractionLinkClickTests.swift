import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #265：`<a href>` 分支此前不做真实点击、直接返回 href 交
/// 上层打开，页面的 onclick / 路由拦截 / preventDefault 全被绕过。
/// 修复后链接同样走真实点击：页面处理器先运行，未阻止默认导航时由脚本
/// 补一次 preventDefault 阻断原生导航并回传 href（上层经本地审批打开），
/// 页面已阻止时不上报 href、不再导航。
@Suite("Browser 交互脚本链接真实点击")
struct BrowserInteractionLinkClickTests {

    private enum HarnessError: Error {
        case contextUnavailable
    }

    @Test("链接真实点击必须运行页面 onclick 并回传 href")
    func linkClickRunsHandlerAndReportsHref() throws {
        let context = try makeContext(onclick: "__state.handlerRuns += 1;")
        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(result?.objectForKeyedSubscript("href")?.toString() == "https://example.com/next")
        // 页面 onclick 已真实运行。
        #expect(context.objectForKeyedSubscript("__state")?.objectForKeyedSubscript("handlerRuns")?.toInt32() == 1)
        // 脚本补发了 preventDefault：原生导航被阻断，导航交给上层。
        #expect(context.objectForKeyedSubscript("__state")?.objectForKeyedSubscript("nativePrevented")?.toBool() == true)
    }

    @Test("页面 preventDefault 后不得上报 href 触发导航")
    func linkClickRespectsPreventDefault() throws {
        let context = try makeContext(onclick: "__state.handlerRuns += 1; event.preventDefault();")
        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(result?.objectForKeyedSubscript("href")?.toString() == "")
        let message = result?.objectForKeyedSubscript("message")?.toString() ?? ""
        #expect(message.contains("prevented default"))
        // 处理器已运行；脚本看到页面已阻止，不再额外干预（href 为空即契约）。
        #expect(context.objectForKeyedSubscript("__state")?.objectForKeyedSubscript("handlerRuns")?.toInt32() == 1)
    }

    @Test("target=_blank 链接点击后回传 href 交上层在同一会话打开")
    func blankLinkClickReportsHref() throws {
        let context = try makeContext(target: "_blank", onclick: "__state.handlerRuns += 1;")
        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(result?.objectForKeyedSubscript("href")?.toString() == "https://example.com/next")
        #expect(context.objectForKeyedSubscript("__state")?.objectForKeyedSubscript("handlerRuns")?.toInt32() == 1)
    }

    @Test("非链接元素的点击不补发 preventDefault")
    func nonLinkClickDoesNotPreventDefault() throws {
        let context = try makeContext(tagName: "BUTTON", withHref: false)
        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)
        #expect(result?.objectForKeyedSubscript("message")?.toString() == "Clicked.")
        #expect(context.objectForKeyedSubscript("__state")?.objectForKeyedSubscript("nativePrevented")?.toBool() == false)
    }

    // MARK: - Harness

    /// 最小 DOM 替身：可配置 tagName/href/target/onclick 的元素。
    /// `el.click()` 按真实事件次序运行：先目标上的 onclick，后 document
    /// 冒泡监听器；`preventDefault` 只翻转事件自身的 defaultPrevented。
    private func makeContext(
        tagName: String = "A",
        withHref: Bool = true,
        target: String = "",
        onclick: String = ""
    ) throws -> JSContext {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.harness(
            tagName: tagName,
            withHref: withHref,
            target: target,
            onclick: onclick
        ))
        return context
    }

    private static func harness(
        tagName: String,
        withHref: Bool,
        target: String,
        onclick: String
    ) -> String {
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

        var __clickListeners = [];
        var __state = {
          handlerRuns: 0,
          nativePrevented: false
        };

        var __el = {
          tagName: "\#(tagName)",
          href: \#(withHref ? "\"https://example.com/next\"" : "null"),
          target: "\#(target)",
          events: [],
          shadowRoot: null,
          focus: function () {},
          scrollIntoView: function () {},
          getBoundingClientRect: function () {
            return { width: 100, height: 20, left: 0, top: 0 };
          },
          hasAttribute: function (name) { return name === "href" && \#(withHref ? "true" : "false"); },
          getAttribute: function (name) { return name === "href" && \#(withHref ? "true" : "false") ? "/next" : null; },
          contains: function (other) { return other === this; },
          dispatchEvent: function (event) { this.events.push(event.type); return true; },
          click: function () {
            var event = {
              type: "click",
              defaultPrevented: false,
              preventDefault: function () { this.defaultPrevented = true; }
            };
            if (this.onclick) this.onclick(event);
            for (var i = 0; i < __clickListeners.length; i++) __clickListeners[i](event);
            __state.nativePrevented = event.defaultPrevented;
          }
        };
        \#(onclick.isEmpty ? "" : "__el.onclick = function (event) { \(onclick) };")

        var document = {
          querySelectorAll: function () { return [__el]; },
          querySelector: function () { return __el; },
          elementFromPoint: function () { return __el; },
          addEventListener: function (type, listener) {
            if (type === "click") __clickListeners.push(listener);
          },
          removeEventListener: function (type, listener) {
            var index = __clickListeners.indexOf(listener);
            if (index !== -1) __clickListeners.splice(index, 1);
          }
        };
        var getComputedStyle = function () { return { visibility: "visible", display: "block" }; };
        """#
    }
}
