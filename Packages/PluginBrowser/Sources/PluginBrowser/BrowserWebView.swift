import SwiftUI
import WebKit

#if os(macOS)
struct BrowserWebView: NSViewRepresentable {
    let session: BrowserSession

    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#elseif os(iOS)
struct BrowserWebView: UIViewRepresentable {
    let session: BrowserSession

    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#endif
