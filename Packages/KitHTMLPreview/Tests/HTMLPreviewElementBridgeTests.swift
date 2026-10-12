import AppKit
import Foundation
import Testing
import WebKit

@testable import KitHTMLPreview

@Suite("HTML preview element bridge")
@MainActor
struct HTMLPreviewElementBridgeTests {
    @Test("normalizes a decorative child to its button and includes its block parent")
    func resolvesInteractiveTargetAndParent() async throws {
        let webView = try await makeWebView(html: """
        <style>section { display:block; width:240px; height:90px; padding:10px; } button { width:200px; height:50px; }</style>
        <section data-block="actions" data-block-label="Actions">
          <button aria-label="Checkout"><span id="icon">→</span></button>
        </section>
        """)

        let candidates = try await inspect(webView, selector: "#icon")

        #expect(candidates.count == 2)
        _ = try #require(candidates.count == 2)
        #expect(candidates[0]["tagName"] as? String == "button")
        #expect(candidates[0]["label"] as? String == "Checkout")
        #expect(candidates[1]["blockID"] as? String == "actions")
    }

    @Test("prefers unique block selectors and falls back when block IDs repeat")
    func buildsUniqueSelectors() async throws {
        let webView = try await makeWebView(html: """
        <style>section { display:block; width:200px; height:50px; }</style>
        <section data-block="unique">One</section>
        <section data-block="repeat">Two</section>
        <section data-block="repeat" id="target">Three</section>
        """)

        let unique = try await inspect(webView, selector: #"[data-block="unique"]"#)
        let repeated = try await inspect(webView, selector: "#target")

        #expect(unique[0]["selector"] as? String == #"[data-block="unique"]"#)
        #expect(repeated[0]["selector"] as? String != #"[data-block="repeat"]"#)
        let repeatedSelector = try #require(repeated[0]["selector"] as? String)
        let count = try await webView.evaluateJavaScript("document.querySelectorAll(\(json(repeatedSelector))).length") as? Int
        #expect(count == 1)
    }

    @Test("bounds HTML and never serializes bridge markup")
    func boundsHTMLAndIsolatesOverlay() async throws {
        let largeText = String(repeating: "x", count: 30 * 1_024)
        let webView = try await makeWebView(html: """
        <style>#large { display:block; width:200px; height:50px; }</style>
        <section id="large">\(largeText)</section>
        """)

        _ = try await webView.evaluateJavaScript("window.__lumiElementBridge.highlight(document.querySelector('#large'))")
        let candidates = try await inspect(webView, selector: "#large")
        let html = try #require(candidates[0]["outerHTML"] as? String)

        #expect(candidates[0]["isOuterHTMLTruncated"] as? Bool == true)
        #expect(html.utf8.count <= 24 * 1_024)
        #expect(!html.contains("lumi-element-overlay"))
    }

    @Test("reinjection is idempotent and disposal removes the overlay")
    func reinjectionAndDisposal() async throws {
        let webView = try await makeWebView(html: """
        <style>#target { display:block; width:200px; height:50px; }</style>
        <section id="target">Target</section>
        """)

        _ = try await webView.evaluateJavaScript(HTMLPreviewElementBridgeScript.source)
        _ = try await webView.evaluateJavaScript("window.__lumiElementBridge.highlight(document.querySelector('#target'))")
        let before = try await webView.evaluateJavaScript("document.querySelectorAll('[data-lumi-element-overlay]').length") as? Int
        _ = try await webView.evaluateJavaScript("window.__lumiElementBridge.dispose()")
        let after = try await webView.evaluateJavaScript("document.querySelectorAll('[data-lumi-element-overlay]').length") as? Int

        #expect(before == 1)
        #expect(after == 0)
    }

    private func makeWebView(html: String) async throws -> WKWebView {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        webView.loadHTMLString("<html><body data-test-ready>\(html)</body></html>", baseURL: nil)
        try await waitForDocument(in: webView)
        _ = try await webView.evaluateJavaScript(HTMLPreviewElementBridgeScript.source)
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

    private func inspect(_ webView: WKWebView, selector: String) async throws -> [[String: Any]] {
        let script = "window.__lumiElementBridge.inspect(document.querySelector(\(json(selector))))"
        return try #require(try await webView.evaluateJavaScript(script) as? [[String: Any]])
    }

    private func json(_ value: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [value])
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }
}
