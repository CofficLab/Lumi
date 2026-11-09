import AppKit
import KitAgentTool
import Foundation
import ProviderNetwork
import LumiLoggingKit
import os

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
/// 工具通过此单例触发图片显示，UI 层通过观察此单例来渲染图片。
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

// MARK: - Show Image Tool

/// 图片显示工具
///
/// 在 Lumi 的 UI 中显示指定图片。
/// 支持两种图片源：
/// 1. **本地文件路径**：以 `/` 开头的绝对路径
/// 2. **远程 URL**：有效的 HTTP/HTTPS URL
struct ShowImageTool: SuperAgentTool, SuperLog {
    nonisolated public static let emoji = "🖼️"
    nonisolated public static let verbose: Bool = false
    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.show-image")

    static let toolName = "show_image"
    static let defaultMaxWidth = 400
    static let minMaxWidth = 100
    static let maxMaxWidth = 800
    static let supportedImageExtensions = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "heic", "heif", "webp", "ico", "icns", "svg",
    ]

    private let network: (any NetworkProviding)?

    init(network: (any NetworkProviding)?) {
        self.network = network
    }

    var name: String { Self.toolName }

    func description(for language: LanguagePreference) -> String {
        "Display an image in the chat UI. Accepts a local file path or a remote URL. Supports PNG, JPEG, GIF, and other common image formats. The image will be shown inline in the conversation with an optional title and caption."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "source": [
                    "type": "string",
                    "description": "The image source. Can be either a local file path (e.g., /Users/name/photo.png) or a remote URL (e.g., https://example.com/image.png)",
                ],
                "title": [
                    "type": "string",
                    "description": "Optional title for the image, displayed above the image",
                ],
                "caption": [
                    "type": "string",
                    "description": "Optional caption/description for the image, displayed below the image",
                ],
                "maxWidth": [
                    "type": "integer",
                    "description": "Optional maximum width of the displayed image in pixels (default: 400, range: 100-800)",
                    "minimum": Self.minMaxWidth,
                    "maximum": Self.maxMaxWidth,
                ],
            ],
            "required": ["source"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "显示图片"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let source = arguments["source"]?.value as? String else {
            throw ShowImageError.missingSource
        }
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShowImageError.missingSource
        }

        let title = (arguments["title"]?.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = (arguments["caption"]?.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let maxWidth = Self.normalizedMaxWidth(arguments["maxWidth"]?.value)

        if Self.verbose {
            Self.logger.info("\(Self.t)🖼️ 显示图片：\(source)")
        }

        let imageSource = try Self.normalizedSource(from: source)

        if case .local(let path) = imageSource {
            try Self.validateLocalImage(at: path)
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

    // MARK: - Helpers

    /// 发布显示状态前校验本地图片源。
    ///
    /// 仅检查「路径存在 + 扩展名」会让目录和伪造文件也被宣告为显示成功，
    /// 因此这里还要确认它是可读的普通文件，并且内容真的能解码成图片。
    static func validateLocalImage(at path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ShowImageError.fileNotFound(path)
        }
        guard !isDirectory.boolValue else {
            throw ShowImageError.notAFile(path)
        }
        // 只用于判断格式；文件名本身仍按原始路径读取。`URL.pathExtension`
        // 对「name.png␠」这类文件名返回空，这里先去空白再取扩展名。
        let extensionName = (fileURL.lastPathComponent as NSString)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = (extensionName as NSString).pathExtension.lowercased()
        guard Self.supportedImageExtensions.contains(ext) else {
            throw ShowImageError.unsupportedFormat(ext: ext, supported: Self.supportedImageExtensions)
        }
        guard FileManager.default.isReadableFile(atPath: path),
              let data = try? Data(contentsOf: fileURL)
        else {
            throw ShowImageError.unreadableFile(path)
        }
        // 与 Overlay 的渲染路径保持一致（`NSImage(data:)`）。`NSImage` 是延迟解码的，
        // 截断的数据头（如只有 JPEG SOI 的 4 字节）也能构造出实例，因此必须再确认
        // 它真的解析出了 representation。
        guard let image = NSImage(data: data), !image.representations.isEmpty else {
            throw ShowImageError.undecodableImage(path)
        }
    }

    static func normalizedMaxWidth(_ value: Any?) -> Int {
        let rawMaxWidth = ToolArgumentNumber.int(value) ?? defaultMaxWidth
        return min(max(rawMaxWidth, minMaxWidth), maxMaxWidth)
    }

    static func normalizedSource(from source: String) throws -> ShowImageSource {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShowImageError.missingSource
        }

        // URL 可能被粘贴时带上首尾空白，按 trim 后解析；本地路径则必须逐字节保留，
        // 因为首尾空白可以属于真实文件名，裁剪会指向另一个文件。
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme {
            switch scheme.lowercased() {
            case "http", "https":
                // `https:image.png`、`http:///image.png` 都有 http(s) scheme，却没有
                // authority/host，不能作为远程图片来源发布（issue #1066）。
                guard let host = url.host, !host.isEmpty else {
                    throw ShowImageError.missingRemoteHost(url.absoluteString)
                }
                return .remote(url.absoluteString)
            case "file":
                // `file://server/tmp/x.png` 的 host 是 server，路径只是远端机器上
                // 的路径；丢弃 authority 会把它静默换成本机同名文件（issue #1094）。
                // 只有空 authority 与 localhost 才指向本机。
                if let host = url.host, !host.isEmpty, host.lowercased() != "localhost" {
                    throw ShowImageError.nonLocalFileHost(url.absoluteString)
                }
                return .local(url.path)
            default:
                throw ShowImageError.unsupportedScheme(scheme)
            }
        }

        return .local(source)
    }

    /// 校验失败必须抛出，而不是返回 `"Error: ..."` 文本：工具结果的成功/失败
    /// 由 `ToolCallResult.isError` 决定，字符串里写 Error 对上层是成功语义。
    enum ShowImageError: LocalizedError, Equatable {
        case missingSource
        case unsupportedScheme(String)
        case missingRemoteHost(String)
        case nonLocalFileHost(String)
        case fileNotFound(String)
        case notAFile(String)
        case unreadableFile(String)
        case undecodableImage(String)
        case unsupportedFormat(ext: String, supported: [String])

        var errorDescription: String? {
            switch self {
            case .missingSource:
                return "Error: Missing required 'source' parameter. Please provide a local file path or a remote URL."
            case .unsupportedScheme(let scheme):
                return "Error: Unsupported image URL scheme '\(scheme)'. Only HTTP/HTTPS URLs are supported."
            case .missingRemoteHost(let url):
                return "Error: Remote image URL has no host: \(url)"
            case .nonLocalFileHost(let url):
                return "Error: File URL refers to a remote host, but only local files are supported: \(url)"
            case .fileNotFound(let path):
                return "Error: File not found: \(path)"
            case .notAFile(let path):
                return "Error: Not a regular file: \(path)"
            case .unreadableFile(let path):
                return "Error: Cannot read file: \(path)"
            case .undecodableImage(let path):
                return "Error: Not a decodable image: \(path)"
            case .unsupportedFormat(let ext, let supported):
                return "Error: Unsupported image format '\(ext)'. Supported formats: \(supported.joined(separator: ", "))"
            }
        }
    }
}
