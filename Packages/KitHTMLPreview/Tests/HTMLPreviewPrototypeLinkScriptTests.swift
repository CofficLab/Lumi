import AppKit
import Foundation
import Testing
import WebKit

@testable import KitHTMLPreview

@Suite("HTML preview prototype link script")
@MainActor
struct HTMLPreviewPrototypeLinkScriptTests {

    @Test("a hotspot click posts the declared link target")
    func hotspotClickPostsDeclaredTarget() async throws {
        let webView = try await makeWebView(html: """
        <style>button { display:block; width:200px; height:50px; }</style>
        <button data-prototype-link="02-detail">Open detail</button>
        """)

        let payload = try #require(try await capturedMessagesAfterClick(webView, selector: "button").first)

        #expect(payload["schemaVersion"] as? Int == 1)
        #expect(payload["action"] as? String == "prototypeLink")
        #expect(payload["navigationGeneration"] as? Int == 0)
        #expect(payload["target"] as? String == "02-detail")
    }

    @Test("a click on a decorative descendant resolves to the nearest hotspot")
    func descendantClickResolvesNearestHotspot() async throws {
        let webView = try await makeWebView(html: """
        <style>div { display:block; width:300px; height:90px; padding:10px; } button { width:200px; height:50px; }</style>
        <div data-prototype-link="00-home">
          <button data-prototype-link="02-detail"><span id="icon">→</span></button>
        </div>
        """)

        let payload = try #require(try await capturedMessagesAfterClick(webView, selector: "#icon").first)

        #expect(payload["target"] as? String == "02-detail")
    }

    @Test("blank link values are ignored")
    func blankTargetIgnored() async throws {
        let webView = try await makeWebView(html: """
        <style>button { display:block; width:200px; height:50px; }</style>
        <button data-prototype-link="   ">No target</button>
        """)

        let messages = try await capturedMessagesAfterClick(webView, selector: "button")

        #expect(messages.isEmpty)
    }

    @Test("clicks outside hotspots are ignored")
    func clickOutsideHotspotIgnored() async throws {
        let webView = try await makeWebView(html: """
        <style>section { display:block; width:200px; height:50px; }</style>
        <section id="plain">Plain content</section>
        """)

        let messages = try await capturedMessagesAfterClick(webView, selector: "#plain")

        #expect(messages.isEmpty)
    }

    @Test("the target is trimmed and bounded to 256 characters")
    func trimsAndBoundsTarget() async throws {
        let longTarget = String(repeating: "a", count: 300)
        let webView = try await makeWebView(html: """
        <style>button { display:block; width:200px; height:50px; }</style>
        <button data-prototype-link=" 02-detail ">Padded</button>
        <button id="long" data-prototype-link="\(longTarget)">Long</button>
        """)

        let padded = try #require(try await capturedMessagesAfterClick(webView, selector: "button").first)
        #expect(padded["target"] as? String == "02-detail")

        // 捕获数组在多次点击间累积，长目标的消息在末尾。
        let all = try await capturedMessagesAfterClick(webView, selector: "#long")
        let long = try #require(all.last)
        let target = try #require(long["target"] as? String)
        #expect(target.count == 256)
    }

    @Test("the default anchor navigation is prevented")
    func preventsDefaultOnAnchorHotspot() async throws {
        let webView = try await makeWebView(html: """
        <style>a { display:block; width:200px; height:50px; }</style>
        <a href="#fallback" data-prototype-link="02-detail">Anchor</a>
        """)

        let prevented = try #require(try await webView.evaluateJavaScript("""
            var event = new MouseEvent('click', { bubbles: true, cancelable: true });
            document.querySelector('a').dispatchEvent(event);
            event.defaultPrevented
            """) as? Bool)
        #expect(prevented)
    }

    @Test("disposal removes the listener and reinjection stays single-shot")
    func disposalAndReinjection() async throws {
        let webView = try await makeWebView(html: """
        <style>button { display:block; width:200px; height:50px; }</style>
        <button data-prototype-link="02-detail">Open detail</button>
        """)

        _ = try await webView.evaluateJavaScript("window.__lumiPrototypeLinkBridge.dispose()")
        let afterDispose = try await capturedMessagesAfterClick(webView, selector: "button")
        #expect(afterDispose.isEmpty)

        _ = try await webView.evaluateJavaScript(HTMLPreviewPrototypeLinkScript.source)
        let afterReinjection = try await capturedMessagesAfterClick(webView, selector: "button")
        #expect(afterReinjection.count == 1)
    }

    // MARK: - Helpers

    private func makeWebView(html: String) async throws -> WKWebView {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        webView.loadHTMLString("<html><body data-test-ready>\(html)</body></html>", baseURL: nil)
        try await waitForDocument(in: webView)
        // 用桩替换消息通道，直接捕获脚本回传的 payload（不经过 WKScriptMessageHandler）。
        _ = try await webView.evaluateJavaScript("""
            window.__capturedMessages = [];
            window.webkit = { messageHandlers: { lumiPrototypeLink: {
                postMessage: function (payload) { window.__capturedMessages.push(payload); }
            } } };
            """)
        _ = try await webView.evaluateJavaScript(HTMLPreviewPrototypeLinkScript.source)
        return webView
    }

    private func waitForDocument(in webView: WKWebView) async throws {
        for _ in 0..<100 {
            if (try? await webView.evaluateJavaScript(
                "document.readyState === 'complete' && document.body.hasAttribute('data-test-ready')"
            )) as? Bool == true {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("WKWebView did not finish loading")
    }

    @discardableResult
    private func capturedMessagesAfterClick(_ webView: WKWebView, selector: String) async throws -> [[String: Any]] {
        _ = try await webView.evaluateJavaScript("""
            var target = document.querySelector(\(json(selector)));
            target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            """)
        return try #require(try await webView.evaluateJavaScript("window.__capturedMessages") as? [[String: Any]])
    }

    private func json(_ value: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [value])
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }
}
