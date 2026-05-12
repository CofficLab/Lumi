import Foundation

/// LSP Error Taxonomy for Xcode Projects
/// 将统一的 "No definition found" 细分为可操作的错误类型
public enum XcodeLSPError: LocalizedError, Equatable {

    /// 服务器未启动
    case serverNotStarted

    /// 服务器已断开连接
    case serverDisconnected

    /// 没有项目上下文
    case noProjectContext

    /// Build context 不可用
    case buildContextUnavailable(String)

    /// 符号未解析（sourcekit-lsp 返回 nil）
    case symbolNotResolved(symbolName: String?)

    /// 符号不存在
    case symbolNotFound

    /// 索引未完成
    case indexingInProgress

    /// 文件不属于任何 target
    case fileNotInTarget(String)

    /// 文件属于多个 target，当前 scheme 无法唯一确定语义上下文
    case fileInMultipleTargets(file: String, targets: [String], activeScheme: String?)

    /// 文件命中了 target，但当前 active scheme 不包含这些 target
    case fileTargetsExcludedByActiveScheme(file: String, targets: [String], activeScheme: String?)

    /// LSP 请求超时
    case requestTimeout

    /// 未知错误
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .serverNotStarted:
            return "LSP server not started, unable to process request"
        case .serverDisconnected:
            return "LSP server connection lost, attempting to reconnect..."
        case .noProjectContext:
            return "Current file is not bound to a valid Xcode project context"
        case .buildContextUnavailable(let reason):
            return "Build context unavailable: \(reason)"
        case .symbolNotResolved(let symbol):
            let symbolPart = symbol.map { " '\($0)'" } ?? ""
            return "Unable to resolve symbol" + symbolPart
        case .symbolNotFound:
            return "No matching symbol found"
        case .indexingInProgress:
            return "Project is being indexed, semantic navigation may be incomplete"
        case .fileNotInTarget(let file):
            return "'\(file)' does not belong to any compilation target, please check if the file is in the project"
        case .fileInMultipleTargets(let file, let targets, let activeScheme):
            let targetList = targets.joined(separator: ", ")
            if let activeScheme, !activeScheme.isEmpty {
                return "'\(file)' belongs to multiple targets (\(targetList)), current scheme '\(activeScheme)' cannot uniquely determine semantic context"
            }
            return "'\(file)' belongs to multiple targets (\(targetList)), cannot uniquely determine semantic context"
        case .fileTargetsExcludedByActiveScheme(let file, let targets, let activeScheme):
            let targetList = targets.joined(separator: ", ")
            if let activeScheme, !activeScheme.isEmpty {
                return "'\(file)' belongs to target (\(targetList)), but current scheme '\(activeScheme)' does not include these targets"
            }
            return "'\(file)' belongs to target (\(targetList)), but current active scheme does not include these targets"
        case .requestTimeout:
            return "LSP request timed out, please try again later"
        case .unknown(let message):
            return message
        }
    }

    /// 用户可操作的建议
    public var suggestedAction: String? {
        switch self {
        case .serverNotStarted:
            return "Try reopening the file or restarting Lumi"
        case .serverDisconnected:
            return "Wait for auto-reconnect, or manually switch files to trigger rebuild"
        case .noProjectContext:
            return "Ensure .xcodeproj/.xcworkspace is in the project root directory"
        case .buildContextUnavailable:
            return "Run brew install xcode-build-server and reopen the project"
        case .symbolNotResolved:
            return "Wait for indexing to complete and retry, or check sourcekit-lsp logs"
        case .symbolNotFound:
            return nil
        case .indexingInProgress:
            return "Wait for indexing to complete and try again"
        case .fileNotInTarget:
            return "Add the file to a target"
        case .fileInMultipleTargets:
            return "Switch to a more specific scheme, or keep only one target membership and retry"
        case .fileTargetsExcludedByActiveScheme:
            return "Switch to a scheme that includes the file's target and retry"
        case .requestTimeout:
            return "Try again"
        case .unknown:
            return nil
        }
    }

    /// 错误分类（用于日志和统计）
    public var category: String {
        switch self {
        case .serverNotStarted, .serverDisconnected:
            return "server"
        case .noProjectContext, .fileNotInTarget, .fileInMultipleTargets, .fileTargetsExcludedByActiveScheme:
            return "project"
        case .buildContextUnavailable:
            return "build"
        case .symbolNotResolved, .symbolNotFound, .indexingInProgress:
            return "semantic"
        case .requestTimeout:
            return "timeout"
        case .unknown:
            return "unknown"
        }
    }

    /// 是否需要用户干预
    public var requiresUserAction: Bool {
        switch self {
        case .serverDisconnected, .indexingInProgress:
            return false
        default:
            return true
        }
    }
}

/// LSP 错误上下文
public struct LSPErrorContext: Sendable {
    public let uri: String?
    public let symbolName: String?
    public let operation: String?

    public init(uri: String? = nil, symbolName: String? = nil, operation: String? = nil) {
        self.uri = uri
        self.symbolName = symbolName
        self.operation = operation
    }
}

/// 从错误创建用户友好的消息
public extension XcodeLSPError {
    static func userMessage(for error: XcodeLSPError, operation: String) -> String {
        var message = "\(operation): \(error.localizedDescription)"
        if let action = error.suggestedAction {
            message += "\n\n💡 \(action)"
        }
        return message
    }
}
