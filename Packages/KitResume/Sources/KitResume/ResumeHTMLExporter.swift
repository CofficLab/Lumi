import AppKit
import CoreGraphics
import Foundation
import KitHTMLPreview
import PDFKit
import WebKit

public enum ResumeExportError: LocalizedError, Equatable {
    case loadTimedOut
    case resourcesTimedOut
    case noPages
    case unexpectedPageSize(page: Int, expectedWidth: Double, expectedHeight: Double, actualWidth: Double, actualHeight: Double)
    case pageOverflow(pages: [Int])
    case pdfCreationFailed
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .loadTimedOut: "Timed out while loading resume HTML."
        case .resourcesTimedOut: "Timed out while waiting for images and fonts."
        case .noPages: "HTML contains no .resume-page elements."
        case .unexpectedPageSize(let page, let expectedWidth, let expectedHeight, let actualWidth, let actualHeight):
            "Page \(page) renders at \(actualWidth)x\(actualHeight) but the paper preset requires \(expectedWidth)x\(expectedHeight)."
        case .pageOverflow(let pages):
            "Content overflows .resume-page container(s): \(pages.map { String($0 + 1) }.joined(separator: ", ")). Reduce content or add another page."
        case .pdfCreationFailed: "Failed to create PDF from resume HTML."
        case .pngEncodingFailed: "Failed to encode resume PNG."
        }
    }
}

/// 导出页面检查结果：页数、每页渲染框与溢出情况。
public struct ResumePageInspection: Equatable, Sendable {
    public struct Page: Equatable, Sendable {
        public let index: Int
        public let top: Double
        public let left: Double
        public let width: Double
        public let height: Double
        /// 容器实际内容高度超过可视高度（会被 overflow: hidden 裁掉）。
        public let isOverflowing: Bool
    }

    public let pages: [Page]

    public var pageCount: Int { pages.count }
    public var overflowingPages: [Int] { pages.filter(\.isOverflowing).map(\.index) }
}

/// 简历 HTML → 矢量 PDF / 分 DPI PNG 导出管线。
///
/// 与 promo 插件的"整页栅格化"不同，本管线以每个 `.resume-page`
/// 容器为单位捕获 WebKit 矢量 PDF（文字可选中、字体内嵌），再按
/// 72dpi 点尺寸校正页面 mediaBox——PDF 页面即物理纸张，打印无缩放。
@MainActor
public enum ResumeHTMLExporter {

    /// 渲染并校验全部页面，返回合并后的矢量 PDF 文档。
    ///
    /// - Throws: 页面尺寸不符或内容溢出时抛出（见 `inspectPages`）。
    public static func renderPDFDocument(
        html: String,
        fileURL: URL?,
        paper: ResumePaperKind,
        loadTimeout: TimeInterval = 8,
        resourceTimeout: TimeInterval = 5
    ) async throws -> PDFDocument {
        let preset = ResumePaperSpec.preset(for: paper)
        let webView = try await loadWebView(html: html, fileURL: fileURL, paper: preset, loadTimeout: loadTimeout, resourceTimeout: resourceTimeout)
        let inspection = try await inspectPages(in: webView, preset: preset)

        let merged = PDFDocument()
        for page in inspection.pages {
            let frame = CGRect(x: page.left, y: page.top, width: page.width, height: page.height)
            let data = try await capturePDF(in: webView, rect: frame)
            guard let pageDocument = PDFDocument(data: data), let pdfPage = pageDocument.page(at: 0) else {
                throw ResumeExportError.pdfCreationFailed
            }
            // WebKit PDF 输出固定 1 CSS px = 0.75 pt；显式校正 mediaBox
            // 以保证页面尺寸与物理纸张严格一致。
            pdfPage.setBounds(CGRect(origin: .zero, size: preset.pdfSize), for: .mediaBox)
            merged.insert(pdfPage, at: merged.pageCount)
        }
        guard merged.pageCount > 0 else { throw ResumeExportError.pdfCreationFailed }
        return merged
    }

