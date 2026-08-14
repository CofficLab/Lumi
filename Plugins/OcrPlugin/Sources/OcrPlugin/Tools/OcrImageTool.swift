import Foundation
import KernelLumi
import UniformTypeIdentifiers

/// `ocr_image`：识别本地图片文件中的文字。
///
/// 基于 macOS Vision（设备端），完全离线——不联网、不调用第三方 API。
/// 输入为本地图片绝对路径，返回识别到的多行文本。
public struct OcrImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "ocr_image",
        displayName: "OCR Image",
        description: """
        Recognize and extract text from a local image file (PNG, JPEG, HEIC, TIFF, GIF, etc.) \
        using on-device macOS Vision. Fully offline — no network requests, no third-party APIs. \
        Provide an absolute file path. Optionally set 'language' to bias recognition (e.g. 'en', \
        'zh', 'zh-TW', 'ja', 'ko'); defaults to Simplified Chinese + English. \
        Returns the recognized text, line by line.
        """
    )

    public init() {}

    public var tags: Set<LumiToolTag> { [.fileSystem, .readOnly, .fast] }

    public var inputSchema: LumiJSONValue {
        let str = { (desc: String) in
            LumiJSONValue.object(["type": .string("string"), "description": .string(desc)])
        }
        return .object([
            "type": .string("object"),
            "properties": .object([
                "path": str("Absolute path to a local image file to run OCR on."),
                "language": str("Optional recognition language hint, e.g. 'en', 'zh', 'zh-TW', 'ja', 'ko', 'fr'. Defaults to Simplified Chinese + English."),
            ]),
            "required": .array([.string("path")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let raw = arguments.string("path"), !raw.isEmpty else {
            return "OCR Image"
        }
        return "OCR \(URL(fileURLWithPath: raw).lastPathComponent)"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        guard let rawPath = arguments.string("path")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return "Error: Missing required 'path' argument. Provide an absolute path to a local image."
        }

        let url = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL
        let path = url.path

        guard kernel.isPathAllowed(path) else {
            return "Error: Path access denied: \(path)"
        }

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

        let languages = Self.resolveLanguages(arguments.string("language"))

        do {
            try kernel.checkCancellation()
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
