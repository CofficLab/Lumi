import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #1093：可访问性快照把 contenteditable 的 ARIA textbox
/// 暴露为可交互文本框，`fill` / `type` 也必须真的能写入，
/// 否则调用方拿到一个「看起来能填、实际拒绝」的 ref。
@Suite("Browser 输入动作支持 contenteditable textbox")
struct BrowserInteractionContentEditableTests {

    @Test("fill 写入 contenteditable 内容并派发 input/change")
    func fillWritesContentEditableHost() throws {
        let output = try run(action: .fill, text: "hello")

        #expect(output.ok)
        #expect(output.text == "hello")
        #expect(output.events.contains("input"))
        #expect(output.events.contains("change"))
    }

    @Test("type 逐字符追加到 contenteditable 内容")
    func typeAppendsToContentEditableHost() throws {
        let output = try run(action: .type, text: "A😀")

        #expect(output.ok)
        #expect(output.text == "A😀")
        #expect(Set(output.keys) == ["A", "😀"])
        #expect(output.events.filter { $0 == "input" }.count == 2)
    }

    @Test("不可编辑的普通 div 仍然拒绝文本")
    func rejectsNonEditableHost() throws {
        let output = try run(action: .fill, text: "hello", contentEditable: false)

        #expect(!output.ok)
        #expect(output.text.isEmpty)
    }

    // MARK: - Harness

    private struct Output {
        let ok: Bool
        let text: String
        let events: [String]
        let keys: [String]
    }

    private func run(
        action: BrowserInteractionAction,
        text: String,
        contentEditable: Bool = true
    ) throws -> Output {
        guard let context = JSContext() else {
            throw HarnessError.contextUnavailable
        }
        context.evaluateScript(Self.harness(contentEditable: contentEditable))
        let script = BrowserInteractionScript.script(action: action, ref: "lumi-1", text: text)
        let result = context.evaluateScript(script)

        let element = context.objectForKeyedSubscript("__el")
        return Output(
            ok: result?.objectForKeyedSubscript("ok")?.toBool() ?? false,
            text: element?.objectForKeyedSubscript("textContent")?.toString() ?? "",
            events: (element?.objectForKeyedSubscript("events")?.toArray() as? [String]) ?? [],
            keys: (element?.objectForKeyedSubscript("keyLog")?.toArray() as? [String]) ?? []
        )
    }

    private enum HarnessError: Error {
        case contextUnavailable
    }

    /// 最小 DOM 替身：一个 contenteditable 的 div，没有 value 属性。
    private static func harness(contentEditable: Bool) -> String {
        let flag = contentEditable ? "true" : "false"
        return #"""
        class HTMLInputElement {}
        class HTMLTextAreaElement {}
        class HTMLSelectElement {}

        class KeyboardEvent {
          constructor(type, init) {
            this.type = type;
            this.key = (init && init.key) || "";
          }
        }
        class Event {
          constructor(type) { this.type = type; }
        }

        class DivElement {
          constructor() {
            this.tagName = "DIV";
            this.events = [];
            this.keyLog = [];
            this._text = "";
            this.isContentEditable = \#(flag);
          }
          get textContent() { return this._text; }
          set textContent(next) { this._text = String(next); }
          focus() {}
          scrollIntoView() {}
          getBoundingClientRect() {
            return { width: 100, height: 20, left: 0, top: 0 };
          }
          hasAttribute() { return false; }
          getAttribute() { return null; }
          dispatchEvent(event) {
            this.events.push(event.type);
            if (event.type === "keydown" || event.type === "keypress" || event.type === "keyup") {
              this.keyLog.push(event.key);
            }
            return true;
          }
        }

        var __el = new DivElement();
        var document = {
          querySelector: function () { return __el; },
          querySelectorAll: function () { return [__el]; }
        };
        var getComputedStyle = function () { return { visibility: "visible", display: "block" }; };
        """#
    }
}
