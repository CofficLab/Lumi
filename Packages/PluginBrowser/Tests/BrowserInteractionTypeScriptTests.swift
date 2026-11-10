import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #1059：type 动作必须按完整字符输入，
/// 不能把 surrogate pair 拆成两次赋值（DOM 会把孤立代理项变成替换字符）。
@Suite("Browser type 动作的 Unicode 输入")
struct BrowserInteractionTypeScriptTests {

    @Test("Emoji 与中文按完整字符输入")
    func typePreservesEmojiAndCJK() throws {
        let output = try runType(text: "A😀B中文")

        #expect(output.value == "A😀B中文")
        #expect(Set(output.keys) == Set(["A", "😀", "B", "中", "文"]))
        #expect(output.keys.count == 15, "每个字符应各触发 keydown/keypress/keyup 一次")
    }

    @Test("ZWJ 组合 Emoji 不被拆坏")
    func typePreservesZWJEmoji() throws {
        let family = "👨\u{200D}👩\u{200D}👧\u{200D}👦"
        let output = try runType(text: family)

        #expect(output.value == family)
    }

    @Test("组合附加符号不产生替换字符")
    func typePreservesCombiningMarks() throws {
        let text = "e\u{0301}cole"
        let output = try runType(text: text)

        #expect(output.value == text)
    }

    // MARK: - Harness

    private struct Output {
        let value: String
        let keys: [String]
    }

    private func runType(text: String) throws -> Output {
        guard let context = JSContext() else {
            throw HarnessError.contextUnavailable
        }
        context.evaluateScript(Self.harness)
        let script = BrowserInteractionScript.script(action: .type, ref: "lumi-1", text: text)
        let result = context.evaluateScript(script)
        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == true)

        let element = context.objectForKeyedSubscript("__el")
        let value = element?.objectForKeyedSubscript("value")?.toString() ?? ""
        let keys = (element?.objectForKeyedSubscript("keyLog")?.toArray() as? [String]) ?? []
        return Output(value: value, keys: keys)
    }

    private enum HarnessError: Error {
        case contextUnavailable
    }

    /// 最小 DOM 替身。`value` 的 setter 按 HTML 规范的 USVString 转换，
    /// 把孤立 surrogate 换成 U+FFFD——这是生产环境里 Emoji 被拆坏的原因。
    private static let harness = #"""
    var toUSVString = function (input) {
      var out = "";
      for (var i = 0; i < input.length; i++) {
        var code = input.charCodeAt(i);
        if (code >= 0xD800 && code <= 0xDBFF) {
          var next = input.charCodeAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            out += input[i] + input[i + 1];
            i++;
          } else {
            out += "\uFFFD";
          }
        } else if (code >= 0xDC00 && code <= 0xDFFF) {
          out += "\uFFFD";
        } else {
          out += input[i];
        }
      }
      return out;
    };

    class HTMLInputElement {
      constructor() {
        this._value = "";
        this.events = [];
        this.keyLog = [];
      }
      get value() { return this._value; }
      set value(next) { this._value = toUSVString(String(next)); }
    }
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

    var __el = new HTMLInputElement();
    __el.focus = function () {};
    __el.scrollIntoView = function () {};
    __el.getBoundingClientRect = function () {
      return { width: 100, height: 20, left: 0, top: 0 };
    };
    __el.hasAttribute = function () { return false; };
    __el.getAttribute = function (name) { return name === "type" ? "text" : null; };
    __el.dispatchEvent = function (event) {
      this.events.push(event.type);
      if (event.type === "keydown" || event.type === "keypress" || event.type === "keyup") {
        this.keyLog.push(event.key);
      }
      return true;
    };

    var document = {
      querySelector: function () { return __el; },
      querySelectorAll: function () { return [__el]; }
    };
    var getComputedStyle = function () { return { visibility: "visible", display: "block" }; };
    """#
}
