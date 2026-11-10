import Foundation
import KitHTMLPreview
import WebKit

/// HTML 落盘与快照渲染服务。
///
/// ## 为什么要落盘
///
/// `Message.metadata` 是 `[String: String]`，LLM 画出来的界面可能有几十 KB。
/// 因此 HTML 源文件写到插件数据目录，消息里只记路径。
///
/// ## 为什么默认渲染 PNG 快照
///
/// 消息列表是 `List`，行内容会被惰性物化。若直接嵌 `WKWebView`：
/// - WebView 会抢走外层 `List` 的滚轮事件，用户滚不动聊天记录；
/// - 每次滚出视口再滚回来都会重建一个 WKWebView（一次完整 HTML 解析）。
///
/// 因此列表里默认展示预先渲染好的 PNG 快照（纯图片，不抢滚动、不重建）。
/// 快照不可用时才回退到直接加载 HTML。
@MainActor
enum HTMLCanvasStore {

    enum StoreError: LocalizedError {
        case missingHTML
        case writeFailed(String)
        case snapshotFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingHTML:
                return "The html argument is missing or empty."
            case .writeFailed(let reason):
                return "Failed to write HTML file: \(reason)"
            case .snapshotFailed(let reason):
                return "Failed to render HTML snapshot: \(reason)"
            }
        }
    }

    /// 写入 HTML 并渲染快照，返回载荷。
    ///
    /// - Parameters:
    ///   - html: 完整 HTML 文档。
    ///   - title: 卡片标题。
    ///   - width: 画布宽度（CSS 逻辑像素）。
    ///   - height: 画布高度（CSS 逻辑像素）。
    ///   - directory: 落盘目录（插件数据目录）。
    /// - Returns: 载荷，记录 HTML 与快照的文件路径。
    static func persist(
        html: String,
        title: String,
        width: Double,
        height: Double,
        directory: URL
    ) async throws -> HTMLCanvasPayload {
        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError.missingHTML
        }
        try Task.checkCancellation()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let identifier = UUID().uuidString
        let htmlURL = directory.appendingPathComponent("\(identifier).html", isDirectory: false)
        let snapshotURL = directory.appendingPathComponent("\(identifier).png", isDirectory: false)

        // 取消或写入失败时清掉半成品，避免留下没有卡片引用的孤儿文件。
        var committed = false
        defer {
            if !committed {
                try? FileManager.default.removeItem(at: htmlURL)
                try? FileManager.default.removeItem(at: snapshotURL)
            }
        }

        do {
            try html.write(to: htmlURL, atomically: true, encoding: .utf8)
        } catch {
            throw StoreError.writeFailed(error.localizedDescription)
        }
        try Task.checkCancellation()

        // 快照渲染失败不阻断整条链路：载荷里 snapshotPath 留空，
        // 渲染器会回退到直接加载 HTML 文件。
        var snapshotPath = ""
        if let data = try? await renderSnapshot(
            html: html,
            fileURL: htmlURL,
            size: CGSize(width: width, height: height)
        ) {
            // 渲染期间可能已被取消：不要再写出图片。
            try Task.checkCancellation()
            try? data.write(to: snapshotURL, options: .atomic)
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                snapshotPath = snapshotURL.path
            }
        }
        try Task.checkCancellation()

        committed = true
        return HTMLCanvasPayload(
            title: title,
            htmlPath: htmlURL.path,
            snapshotPath: snapshotPath,
            width: width,
            height: height
        )
    }

    /// 把 HTML 渲染成 PNG 数据。
    ///
    /// 走 `HTMLScreenshotter`（`createPDF` + 逐页栅格化），绕开 `takeSnapshot`
    /// 的 tile-based 渲染限制，不会出现黑色未渲染区域。
    ///
    /// - Note: 渲染期间禁用脚本执行。LLM 生成的 HTML 可能含有脚本，
    ///   在用户自己的机器上执行它们没有必要，也避免副作用。
    static func renderSnapshot(
        html: String,
        fileURL: URL?,
        size: CGSize,
        timeout: TimeInterval = 12
    ) async throws -> Data {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: size),
            configuration: configuration
        )
        let delegate = LoadDelegate()
        webView.navigationDelegate = delegate

        if let fileURL {
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }

        guard await delegate.waitForFinish(timeout: timeout) else {
            throw StoreError.snapshotFailed("timed out while loading HTML")
        }

        let image = try await HTMLScreenshotter.capture(webView, timeout: timeout)
        guard let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = NSBitmapImageRep(cgImage: sourceImage).representation(
                using: .png,
                properties: [:]
              ) else {
            throw StoreError.snapshotFailed("failed to encode PNG")
        }
        return data
    }

    /// 导航完成等待器。
    ///
    /// WebKit 的导航回调不保证送达，因此必须带超时兜底，
    /// 否则 continuation 永不恢复，调用方会永久挂起。
    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Bool, Never>?
        private var completedResult: Bool?

        func waitForFinish(timeout: TimeInterval) async -> Bool {
            if let completedResult { return completedResult }
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(timeout))
                    self?.finish(false)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finish(true)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finish(false)
        }

        private func finish(_ success: Bool) {
            guard completedResult == nil else { return }
            completedResult = success
            continuation?.resume(returning: success)
            continuation = nil
        }
    }
}
