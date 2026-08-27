import Foundation

public enum MLXDownloadStatus: Equatable, Sendable {
    case idle
    case downloading
    case paused
    case completed
    case failed(String)
}

public struct MLXDownloadProgress: Equatable, Sendable {
    public var fractionCompleted: Double = 0
    public var completedFiles: Int = 0
    public var totalFiles: Int = 0
    public var downloadedBytes: Int64 = 0
    public var totalBytes: Int64 = 0
    public var speed: Double?

    public var percentLabel: String { "\(Int(fractionCompleted * 100))%" }

    public var speedLabel: String {
        guard let speed, speed > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }
}

struct MLXHFFileEntry: Decodable, Sendable, Equatable {
    let type: String
    let path: String
    let size: Int64?
}

enum MLXDownloadError: LocalizedError {
    case invalidModelID(String)
    case invalidResponse
    case httpError(Int)
    case noFilesAvailable
    case missingRequiredFiles
    case incompleteFile(String)

    var errorDescription: String? {
        switch self {
        case .invalidModelID(let id): return "无效的模型 ID：\(id)"
        case .invalidResponse: return "无法读取 Hugging Face 模型文件列表"
        case .httpError(let code): return "Hugging Face 请求失败（HTTP \(code)）"
        case .noFilesAvailable: return "模型没有可下载的文件"
        case .missingRequiredFiles: return "模型缺少 MLX 所需的配置文件"
        case .incompleteFile(let path): return "模型文件未完整下载：\(path)"
        }
    }
}
