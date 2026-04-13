import Foundation

enum RAGError: LocalizedError {
    case notInitialized
    case invalidProjectPath
    case internalStateCorrupted
    case dbError(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "RAG 服务未初始化"
        case .invalidProjectPath:
            return "无效的项目路径"
        case .internalStateCorrupted:
            return "RAG 内部状态异常"
        case let .dbError(message):
            return "RAG 数据库错误：\(message)"
        }
    }
}
