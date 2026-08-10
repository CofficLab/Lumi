import AppKit
import SwiftUI
import WebKit

/// HTML 文件预览视图。
///
/// 使用 WKWebView 实时渲染 HTML 内容。
/// 可通过 `fileURL` 直接加载本地文件（支持相对资源引用），
/// 或通过 `htmlText` 加载纯 HTML 字符串。
public struct HTMLPreviewView: View {

    let htmlText: String
    let fileURL: URL?
    /// When set, the WebView renders at this logical size and scales down to fit the container.
    let contentSize: CGSize?
    /// 用户控制的额外缩放因子，叠加在「适应容器」的 fitScale 之上（1.0 = 适应）。
    /// 放大超过容器后内容可滚动查看（见 `previewContent`）。
    var zoomFactor: CGFloat
    var onWebViewResolved: ((WKWebView) -> Void)?

    /// 右键命中一个区块（`data-block` 或兜底语义块）后回调，携带区块标识与 `outerHTML`。
    var onBlockSelected: ((PromoBlockSelection) -> Void)?

    public init(
        htmlText: String,
        fileURL: URL? = nil,
        contentSize: CGSize? = nil,
        zoomFactor: CGFloat = 1.0,
        onWebViewResolved: ((WKWebView) -> Void)? = nil,
        onBlockSelected: ((PromoBlockSelection) -> Void)? = nil
    ) {
        self.htmlText = htmlText
        self.fileURL = fileURL
        self.contentSize = contentSize
        self.zoomFactor = zoomFactor
        self.onWebViewResolved = onWebViewResolved
        self.onBlockSelected = onBlockSelected
    }

