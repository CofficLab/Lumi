import AppKit
import Foundation
import Vision

/// OCR 识别引擎：基于 macOS Vision 框架的纯本地文字识别。
///
/// 所有识别在设备端完成，**不调用任何第三方 API，不产生网络请求**。
/// 识别工作放在 `Task.detached` 中执行，避免 Vision 的同步推理阻塞调用线程；
/// `CGImage` 在 detached 内部创建与使用，不跨越 task 边界（Swift 6 Sendable 安全）。
public enum OcrEngine {
    /// 默认识别语言：简体中文 + 英文。
    public static let defaultLanguages: [String] = ["zh-Hans", "en-US"]

    /// 识别本地图片文件中的文字，返回按行拼接的文本。
    ///
    /// - Parameters:
    ///   - path: 本地图片文件绝对路径。
    ///   - languages: 识别语言列表（BCP 47 标签），默认简体中文 + 英文。
    /// - Returns: 识别到的文本（每行一条）；若图片中无文字则返回空字符串。
    public static func recognizeText(at path: String, languages: [String] = defaultLanguages) async throws -> String {
        let resolvedLanguages = languages
        return try await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                throw OcrError.fileNotFound(path)
            }
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                throw OcrError.notAFile(path)
            }

            guard let nsImage = NSImage(contentsOf: url),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw OcrError.invalidImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = resolvedLanguages

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw OcrError.recognitionFailed(error.localizedDescription)
            }

            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }
}

// MARK: - Errors

enum OcrError: LocalizedError, Equatable {
    case fileNotFound(String)
    case notAFile(String)
    case invalidImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Error: File not found: \(path)"
        case .notAFile(let path):
            return "Error: Path is a directory, not a file: \(path)"
        case .invalidImage:
            return "Error: The file could not be loaded as an image."
        case .recognitionFailed(let reason):
            return "Error: OCR failed - \(reason)"
        }
    }
}
