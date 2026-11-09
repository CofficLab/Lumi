import Foundation
import JavaScriptCore
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #1091：ref 由 Lumi 分配且唯一。
///
/// 页面预置的 `data-lumi-browser-ref` 既不可信也可能重复；
/// 快照必须覆盖它，交互遇到同名多元素时必须拒绝而不是操作第一个。
@Suite("Browser ref 分配与唯一性")
struct BrowserRefOwnershipTests {

    // MARK: - 快照

    @Test("快照覆盖页面预置的重复 ref，并沿用已分配的计数器")
    func snapshotReplacesPresetDuplicateRefs() throws {
        let first = try makeSnapshotContext(stateCounter: nil)
        #expect(try runSnapshot(first) == ["lumi-1", "lumi-2"])
        // 两个按钮原本都是 lumi-1，第二个被改写成 Lumi 新分配的值。
        #expect(elementAttribute(first, index: 1) == "lumi-2")
        // 计数器持久化在 window 上，下一次快照从这里继续。
        #expect(first.evaluateScript("window.__lumiBrowserState.counter")?.toInt32() == 2)

        let second = try makeSnapshotContext(stateCounter: 2)
        #expect(try runSnapshot(second) == ["lumi-3", "lumi-4"])
        #expect(elementAttribute(second, index: 0) == "lumi-3")
    }

    // MARK: - 交互

    @Test("同名 ref 匹配多个元素时拒绝交互")
    func interactionRejectsAmbiguousRef() throws {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.interactionHarness(matchCount: 2))

        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-1", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == false)
        let message = result?.objectForKeyedSubscript("message")?.toString() ?? ""
        #expect(message.contains("matches 2 elements"))
        #expect(context.objectForKeyedSubscript("__clicked")?.toInt32() == 0)
    }

    @Test("没有匹配元素时仍然报告失效 ref")
    func interactionReportsStaleRef() throws {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.interactionHarness(matchCount: 0))

        let result = context.evaluateScript(
            BrowserInteractionScript.script(action: .click, ref: "lumi-7", text: nil)
        )

        #expect(result?.objectForKeyedSubscript("ok")?.toBool() == false)
        let message = result?.objectForKeyedSubscript("message")?.toString() ?? ""
        #expect(message.hasPrefix("STALE_REF:lumi-7"))
    }

    // MARK: - Harness

    private enum HarnessError: Error {
        case contextUnavailable
    }

    private func makeSnapshotContext(stateCounter: Int?) throws -> JSContext {
        guard let context = JSContext() else { throw HarnessError.contextUnavailable }
        context.evaluateScript(Self.snapshotHarness(stateCounter: stateCounter))
        return context
    }

    private func runSnapshot(_ context: JSContext) throws -> [String] {
        let script = BrowserAccessibilityScript.script(operation: "snapshot")
        guard let result = context.evaluateScript(script),
              let nodes = result.objectForKeyedSubscript("nodes") else {
            throw HarnessError.contextUnavailable
        }
        let count = Int(nodes.forProperty("length")?.toInt32() ?? 0)
        return (0..<count).compactMap { index in
            nodes.atIndex(index)?.objectForKeyedSubscript("ref")?.toString()
        }
    }

    private func elementAttribute(_ context: JSContext, index: Int) -> String? {
        context.evaluateScript(
            "document.body.children[\(index)].getAttribute(\"data-lumi-browser-ref\")"
        )?.toString()
    }

    /// 两个按钮都预置了 `data-lumi-browser-ref="lumi-1"`；
    /// `stateCounter` 模拟同一页面里上一次快照留下的计数器。
    private static func snapshotHarness(stateCounter: Int?) -> String {
        let state = stateCounter.map { "var window = { __lumiBrowserState: { counter: \($0) } };" }
            ?? "var window = {};"
        return #"""
        function makeElement(tagName, text, presetRef) {
          var el = {
            nodeType: 1,
            tagName: tagName.toUpperCase(),
            children: [],
            childNodes: text ? [{ nodeType: 3, nodeValue: text }] : [],
            _attrs: {},
            getAttribute: function (name) {
              return this._attrs.hasOwnProperty(name) ? this._attrs[name] : null;
            },
            hasAttribute: function (name) { return this._attrs.hasOwnProperty(name); },
            setAttribute: function (name, value) { this._attrs[name] = String(value); },
            removeAttribute: function (name) { delete this._attrs[name]; },
            getClientRects: function () { return [{}]; },
            closest: function () { return null; },
            labels: null
          };
          if (presetRef) el._attrs["data-lumi-browser-ref"] = presetRef;
          return el;
        }

        var __body = makeElement("div", null, null);
        __body.children = [
          makeElement("button", "Delete", "lumi-1"),
          makeElement("button", "Save", "lumi-1")
        ];

        var document = {
          body: __body,
          documentElement: __body,
          activeElement: null,
          getElementById: function () { return null; }
        };
        \#(state)
        var location = { href: "https://example.com/" };
        var getComputedStyle = function () { return { display: "block", visibility: "visible" }; };
        """#
    }

    /// 交互脚本的 DOM 替身；`matchCount` 决定 querySelectorAll 的匹配数量。
    private static func interactionHarness(matchCount: Int) -> String {
        #"""
        class Event {
          constructor(type) { this.type = type; }
        }
        class MouseEvent extends Event {
          constructor(type, init) { super(type); this.init = init || {}; }
        }

        var __clicked = 0;
        function makeElement() {
          return {
            events: [],
            focus: function () {},
            scrollIntoView: function () {},
            getBoundingClientRect: function () {
              return { width: 100, height: 20, left: 0, top: 0 };
            },
            hasAttribute: function () { return false; },
            getAttribute: function () { return null; },
            dispatchEvent: function (event) { this.events.push(event.type); return true; },
            click: function () { __clicked += 1; }
          };
        }

        var __elements = [];
        var __count = \#(matchCount);
        for (var i = 0; i < __count; i++) __elements.push(makeElement());

        var document = {
          querySelectorAll: function () { return __elements; },
          querySelector: function () { return __elements[0] || null; },
          elementFromPoint: function () { return null; }
        };
        var getComputedStyle = function () { return { visibility: "visible", display: "block" }; };
        """#
    }
}
