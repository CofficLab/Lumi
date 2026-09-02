import KitAgentTool
import AppKit
import Foundation

/// 读取本地图片并以视觉附件返回给 Agent。
public struct ReadImageTool: SuperAgentTool, @unchecked Sendable {
    public let name = "read_image"
    public let executionCapability: ToolExecutionCapability = .parallelReadOnly

    private static let maxImageBytes: Int64 = 10 * 1024 * 1024

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read a local image file and return it as a visual attachment so the model can inspect the image."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute path to a local PNG, JPEG, GIF, WebP, BMP, HEIC, or TIFF image."],
            ],
            "required": ["path"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments.stringValue("path") else { return "读取图片" }
        return "查看图片 " + URL(fileURLWithPath: path).lastPathComponent
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await executeResult(arguments: arguments).content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        guard let rawPath = arguments.stringValue("path"), !rawPath.isEmpty else {
            return ToolCallResult(content: "Error: Missing 'path' argument", isError: true)
        }

        let url = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL

        guard let mimeType = Self.mimeType(for: url.pathExtension) else {
            let format = url.pathExtension.isEmpty ? "unknown" : url.pathExtension
            return ToolCallResult(content: "Error: Unsupported image format: " + format, isError: true)
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard byteCount <= Self.maxImageBytes else {
                return ToolCallResult(
                    content: "Error: Image is too large (\(byteCount) bytes; maximum is \(Self.maxImageBytes) bytes).",
                    isError: true
                )
            }

            let data = try Data(contentsOf: url)
            guard let image = NSImage(data: data), image.isValid else {
                return ToolCallResult(content: "Error: Invalid or unreadable image: \(url.path)", isError: true)
            }

            let pixelSize = image.representations.reduce(into: (width: 0, height: 0)) { result, representation in
                result.width = max(result.width, representation.pixelsWide)
                result.height = max(result.height, representation.pixelsHigh)
            }

            let size = pixelSize.width > 0 && pixelSize.height > 0
                ? "\(pixelSize.width)×\(pixelSize.height)"
                : "unknown dimensions"
            let content = "已读取图片：\(url.lastPathComponent)（\(size)）。图片已附加到工具结果，可直接查看。"

            return ToolCallResult(
                content: content,
                images: [ImageAttachment(data: data, mimeType: mimeType, fileName: url.lastPathComponent)]
            )
        } catch {
            return ToolCallResult(content: "Error reading image: \(error.localizedDescription)", isError: true)
        }
    }

    private static func mimeType(for pathExtension: String) -> String? {
        switch pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "heic": return "image/heic"
        case "tif", "tiff": return "image/tiff"
        default: return nil
        }
    }
}
