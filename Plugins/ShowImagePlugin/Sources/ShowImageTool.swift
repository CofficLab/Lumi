import AppKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os
import SwiftUI

// MARK: - Image Source

/// 图片来源
public enum ShowImageSource: Equatable, Sendable {
    case local(String)
    case remote(String)

    public var stringValue: String {
        switch self {
        case .local(let path): return path
        case .remote(let url): return url
        }
    }

    public var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }
}

// MARK: - Show Image State

/// 图片显示状态（@MainActor 单例）
///
/// 工具通过此单例触发图片显示，RootView 通过观察此单例来渲染图片。
@MainActor
public final class ShowImageState: ObservableObject {
    public static let shared = ShowImageState()

    public struct DisplayItem: Identifiable, Equatable {
        public let id = UUID()
        public let source: ShowImageSource
        public let title: String?
        public let caption: String?
        public let maxWidth: Int

        public static func == (lhs: DisplayItem, rhs: DisplayItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published public var displayItem: DisplayItem?

    public func showImage(source: ShowImageSource, title: String? = nil, caption: String? = nil, maxWidth: Int = 400) {
        displayItem = DisplayItem(source: source, title: title, caption: caption, maxWidth: maxWidth)
    }

    public func clear() {
        displayItem = nil
    }
}

// MARK: - Tool

/// 图片显示工具。
///
/// 在 Lumi 的 UI 中显示指定图片。
/// 支持两种图片源：
/// 1. **本地文件路径**：以 `/` 开头的绝对路径
/// 2. **远程 URL**：有效的 HTTP/HTTPS URL
public struct ShowImageTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🖼️"
    public nonisolated static let verbose: Bool = true
    static let defaultMaxWidth = 400
    static let minMaxWidth = 100
    static let maxMaxWidth = 800
    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.show-image")

    public static let info = LumiAgentToolInfo(
        id: "show_image",
        displayName: "Show Image",
        description: "Display an image in the chat UI. Accepts a local file path or a remote URL. Supports PNG, JPEG, GIF, and other common image formats. The image will be shown inline in the conversation with an optional title and caption."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "source": .object([
                    "type": .string("string"),
                    "description": .string("The image source. Can be either a local file path (e.g., /Users/name/photo.png) or a remote URL (e.g., https://example.com/image.png)"),
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Optional title for the image, displayed above the image"),
                ]),
                "caption": .object([
                    "type": .string("string"),
                    "description": .string("Optional caption/description for the image, displayed below the image"),
                ]),
                "maxWidth": .object([
                    "type": .string("integer"),
                    "description": .string("Optional maximum width of the displayed image in pixels (default: 400, range: 100-800)"),
                    "minimum": .int(Self.minMaxWidth),
                    "maximum": .int(Self.maxMaxWidth),
                ]),
            ]),
            "required": .array([.string("source")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "显示图片"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let rawSource = arguments.string("source") else {
            return "Error: Missing required 'source' parameter. Please provide a local file path or a remote URL."
        }
        let source = rawSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            return "Error: Missing required 'source' parameter. Please provide a local file path or a remote URL."
        }

        let title = (arguments.string("title") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = (arguments.string("caption") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let maxWidth = Self.normalizedMaxWidth(arguments["maxWidth"]?.anyValue)

        if Self.verbose {
            Self.logger.info("\(Self.t)🖼️ 显示图片：\(source)")
        }

        let imageSource: ShowImageSource
        do {
            imageSource = try Self.normalizedSource(from: source)
        } catch {
            return error.localizedDescription
        }

        if case .local(let path) = imageSource {
            let fileURL = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                return "Error: File not found: \(path)"
            }
            let ext = fileURL.pathExtension.lowercased()
            let supportedExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "heic", "heif", "webp", "ico", "icns", "svg"]
            guard supportedExtensions.contains(ext) else {
                return "Error: Unsupported image format '\(ext)'. Supported formats: \(supportedExtensions.joined(separator: ", "))"
            }
        }

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

    static func normalizedMaxWidth(_ value: Any?) -> Int {
        let rawMaxWidth: Int?
        if let int = value as? Int {
            rawMaxWidth = int
        } else if let double = value as? Double {
            rawMaxWidth = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            rawMaxWidth = int
        } else {
            rawMaxWidth = nil
        }

        return min(max(rawMaxWidth ?? defaultMaxWidth, minMaxWidth), maxMaxWidth)
    }

    static func normalizedSource(from source: String) throws -> ShowImageSource {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SourceError.missingSource
        }

        if let url = URL(string: trimmed), let scheme = url.scheme {
            switch scheme.lowercased() {
            case "http", "https":
                return .remote(url.absoluteString)
            case "file":
                return .local(url.path)
            default:
                throw SourceError.unsupportedScheme(scheme)
            }
        }

        return .local(trimmed)
    }

    enum SourceError: LocalizedError, Equatable {
        case missingSource
        case unsupportedScheme(String)

        var errorDescription: String? {
            switch self {
            case .missingSource:
                return "Error: Missing required 'source' parameter. Please provide a local file path or a remote URL."
            case .unsupportedScheme(let scheme):
                return "Error: Unsupported image URL scheme '\(scheme)'. Only HTTP/HTTPS URLs are supported."
            }
        }
    }
}
