import AppKit
import Testing
import WebKit

@testable import KitHTMLPreview

@Suite("HTMLScreenshotter capture")
@MainActor
struct HTMLScreenshotterCaptureTests {

    @Test("captures a rendered web page into a non-empty image spanning all content")
    func capturesFullPage() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let html = """
        <html><body style="margin:0">
        <div style="height:500px;background:#ff0000"></div>
        </body></html>
        """
        _ = try await webView.loadHTMLString(html, baseURL: nil)

        let image = try await HTMLScreenshotter.capture(webView)

        #expect(image.size.width > 0)
        // The 500px-tall body must exceed the 200pt viewport, proving the
        // capture renders the full page rather than just the visible area.
        #expect(image.size.height >= 500)
    }

    @Test("throws an error for a web view with no rendered content")
    func throwsForEmptyDocument() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))

        await #expect(throws: Error.self) {
            _ = try await HTMLScreenshotter.capture(webView)
        }
    }
}