    public var body: some View {
        Group {
            if htmlText.isEmpty {
                emptyView
            } else if contentSize != nil {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    PreviewBoardGrid()
                    previewContent
                }
            } else {
                previewContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewContent: some View {
        GeometryReader { geometry in
            let webViewSize = contentSize ?? geometry.size
            let fitScale = Self.fitScale(contentSize: contentSize, in: geometry.size)
            let effectiveScale = fitScale * zoomFactor
            // 缩放后内容实际占用的点尺寸；放大时以此为 frame，ScrollView 才能算出可滚动区域。
            let scaledWidth = webViewSize.width * effectiveScale
            let scaledHeight = webViewSize.height * effectiveScale

            let webView = _WKWebViewWrapper(
                html: htmlText,
                fileURL: fileURL,
                containerSize: webViewSize,
                onWebViewResolved: onWebViewResolved,
                onBlockSelected: onBlockSelected
            )
            .frame(width: webViewSize.width, height: webViewSize.height)
            // 锚点置顶左：放大时从左上角对齐而非居中，便于查看与滚动。
            .scaleEffect(effectiveScale, anchor: .topLeading)

            if effectiveScale > 1.0 {
                // 放大超过容器：用缩放后的实际尺寸作 frame，包进 ScrollView 让溢出部分可拖动查看。
                ScrollView([.horizontal, .vertical]) {
                    webView
                        .frame(width: scaledWidth, height: scaledHeight)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                // 适应 / 缩小：填满容器，无需滚动。
                webView
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private static func fitScale(contentSize: CGSize?, in containerSize: CGSize) -> CGFloat {
        guard let contentSize,
              contentSize.width > 0,
              contentSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return 1
        }
        return min(containerSize.width / contentSize.width, containerSize.height / contentSize.height)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No HTML content to preview.", comment: "Empty state when there is no HTML to render")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }
}

// MARK: - WKWebView Wrapper

private struct _WKWebViewWrapper: NSViewRepresentable {
    let html: String
    let fileURL: URL?
    let containerSize: CGSize
    let onWebViewResolved: ((WKWebView) -> Void)?
    let onBlockSelected: ((PromoBlockSelection) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onBlockSelected: onBlockSelected)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        // 注册消息通道：JS 把「选中区块 → 发送」事件回传给 Swift。
        // Coordinator 作为 messageHandler 必须以弱引用持有，避免 webview↔coordinator 保留环
        // （WebKit 常见坑：userContentController 强持有 handler）。
        userContentController.add(WeakScriptMessageHandler(proxy: context.coordinator), name: Self.messageHandlerName)
        config.userContentController = userContentController

        let webView = WKWebView(frame: CGRect(origin: .zero, size: containerSize), configuration: config)
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        DispatchQueue.main.async {
            onWebViewResolved?(webView)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 回调指针可能变化（闭包重建），同步给 coordinator。
        context.coordinator.onBlockSelected = onBlockSelected

        DispatchQueue.main.async {
            onWebViewResolved?(webView)
        }

        if webView.frame.size != containerSize {
            webView.frame = CGRect(origin: .zero, size: containerSize)
        }

        let loadKey = LoadKey(html: html, fileURL: fileURL)
        let didReload = context.coordinator.lastLoadKey != loadKey
        context.coordinator.lastLoadKey = loadKey

        switch HTMLPreviewLoadPlanner().loadRequest(html: html, fileURL: fileURL) {
        case .file(let fileURL, let readAccessURL):
            // 仅在内容变化时触发新加载；导航完成后 coordinator 会在 didFinish 重新注入 JS。
            if didReload {
                webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)
            }
        case .html(let html, let baseURL):
            if didReload {
                webView.loadHTMLString(html, baseURL: baseURL)
            }
        }

        // 即使不重载（首次已由 didFinish 处理），也兜底确保 JS 至少注入一次。
        if !didReload, !context.coordinator.didInjectSelectionScript {
            context.coordinator.injectSelectionScript(into: webView)
        }
    }

    static let messageHandlerName = "promoBlockAction"
}

// MARK: - Coordinator

/// 预览 webview 的协调器：导航 + 消息回传 + 选区脚本注入。
///
/// 作为文件级类型，便于 `WeakScriptMessageHandler` 以弱引用指向它，
/// 打破 `userContentController → handler → coordinator → webView` 的保留环。
fileprivate final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    weak var webView: WKWebView?
    var onBlockSelected: ((PromoBlockSelection) -> Void)?
    var lastLoadKey: LoadKey?
    /// 标记当前 webview 实例是否已注入选区脚本（重载后会被重置，需重新注入）。
    var didInjectSelectionScript = false

    init(onBlockSelected: ((PromoBlockSelection) -> Void)?) {
        self.onBlockSelected = onBlockSelected
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 每次导航完成（含 fileURL 重载）后注入/重注入选区脚本。
        injectSelectionScript(into: webView)
    }

    // MARK: WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == _WKWebViewWrapper.messageHandlerName else { return }
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              action == "send" else { return }
        let blockID = (body["blockID"] as? String) ?? "block"
        let label = (body["label"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? blockID
        let outerHTML = (body["outerHTML"] as? String) ?? ""
        let selection = PromoBlockSelection(blockID: blockID, label: label, outerHTML: outerHTML)
        onBlockSelected?(selection)
    }

    // MARK: Script injection

    func injectSelectionScript(into webView: WKWebView) {
        webView.evaluateJavaScript(Self.selectionScript) { [weak self] _, _ in
            self?.didInjectSelectionScript = true
        }
    }

    /// 选区交互脚本。
    ///
    /// 职责：
    /// 1. 拦截 `contextmenu`，定位最近的 `data-block`（缺省回退到最近的 `<section>`/
    ///    `<h1>`/`<img>` 等语义块），高亮并在其右上角浮一个「发给助手」按钮。
    /// 2. 点击浮动按钮 → 经 `webkit.messageHandlers.promoBlockAction` 回传
    ///    `{ action:"send", blockID, label, outerHTML }`。
    /// 3. 切换选中时清除上一个高亮；点击区块外区域取消选中。
    /// 脚本幂等：重复注入会先移除旧实例（`window.__promoBlockBridge`）。
    private static let selectionScript: String = """
    (function () {
        if (window.__promoBlockBridge && window.__promoBlockBridge.dispose) {
            window.__promoBlockBridge.dispose();
        }

        var current = null;        // 当前高亮元素
        var highlighter = null;    // 描边遮罩
        var floating = null;       // 浮动按钮

        function resolveBlock(target) {
            // 优先精确命中 data-block；否则向上找语义块兜底（存量/手写 HTML）。
            var el = target.closest
                ? target.closest('[data-block]')
                : null;
            if (el) { return el; }
            return target.closest
                ? target.closest('section, h1, h2, h3, img, [class~="screen"], [class~="copy"], [class~="device"]')
                : null;
        }

        function readLabel(el) {
            return el.getAttribute && el.getAttribute('data-block-label')
                || el.getAttribute && el.getAttribute('data-block')
                || el.tagName.toLowerCase();
        }

        function readBlockID(el) {
            return (el.getAttribute && el.getAttribute('data-block'))
                || el.tagName.toLowerCase();
        }

        function clearSelection() {
            if (highlighter) { highlighter.remove(); highlighter = null; }
            if (floating) { floating.remove(); floating = null; }
            current = null;
        }

        function showButton(el) {
            if (floating) { floating.remove(); }
            floating = document.createElement('div');
            floating.textContent = '💬 发给助手讨论';
            floating.setAttribute('data-promo-floating', '');
            floating.addEventListener('click', function (ev) {
                ev.stopPropagation();
                ev.preventDefault();
                try {
                    window.webkit.messageHandlers.promoBlockAction.postMessage({
                        action: 'send',
                        blockID: readBlockID(el),
                        label: readLabel(el),
                        outerHTML: el.outerHTML
                    });
                } catch (e) { /* 忽略 */ }
            });
            el.appendChild(floating);
        }

        function highlight(el) {
            if (current === el) { return; }
            clearSelection();
            current = el;
            highlighter = document.createElement('div');
            highlighter.setAttribute('data-promo-highlight', '');
            // 描边跟随元素：用绝对定位覆盖一层边框，避免改动元素自身 box-sizing。
            var rect = el.getBoundingClientRect();
            highlighter.style.position = 'absolute';
            highlighter.style.left = (rect.left + window.scrollX) + 'px';
            highlighter.style.top = (rect.top + window.scrollY) + 'px';
            highlighter.style.width = rect.width + 'px';
            highlighter.style.height = rect.height + 'px';
            highlighter.style.pointerEvents = 'none';
            highlighter.style.zIndex = '2147483646';
            document.body.appendChild(highlighter);
            showButton(el);
        }

        function onContextMenu(ev) {
            var el = resolveBlock(ev.target);
            if (!el) { clearSelection(); return; }
            ev.preventDefault();
            highlight(el);
        }

        function onPointerDown(ev) {
            if (!current) { return; }
            // 点击高亮区块之外（且非浮动按钮）则取消选中。
            if (ev.target.closest && ev.target.closest('[data-promo-floating]')) { return; }
            if (!current.contains(ev.target)) { clearSelection(); }
        }

        document.addEventListener('contextmenu', onContextMenu, true);
        document.addEventListener('mousedown', onPointerDown, true);

        window.__promoBlockBridge = {
            dispose: function () {
                document.removeEventListener('contextmenu', onContextMenu, true);
                document.removeEventListener('mousedown', onPointerDown, true);
                clearSelection();
            }
        };

        // 注入一次性样式（描边 + 浮动按钮）。
        if (!document.getElementById('promo-block-style')) {
            var css = ''
                + '[data-promo-highlight]{'
                + 'border:3px solid rgba(91,92,226,.95);'
                + 'border-radius:10px;'
                + 'box-shadow:0 0 0 4px rgba(91,92,226,.18);'
                + '}'
                + '[data-promo-floating]{'
                + 'position:absolute;'
                + 'right:10px;'
                + 'top:10px;'
                + 'transform:translateY(-120%);'
                + 'padding:6px 11px;'
                + 'font:600 13px -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;'
                + 'color:#fff;'
                + 'background:rgba(91,92,226,.96);'
                + 'border-radius:8px;'
                + 'box-shadow:0 4px 14px rgba(20,10,50,.34);'
                + 'cursor:pointer;'
                + 'white-space:nowrap;'
                + 'z-index:2147483647;'
                + '}';
            var style = document.createElement('style');
            style.id = 'promo-block-style';
            style.textContent = css;
            document.head.appendChild(style);
        }
    })();
    """
}

fileprivate struct LoadKey: Equatable {
    let html: String
    let fileURL: URL?
}

/// 弱引用代理 `WKScriptMessageHandler`，打破 userContentController → handler → coordinator → webView 的保留环。
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var proxy: Coordinator?

    init(proxy: Coordinator) {
        self.proxy = proxy
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        proxy?.userContentController(userContentController, didReceive: message)
    }
}
