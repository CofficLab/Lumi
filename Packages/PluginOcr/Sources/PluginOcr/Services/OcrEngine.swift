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
        try Task.checkCancellation()

        let resolvedLanguages = languages
        let completion = InferenceCompletionBox()
        // Vision 的同步 perform 无法中断，推理本身仍在 detached 中跑完；
        // 但外层等待必须响应取消（#270）：轮询外层取消状态，命中即立刻抛出
        // CancellationError 释放 Job，迟到的推理结果被丢弃。
        let work = Task.detached(priority: .userInitiated) {
            defer { completion.markFinished() }
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
        }

        return try await awaitInference(work, completion: completion)
    }

    /// 等待推理任务完成，期间轮询外层任务的取消状态：命中取消立即抛出，
    /// 不再等 Vision 推理自然结束（#270）。
    static func awaitInference<T: Sendable>(_ work: Task<T, Error>, completion: InferenceCompletionBox) async throws -> T {
        while !completion.isFinished {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return try await work.value
    }
}

/// 推理完成信号：Task 没有可查询的 isCompleted，轮询等待用它判定推理是否结束。
final class InferenceCompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func markFinished() {
        lock.lock()
        finished = true
        lock.unlock()
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
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
