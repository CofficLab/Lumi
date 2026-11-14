import Foundation
import MLXLMCommon

enum MLXProviderError: LocalizedError {
    case unsupportedPlatform
    case emptyPrompt
    case modelNotAvailable(String)
    case invalidModelID(String)
    case downloadFailed(String)
    case loadFailed(String)
    case rejectedToolCall(RejectedToolCall)

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform: return "MLX 仅支持 Apple Silicon Mac"
        case .emptyPrompt: return "消息内容为空"
        case .modelNotAvailable(let model): return "MLX 模型未注册：\(model)"
        case .invalidModelID(let model): return "无效的 Hugging Face 模型 ID：\(model)"
        case .downloadFailed(let detail): return "MLX 模型下载失败：\(detail)"
        case .loadFailed(let detail): return "MLX 模型加载失败：\(detail)"
        case .rejectedToolCall(let rejection):
            // 只携带安全诊断（reason / toolName / detail）；
            // rawTextPreview 可能含敏感参数值，绝不进入错误描述。
            var message = "MLX 模型的工具调用被拒绝（\(rejection.reason.rawValue)）"
            if let toolName = rejection.toolName {
                message += "：\(toolName)"
            }
            if let detail = rejection.detail {
                message += "。\(detail)"
            }
            return message
        }
    }
}
