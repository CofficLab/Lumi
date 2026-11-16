import AppKit
import Foundation
import Testing
import WebKit

@testable import KitHTMLPreview

/// 存量选区桥（`onBlockSelected` → `selectionScript`）回传源码的回归测试。
///
/// 浮动按钮在 `showButton` 里被 `appendChild` 进区块元素，点击时若直接序列化
/// `el.outerHTML` 会把宿主注入的按钮带进发给助手的源码（#495）。这里用 JS 传输桩
/// 捕获真实脚本 `postMessage` 的载荷，再经真实 `decodeLegacyMessageBody` 解码，
/// 锁定「只回传用户原始标记」这一不变量。
@Suite("HTML preview legacy block selection serialization")
@MainActor
struct HTMLPreviewLegacySelectionScriptTests {
    @Test("sent block HTML excludes the host floating button and overlay")
    func serializedBlockExcludesHostOverlays() async throws {
        let body = try await captureSelection()
        let html = try #require(body["outerHTML"] as? String)

        #expect(!html.contains("data-promo-floating"))
        #expect(!html.contains("data-promo-highlight"))
        #expect(!html.contains("发给助手讨论"))
    }

    @Test("sent block HTML keeps the original document markup")
    func serializedBlockKeepsOriginalDocumentMarkup() async throws {
        let body = try await captureSelection()
        let selection = try #require(PromoBlockSelection.decodeLegacyMessageBody(body))

        #expect(selection.blockID == "hero")
        #expect(selection.outerHTML.hasPrefix("<section"))
        #expect(selection.outerHTML.contains("data-block=\"hero\""))
        #expect(selection.outerHTML.contains("<span id=\"keep\">original</span>"))
    }

    // MARK: - Harness

    /// 右键命中区块 → 点击浮动按钮 → 返回真实脚本回传的载荷。
    private func captureSelection() async throws -> [String: Any] {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        webView.loadHTMLString(
            """
            <html><body data-test-ready>
            <style>section { display:block; width:240px; height:90px; }</style>
            <section data-block="hero" data-block-label="Hero"><span id="keep">original</span><p>body</p></section>
            </body></html>
            """,
            baseURL: nil
        )
        try await waitForDocument(in: webView)
        _ = try await webView.evaluateJavaScript(Self.captureStub)
        _ = try await webView.evaluateJavaScript(HTMLPreviewLegacySelectionScript.source)
        let result = try await webView.evaluateJavaScript(Self.triggerScript)
        return try #require(result as? [String: Any])
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

    /// 用纯 JS 桩接管 WebKit 消息通道，同步捕获脚本回传的载荷（传输层非本 bug 所在）。
    private static let captureStub = """
    (function () {
        window.webkit = {
            messageHandlers: {
                promoBlockAction: {
                    postMessage: function (body) { window.__capturedPromoSelection = body; }
                }
            }
        };
    })();
    """

    private static let triggerScript = """
    (function () {
        var block = document.querySelector('[data-block="hero"]');
        if (!block) { return null; }
        block.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true }));
        var button = document.querySelector('[data-promo-floating]');
        if (!button) { return null; }
        button.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
        return window.__capturedPromoSelection || null;
    })();
    """
}