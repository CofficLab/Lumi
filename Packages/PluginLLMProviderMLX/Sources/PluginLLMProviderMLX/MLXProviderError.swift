import Foundation

enum MLXProviderError: LocalizedError {
    case unsupportedPlatform
    case emptyPrompt
    case modelNotAvailable(String)
    case invalidModelID(String)
    case downloadFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform: return "MLX 仅支持 Apple Silicon Mac"
        case .emptyPrompt: return "消息内容为空"
        case .modelNotAvailable(let model): return "MLX 模型未注册：\(model)"
        case .invalidModelID(let model): return "无效的 Hugging Face 模型 ID：\(model)"
        case .downloadFailed(let detail): return "MLX 模型下载失败：\(detail)"
        case .loadFailed(let detail): return "MLX 模型加载失败：\(detail)"
        }
    }
}
