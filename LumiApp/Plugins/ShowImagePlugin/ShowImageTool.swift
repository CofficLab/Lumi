import Foundation
import MagicKit
import SwiftUI
import AppKit
import os

/// 图片显示工具
///
/// 在 Lumi 的 UI 中显示指定图片。
/// 支持两种图片源：
/// 1. **本地文件路径**：以 `/` 开头的绝对路径，如 `/Users/name/Pictures/photo.png`
/// 2. **远程 URL**：有效的 HTTP/HTTPS URL，如 `https://example.com/image.png`
///
/// 工具会先在消息气泡内渲染图片缩略图（可点击放大预览），同时支持设置标题和说明文字。
///
/// ## 使用示例
///
/// 显示本地图片：
/// ```json
/// {
///   "source": "/Users/name/Documents/diagram.png",
///   "title": "架构图",
///   "caption": "系统架构图"
/// }
/// ```
///
/// 显示远程图片：
/// ```json
/// {
///   "source": "https://example.com/chart.png",
///   "title": "数据图表",
///   "caption": "2024 年 Q1 数据"
/// }
/// ```
struct ShowImageTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🖼️"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.show-image")

    let name = "show_image"
    let description = "Display an image in the chat UI. Accepts a local file path or a remote URL. Supports PNG, JPEG, GIF, and other common image formats. The image will be shown inline in the conversation with an optional title and caption."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "source": [
                    "type": "string",
                    "description": "The image source. Can be either a local file path (e.g., /Users/name/photo.png) or a remote URL (e.g., https://example.com/image.png)"
                ],
                "title": [
                    "type": "string",
                    "description": "Optional title for the image, displayed above the image"
                ],
                "caption": [
                    "type": "string",
                    "description": "Optional caption/description for the image, displayed below the image"
                ],
                "maxWidth": [
                    "type": "number",
                    "description": "Optional maximum width of the displayed image in pixels (default: 400, range: 100-800)"
                ]
            ],
            "required": ["source"]
        ]
    }

    init() {}

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let source = arguments["source"]?.value as? String, !source.isEmpty else {
            return "Error: Missing required 'source' parameter. Please provide a local file path or a remote URL."
        }

        let title = (arguments["title"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let caption = (arguments["caption"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var maxWidth = arguments["maxWidth"]?.value as? Int ?? 400
        maxWidth = max(100, min(800, maxWidth))

        if Self.verbose {
            Self.logger.info("\(self.t)🖼️ 显示图片：\(source)")
        }

        // 解析图片源
        let imageSource: ShowImageSource
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            imageSource = .remote(source)
        } else {
            imageSource = .local(source)
        }

        // 检查本地文件是否存在（仅本地路径）
        if case .local(let path) = imageSource {
            let fileURL = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                return "Error: File not found: \(path)"
            }
            // 检查文件扩展名
            let ext = fileURL.pathExtension.lowercased()
            let supportedExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "heic", "heif", "webp", "ico", "icns", "svg"]
            guard supportedExtensions.contains(ext) else {
                return "Error: Unsupported image format '\(ext)'. Supported formats: \(supportedExtensions.joined(separator: ", "))"
            }
        }

        // 通过 ShowImageState 触发图片显示
        await MainActor.run {
            ShowImageState.shared.showImage(
                source: imageSource,
                title: title.isEmpty ? nil : title,
                caption: caption.isEmpty ? nil : caption,
                maxWidth: maxWidth
            )
        }

        return "Image displayed successfully. Source: \(source)"
    }
}

// MARK: - Image Source

/// 图片来源
enum ShowImageSource: Equatable, Sendable {
    case local(String)   // 本地文件路径
    case remote(String)  // 远程 URL

    var stringValue: String {
        switch self {
        case .local(let path): return path
        case .remote(let url): return url
        }
    }

    var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }
}

// MARK: - Show Image State

/// 图片显示状态（@MainActor 单例）
///
/// 工具通过此单例触发图片显示，RootView 通过观察此单例来渲染图片。
@MainActor
final class ShowImageState: ObservableObject {
    static let shared = ShowImageState()

    struct DisplayItem: Identifiable, Equatable {
        let id = UUID()
        let source: ShowImageSource
        let title: String?
        let caption: String?
        let maxWidth: Int

        static func == (lhs: DisplayItem, rhs: DisplayItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published var displayItem: DisplayItem?

    func showImage(source: ShowImageSource, title: String? = nil, caption: String? = nil, maxWidth: Int = 400) {
        displayItem = DisplayItem(source: source, title: title, caption: caption, maxWidth: maxWidth)
    }

    func clear() {
        displayItem = nil
    }
}
