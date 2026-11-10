import Foundation
import WebKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - 等待

/// 等待条件的类型。
enum BrowserWaitCondition: String, CaseIterable, Sendable {
    /// 等待某个 CSS 选择器出现。
    case selector
    /// 等待页面出现某段文本。
    case text
    /// 等待页面加载完成。
    case load
    /// 等待页面发生导航。
    case navigation
}

/// 等待的结果。
struct BrowserWaitResult: Sendable {
    var condition: BrowserWaitCondition
    var timedOut: Bool
    var detail: String
}

extension BrowserSession {
    /// 等待某个条件成立。
    ///
    /// 存在的意义是消除 LLM 的「盲猜 sleep」：异步渲染的页面用固定等待
    /// 猜测时间，要么白等、要么不够。这里改成轮询真实状态，
    /// 条件一成立立刻返回。
    ///
    /// - Parameters:
    ///   - condition: 等待条件。
    ///   - value: selector / text 的目标值；load 与 navigation 时忽略。
    ///   - timeout: 超时秒数。
    func wait(
        condition: BrowserWaitCondition,
        value: String?,
        timeout: TimeInterval
    ) async throws -> BrowserWaitResult {
        let limit = min(max(timeout, 0.5), 60)
        let deadline = Date().addingTimeInterval(limit)
        let pollInterval: TimeInterval = 0.15

        // 导航等待需要以「发起前后的 URL 是否变化」为判据。
        let urlBeforeNavigation = urlString

        while Date() < deadline {
            if try await isWaitConditionSatisfied(condition, value: value, urlBeforeNavigation: urlBeforeNavigation) {
                return BrowserWaitResult(
                    condition: condition,
                    timedOut: false,
                    detail: waitDetail(for: condition, value: value)
                )
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        return BrowserWaitResult(
            condition: condition,
            timedOut: true,
            detail: "Timed out after \(Int(limit))s waiting for \(waitDetail(for: condition, value: value))."
        )
    }

    private func isWaitConditionSatisfied(
        _ condition: BrowserWaitCondition,
        value: String?,
        urlBeforeNavigation: String
    ) async throws -> Bool {
        switch condition {
        case .load:
            return !webView.isLoading && urlString.isEmpty == false
        case .navigation:
            return urlString != urlBeforeNavigation && !webView.isLoading
        case .selector:
            guard let selector = value, !selector.isEmpty else { return false }
            return try await evaluateBoolean("!!document.querySelector(\(jsLiteral(selector)))")
        case .text:
            guard let text = value, !text.isEmpty else { return false }
            let literal = jsLiteral(text)
            return try await evaluateBoolean(
                "(document.body ? document.body.innerText : '').indexOf(\(literal)) !== -1"
            )
        }
    }

    private func waitDetail(for condition: BrowserWaitCondition, value: String?) -> String {
        switch condition {
        case .selector: return "selector \"\(value ?? "")\""
        case .text: return "text \"\(value ?? "")\""
        case .load: return "the page to finish loading"
        case .navigation: return "a navigation to happen"
        }
    }

    private func evaluateBoolean(_ expression: String) async throws -> Bool {
        let raw = try await webView.evaluateJavaScript("(() => { try { return !!(\(expression)); } catch (_) { return false; } })()")
        return (raw as? Bool) ?? false
    }

    /// 把字符串安全地编码成 JS 字面量。
    private func jsLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }
}

// MARK: - 导航

/// 导航动作。
enum BrowserNavigationAction: String, CaseIterable, Sendable {
    case back
    case forward
    case reload
    case goto

    var displayName: String {
        switch self {
        case .back: return "后退"
        case .forward: return "前进"
        case .reload: return "刷新"
        case .goto: return "跳转"
        }
    }
}

extension BrowserSession {
    /// 执行一次导航。
    ///
    /// - Parameters:
    ///   - action: 导航动作。
    ///   - url: `goto` 时的目标地址；其他动作忽略。
    func navigate(action: BrowserNavigationAction, url: URL?, localAccessApproved: Bool) async throws -> String {
        switch action {
        case .back:
            guard webView.canGoBack else {
                throw BrowserSession.SessionError.navigationUnavailable("There is no page to go back to.")
            }
            webView.goBack()
            await waitForInteractionNavigation()
        case .forward:
            guard webView.canGoForward else {
                throw BrowserSession.SessionError.navigationUnavailable("There is no page to go forward to.")
            }
            webView.goForward()
            await waitForInteractionNavigation()
        case .reload:
            webView.reload()
            await waitForInteractionNavigation()
        case .goto:
            guard let url else {
                throw BrowserSession.SessionError.invalidURL
            }
            try await navigate(to: url, localAccessApproved: localAccessApproved)
        }
        return "Title: \(title)\nURL: \(urlString)"
    }
}

// MARK: - JavaScript 执行

extension BrowserSession {
    /// 在页面上下文执行 JavaScript，返回 JSON 化的结果。
    ///
    /// 作为兜底手段存在：页面结构千变万化，穷举工具覆盖不了所有场景，
    /// 给 LLM 一个 escape hatch 比让它卡死强。
    ///
    /// - Parameter script: 要执行的脚本。
    func evaluate(script: String) async throws -> String {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BrowserSession.SessionError.invalidURL
        }
        guard trimmed.count <= 20_000 else {
            throw BrowserSession.SessionError.scriptTooLong
        }

        // 包成函数体并返回 JSON 字符串，这样结果一定可序列化。
        let wrapped = """
        (() => {
          try {
            const __result = (function() { \(trimmed) })();
            try { return JSON.stringify({ ok: true, value: __result === undefined ? null : __result }); }
            catch (e) { return JSON.stringify({ ok: true, value: String(__result) }); }
          } catch (e) {
            return JSON.stringify({ ok: false, error: String(e && e.message ? e.message : e) });
          }
        })()
        """

