import KitAgentTool
import Foundation
import UniformTypeIdentifiers

/// `ocr_image`：识别本地图片文件中的文字。
///
/// 基于 macOS Vision（设备端），完全离线——不联网、不调用第三方 API。
/// 输入为本地图片绝对路径，返回识别到的多行文本。
///
/// 由旧版 `LumiAgentTool` 迁移为 `SuperAgentTool`；移除 `kernel.checkCancellation()`
/// 与 `kernel.isPathAllowed()`（只读工具，无需沙盒授权）。
public struct OcrImageTool: SuperAgentTool {
    public let name = "ocr_image"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        """
        Recognize and extract text from a local image file (PNG, JPEG, HEIC, TIFF, GIF, etc.) \
        using on-device macOS Vision. Fully offline — no network requests, no third-party APIs. \
        Provide an absolute file path. Optionally set 'language' to bias recognition (e.g. 'en', \
        'zh', 'zh-TW', 'ja', 'ko'); defaults to Simplified Chinese + English. \
        Returns the recognized text, line by line.
        """
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Absolute path to a local image file to run OCR on.",
                ],
                "language": [
                    "type": "string",
                    "description": "Optional recognition language hint, e.g. 'en', 'zh', 'zh-TW', 'ja', 'ko', 'fr'. Defaults to Simplified Chinese + English.",
                ],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let raw = arguments["path"]?.value as? String, !raw.isEmpty else {
            return "OCR Image"
        }
        return "OCR \(URL(fileURLWithPath: raw).lastPathComponent)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let rawPath = (arguments["path"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawPath.isEmpty else {
            return "Error: Missing required 'path' argument. Provide an absolute path to a local image."
        }

        let url = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL
        let path = url.path

        guard FileManager.default.fileExists(atPath: path) else {
            return "Error: File not found: \(path)"
        }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            return "Error: Path is a directory, not a file: \(path)"
        }
        // 仅在能解析出 UTType 且明确不是图片时拒绝；未知扩展名放行交由 Vision 尝试。
        if let type = UTType(filenameExtension: url.pathExtension), !type.conforms(to: .image) {
            return "Error: Not an image file: \(url.lastPathComponent)"
        }

        let languages = Self.resolveLanguages(arguments["language"]?.value as? String)

        do {
            let text = try await OcrEngine.recognizeText(at: path, languages: languages)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "No text was recognized in the image."
            }
            return text
        } catch {
            return error.localizedDescription
        }
    }

    /// 把简短语言代码映射为 Vision 支持的 `recognitionLanguages`。
    static func resolveLanguages(_ hint: String?) -> [String] {
        guard let hint = hint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !hint.isEmpty else {
            return OcrEngine.defaultLanguages
        }
        switch hint {
        case "en", "english":
            return ["en-US"]
        case "zh", "zh-cn", "zh-hans", "chinese":
            return ["zh-Hans", "en-US"]
        case "zh-tw", "zh-hk", "zh-hant":
            return ["zh-Hant", "en-US"]
        case "ja", "japanese":
            return ["ja-JP", "en-US"]
        case "ko", "korean":
            return ["ko-KR", "en-US"]
        case "fr", "french":
            return ["fr-FR", "en-US"]
        case "de", "german":
            return ["de-DE", "en-US"]
        default:
            // 视作 BCP 47 标签直接使用。
            return [hint]
        }
    }
}
