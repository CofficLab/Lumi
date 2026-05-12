#if canImport(LumiPreviewKit)
import AppKit
import Foundation
import LumiPreviewKit

/// 编辑器预览格式化工具。
///
/// 提供错误消息格式化、性能摘要生成、图片解码等纯静态工具方法，
/// 供 ViewModel 和 Service 调用。
enum EditorPreviewFormatter {

    // MARK: - 公开方法

    /// 将 PreviewError 转换为用户友好的本地化错误消息。
    static func message(for error: PreviewError) -> String {
        switch error {
        case .targetNotFound(let file):
            String(
                format: String(localized: "No build target found for %@", table: "EditorPreview"),
                URL(fileURLWithPath: file).lastPathComponent
            )
        case .unsupportedProjectType(let path):
            String(
                format: String(localized: "Unsupported project type: %@", table: "EditorPreview"),
                path
            )
        case .compilationFailed(let message):
            message
        case .buildProductNotFound:
            String(localized: "Build product was not found.", table: "EditorPreview")
        case .hostLaunchFailed(let message):
            message
        case .runtimeCrashed(let message):
            message
        case .timedOut(let seconds):
            String(
                format: String(localized: "Timed out after %lld seconds.", table: "EditorPreview"),
                Int64(seconds)
            )
        case .missingDependency(let description):
            description
        }
    }

    /// 根据性能指标生成摘要文本。
    ///
    /// 返回类似 "Build 1.23s cached | Refresh 0.45s" 的格式，
    /// 无指标时返回 nil。
    static func performanceSummary(for metrics: PreviewPerformanceMetrics) -> String? {
        var parts: [String] = []
        if let compileDuration = metrics.lastCompileDuration {
            let cacheSuffix = metrics.lastCompileUsedCache
                ? String(localized: " cached", table: "EditorPreview") : ""
            parts.append(
                String(
                    format: String(localized: "Build %@%@", table: "EditorPreview"),
                    format(seconds: compileDuration),
                    cacheSuffix
                )
            )
        }
        if let loadDuration = metrics.lastLoadDuration {
            parts.append(
                String(
                    format: String(localized: "Load %@", table: "EditorPreview"),
                    format(seconds: loadDuration)
                )
            )
        }
        if let refreshDuration = metrics.lastRefreshDuration {
            parts.append(
                String(
                    format: String(localized: "Refresh %@", table: "EditorPreview"),
                    format(seconds: refreshDuration)
                )
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    /// 从渲染响应中解码预览图片。
    ///
    /// 尝试从 Base64 编码的 PNG 数据解码为 NSImage，失败时返回 nil。
    static func image(from response: RenderResponse) -> NSImage? {
        guard let previewImagePNGBase64 = response.previewImagePNGBase64,
              let data = Data(base64Encoded: previewImagePNGBase64) else {
            return nil
        }
        return NSImage(data: data)
    }

    // MARK: - 私有方法

    private static func format(seconds: TimeInterval) -> String {
        String(format: "%.2fs", seconds)
    }
}
#endif