    /// 导出合并后的矢量 PDF 数据。
    public static func exportPDF(
        html: String,
        fileURL: URL?,
        paper: ResumePaperKind
    ) async throws -> Data {
        let document = try await renderPDFDocument(html: html, fileURL: fileURL, paper: paper)
        guard let data = document.dataRepresentation() else { throw ResumeExportError.pdfCreationFailed }
        return data
    }

    /// 导出单页 PNG（以矢量 PDF 为源按 DPI 栅格化）。
    ///
    /// - Parameters:
    ///   - pageIndex: 从 0 开始的页码。
    ///   - dpi: 96 / 150 / 300，决定输出像素密度。
    public static func exportPNG(
        html: String,
        fileURL: URL?,
        paper: ResumePaperKind,
        pageIndex: Int = 0,
        dpi: Int = ResumeExportResolution.print.rawValue
    ) async throws -> Data {
        let document = try await renderPDFDocument(html: html, fileURL: fileURL, paper: paper)
        guard pageIndex < document.pageCount, let page = document.page(at: pageIndex) else {
            throw ResumeExportError.noPages
        }
        return try rasterize(page: page, paper: ResumePaperSpec.preset(for: paper), dpi: dpi)
    }

    /// 导出全部页面 PNG。
    public static func exportPNGs(
        html: String,
        fileURL: URL?,
        paper: ResumePaperKind,
        dpi: Int = ResumeExportResolution.print.rawValue
    ) async throws -> [Data] {
        let document = try await renderPDFDocument(html: html, fileURL: fileURL, paper: paper)
        let preset = ResumePaperSpec.preset(for: paper)
        return try (0..<document.pageCount).compactMap { document.page(at: $0) }.map {
            try rasterize(page: $0, paper: preset, dpi: dpi)
        }
    }

    /// 将已渲染 PDF 文档中的单页栅格化为指定 DPI 的 PNG
    /// （供批量导出复用同一次渲染结果）。
    public static func pngData(page: PDFPage, paper: ResumePaperKind, dpi: Int) throws -> Data {
        try rasterize(page: page, paper: ResumePaperSpec.preset(for: paper), dpi: dpi)
    }

    /// 仅检查分页质量：页数、每页尺寸与溢出情况（lint 工具使用，
    /// 溢出只报告不抛错）。
    public static func inspectPages(
        html: String,
        fileURL: URL?,
        paper: ResumePaperKind,
        loadTimeout: TimeInterval = 8,
        resourceTimeout: TimeInterval = 5
    ) async throws -> ResumePageInspection {
        let preset = ResumePaperSpec.preset(for: paper)
        let webView = try await loadWebView(html: html, fileURL: fileURL, paper: preset, loadTimeout: loadTimeout, resourceTimeout: resourceTimeout)
        return try await inspectPages(in: webView, preset: preset, strict: false)
    }

    // MARK: - Web loading

