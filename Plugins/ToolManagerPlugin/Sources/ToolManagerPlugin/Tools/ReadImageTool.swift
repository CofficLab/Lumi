import AppKit
import Foundation
import KernelLumi

/// Reads a local image and returns it as a visual attachment to the Agent.
public struct ReadImageTool: LumiAgentTool {
    private static let maxImageBytes: Int64 = 10 * 1024 * 1024

    public static let info = LumiAgentToolInfo(
        id: "read_image",
        displayName: "Read Image",
        description: "Read a local image file and return it as a visual attachment so the model can inspect the image."
    )
    public static let tags: Set<LumiToolTag> = [.fileSystem, .readOnly, .fast]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to a local PNG, JPEG, GIF, WebP, BMP, HEIC, or TIFF image.")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let path = arguments["path"]?.stringValue else { return "读取图片" }
        return "查看图片 " + URL(fileURLWithPath: path).lastPathComponent
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let rawPath = arguments["path"]?.stringValue, !rawPath.isEmpty else {
            return "Error: Missing 'path' argument"
        }

        let url = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL
        guard kernel.isPathAllowed(url.path) else {
            return "Error: Path access denied: " + url.path
        }

        guard let mimeType = Self.mimeType(for: url.pathExtension) else {
            let format = url.pathExtension.isEmpty ? "unknown" : url.pathExtension
            return "Error: Unsupported image format: " + format
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard byteCount <= Self.maxImageBytes else {
                return "Error: Image is too large (" + String(byteCount)
                    + " bytes; maximum is " + String(Self.maxImageBytes) + " bytes)."
            }

            let data = try Data(contentsOf: url)
            guard let image = NSImage(data: data), image.isValid else {
                return "Error: Invalid or unreadable image: " + url.path
            }

            let pixelSize = image.representations.reduce(into: (width: 0, height: 0)) { result, representation in
                result.width = max(result.width, representation.pixelsWide)
                result.height = max(result.height, representation.pixelsHigh)
            }

            kernel.attachImage(
                LumiImageAttachment(
                    mimeType: mimeType,
                    base64Data: data.base64EncodedString(),
                    fileName: url.lastPathComponent
                )
            )

            let size = pixelSize.width > 0 && pixelSize.height > 0
                ? String(pixelSize.width) + "×" + String(pixelSize.height)
                : "unknown dimensions"
            return "已读取图片：" + url.lastPathComponent + "（" + size + "）。图片已附加到工具结果，可直接查看。"
        } catch {
            return "Error reading image: " + error.localizedDescription
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