        guard let raw = try await webView.evaluateJavaScript(wrapped),
              let json = raw as? String,
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrowserSession.SessionError.noPage
        }

        let ok = (object["ok"] as? Bool) ?? false
        if !ok {
            throw BrowserSession.SessionError.scriptFailed((object["error"] as? String) ?? "Unknown error")
        }
        guard let value = object["value"] else {
            return "null"
        }
        if let text = value as? String {
            return text
        }
        if JSONSerialization.isValidJSONObject(value),
           let pretty = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        return String(describing: value)
    }
}

// MARK: - 截图

extension BrowserSession {
    /// 截取当前页面。
    ///
    /// - Parameter fullPage: 是否截取整页（纵向拼接）。
    /// - Returns: PNG 图片数据。
    func screenshot(fullPage: Bool) async throws -> Data {
        guard fullPage, let geometry = await fullPageGeometry() else {
            return try await capture(rect: nil, snapshotWidth: nil)
        }
        return try await captureFullPage(geometry)
    }

    /// 整页截图按几何上限降采样，再按附件大小上限逐级缩小。
    private func captureFullPage(_ geometry: BrowserScreenshotGeometry) async throws -> Data {
        var scale = geometry.outputScale
        var lastSize = 0
        // 最多再降采样两次；仍未达标就拒绝，避免无限重试。
        for _ in 0..<3 {
            let data = try await capture(
                rect: geometry.rect,
                snapshotWidth: geometry.snapshotWidth(scale: scale)
            )
            if data.count <= BrowserScreenshotGeometry.maxAttachmentBytes {
                return data
            }
            lastSize = data.count
            scale *= 0.5
        }
        throw SessionError.screenshotTooLarge(
            bytes: lastSize,
            limit: BrowserScreenshotGeometry.maxAttachmentBytes
        )
    }

    private func capture(rect: CGRect?, snapshotWidth: CGFloat?) async throws -> Data {
        let configuration = WKSnapshotConfiguration()
        if let rect {
            configuration.rect = rect
        }
        if let snapshotWidth {
            configuration.snapshotWidth = NSNumber(value: Double(snapshotWidth))
        }
        configuration.afterScreenUpdates = true

        #if os(macOS)
        let image = try await webView.takeSnapshot(configuration: configuration)
        guard let data = image.tiffRepresentation else {
            throw BrowserSession.SessionError.screenshotUnavailable
        }
        guard let bitmap = NSBitmapImageRep(data: data),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw BrowserSession.SessionError.screenshotUnavailable
        }
        return png
        #else
        let image = try await webView.takeSnapshot(configuration: configuration)
        guard let data = image.pngData() else {
            throw BrowserSession.SessionError.screenshotUnavailable
        }
        return data
        #endif
    }

    /// 计算整页内容的截图几何信息。
    private func fullPageGeometry() async -> BrowserScreenshotGeometry? {
        let script = """
        (() => {
          const body = document.body;
          const html = document.documentElement;
          const height = Math.max(
            body ? body.scrollHeight : 0,
            body ? body.offsetHeight : 0,
            html ? html.clientHeight : 0,
            html ? html.scrollHeight : 0,
            html ? html.offsetHeight : 0
          );
          const width = Math.max(
            body ? body.scrollWidth : 0,
            html ? html.clientWidth : 0,
            html ? html.scrollWidth : 0
          );
          return { height: height, width: width };
        })()
        """
        guard let raw = try? await webView.evaluateJavaScript(script),
              let size = raw as? [String: Any],
              let height = size["height"] as? Double,
              let width = size["width"] as? Double,
              height > 0, width > 0 else {
            return nil
        }
        return BrowserScreenshotGeometry.fitted(width: width, height: height)
    }
}

/// 整页截图的内容边界与降采样策略。
///
/// `WKSnapshotConfiguration.rect` 直接使用页面 CSS 尺寸；如果只钳制高度，
/// 极宽页面会让快照位图按宽度无界增长（issue #1060）。这里同时限制
/// 单边尺寸、总像素数，并为最终附件大小预留降采样空间。
struct BrowserScreenshotGeometry: Equatable {
    /// 单边上限（点）。
    static let maxDimension: CGFloat = 16_000
    /// 单张截图的总像素上限。
    static let maxPixels: CGFloat = 16_000_000
    /// 返回给模型的 PNG 附件大小上限。
    static let maxAttachmentBytes = 12 * 1_024 * 1_024

    let rect: CGRect
    /// 相对页面尺寸的输出缩放；1 表示按原尺寸输出。
    let outputScale: CGFloat

    static func fitted(width: CGFloat, height: CGFloat) -> BrowserScreenshotGeometry {
        let clampedWidth = min(max(width, 1), maxDimension)
        let clampedHeight = min(max(height, 1), maxDimension)
        let pixels = clampedWidth * clampedHeight
        let scale = pixels > maxPixels ? (maxPixels / pixels).squareRoot() : 1
        return BrowserScreenshotGeometry(
            rect: CGRect(x: 0, y: 0, width: clampedWidth, height: clampedHeight),
            outputScale: scale
        )
    }

    /// 指定缩放下的输出宽度（点）。
    func snapshotWidth(scale: CGFloat) -> CGFloat {
        max(1, rect.width * scale)
    }

    /// 按 `outputScale` 输出时的像素总数。
    var outputPixels: CGFloat {
        let scale = outputScale
        return rect.width * scale * rect.height * scale
    }
}