    private static func loadWebView(
        html: String,
        fileURL: URL?,
        paper: ResumePaperPreset,
        loadTimeout: TimeInterval,
        resourceTimeout: TimeInterval
    ) async throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: CGRect(origin: .zero, size: paper.cgSize), configuration: configuration)
        let delegate = LoadDelegate()
        webView.navigationDelegate = delegate

        if let fileURL {
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }

        guard await delegate.waitForFinish(timeout: loadTimeout) else { throw ResumeExportError.loadTimedOut }
        try await disableMotion(in: webView)
        guard await waitForResources(in: webView, timeout: resourceTimeout) else {
            throw ResumeExportError.resourcesTimedOut
        }
        return webView
    }

    /// 测量每个 `.resume-page` 的渲染框、尺寸匹配与溢出情况。
    ///
    /// `strict` 为 true（导出路径）时，尺寸不符或溢出直接抛错；
    /// false（检查路径）时仅返回测量结果。
    private static func inspectPages(
        in webView: WKWebView,
        preset: ResumePaperPreset,
        strict: Bool = true
    ) async throws -> ResumePageInspection {
        let script = """
        (() => {
          const pages = Array.from(document.querySelectorAll('.resume-page'));
          return pages.map((page, index) => ({
            index: index,
            top: page.offsetTop,
            left: page.offsetLeft,
            width: page.offsetWidth,
            height: page.offsetHeight,
            scrollHeight: page.scrollHeight,
            clientHeight: page.clientHeight
          }));
        })()
        """
        guard let raw = try await webView.evaluateJavaScript(script) as? [[String: Any]], !raw.isEmpty else {
            throw ResumeExportError.noPages
        }

        func number(_ item: [String: Any], _ key: String) throws -> Double {
            guard let value = item[key] as? NSNumber else { throw ResumeExportError.noPages }
            return value.doubleValue
        }

        let pages: [ResumePageInspection.Page] = try raw.enumerated().map { offset, item in
            // 查询顺序即 DOM 顺序；即使脚本返回的 index 缺失也按枚举序兜底。
            let index = (item["index"] as? NSNumber)?.intValue ?? offset
            let top = try number(item, "top")
            let left = try number(item, "left")
            let width = try number(item, "width")
            let height = try number(item, "height")
            let scrollHeight = try number(item, "scrollHeight")
            let clientHeight = try number(item, "clientHeight")
            return ResumePageInspection.Page(
                index: index,
                top: top,
                left: left,
                width: width,
                height: height,
                isOverflowing: scrollHeight > clientHeight + 1
            )
        }

        if strict {
            for page in pages {
                guard abs(page.width - Double(preset.cssWidth)) <= 1, abs(page.height - Double(preset.cssHeight)) <= 1 else {
                    throw ResumeExportError.unexpectedPageSize(
                        page: page.index + 1,
                        expectedWidth: Double(preset.cssWidth),
                        expectedHeight: Double(preset.cssHeight),
                        actualWidth: page.width,
                        actualHeight: page.height
                    )
                }
            }
            let overflowing = pages.filter(\.isOverflowing).map { $0.index + 1 }
            guard overflowing.isEmpty else { throw ResumeExportError.pageOverflow(pages: overflowing) }
        }
        return ResumePageInspection(pages: pages)
    }

    // MARK: - Capture

    private static func capturePDF(in webView: WKWebView, rect: CGRect) async throws -> Data {
        let configuration = WKPDFConfiguration()
        configuration.rect = rect
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            webView.createPDF(configuration: configuration) { result in
                switch result {
                case .success(let data): continuation.resume(returning: data)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 以矢量 PDF 页为源，按目标 DPI 栅格化为 sRGB PNG。
    private static func rasterize(page: PDFPage, paper: ResumePaperPreset, dpi: Int) throws -> Data {
        let pixelSize = paper.pixelSize(dpi: dpi)
        let width = Int(pixelSize.width.rounded())
        let height = Int(pixelSize.height.rounded())
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ResumeExportError.pngEncodingFailed
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // PDFPage.draw 内部处理 PDF 坐标系（原点左下）到 CGContext 的映射，
        // 并自动按 mediaBox 与目标尺寸缩放。
        context.interpolationQuality = .high
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ResumeExportError.pngEncodingFailed
        }
        return data
    }

    // MARK: - Loading helpers

    private static func disableMotion(in webView: WKWebView) async throws {
        let script = """
        (() => {
          const style = document.createElement('style');
          style.textContent = '*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}';
          document.head.appendChild(style);
          return true;
        })()
        """
        _ = try await webView.evaluateJavaScript(script)
    }

    private static func waitForResources(in webView: WKWebView, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let script = """
        document.readyState === 'complete' &&
        Array.from(document.images).every(image => image.complete && image.naturalWidth > 0) &&
        (!document.fonts || document.fonts.status === 'loaded')
        """
        while Date() < deadline {
            if let ready = try? await webView.evaluateJavaScript(script) as? Bool, ready { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(true) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(false) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(false) }

        private func finish(_ success: Bool) {
            guard completedResult == nil else { return }
            completedResult = success
            continuation?.resume(returning: success)
            continuation = nil
        }
    }
}
