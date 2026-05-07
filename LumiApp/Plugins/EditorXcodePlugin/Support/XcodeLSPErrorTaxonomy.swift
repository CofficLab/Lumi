import Foundation
import os
import MagicKit

/// LSP Error Taxonomy for Xcode Projects
/// 将统一的 "No definition found" 细分为可操作的错误类型
enum XcodeLSPError: LocalizedError, Equatable {
    
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
    
    var errorDescription: String? {
        switch self {
        case .serverNotStarted:
            return String(localized: "LSP server not started, unable to process request", table: "EditorXcodePlugin")
        case .serverDisconnected:
            return String(localized: "LSP server connection lost, attempting to reconnect...", table: "EditorXcodePlugin")
        case .noProjectContext:
            return String(localized: "Current file is not bound to a valid Xcode project context", table: "EditorXcodePlugin")
        case .buildContextUnavailable(let reason):
            let format = String(localized: "Build context unavailable: %@", table: "EditorXcodePlugin")
            return String(format: format, reason)
        case .symbolNotResolved(let symbol):
            let symbolPart = symbol.map { " '\($0)'" } ?? ""
            return String(localized: "Unable to resolve symbol%@", table: "EditorXcodePlugin") + symbolPart
        case .symbolNotFound:
            return String(localized: "No matching symbol found", table: "EditorXcodePlugin")
        case .indexingInProgress:
            return String(localized: "Project is being indexed, semantic navigation may be incomplete", table: "EditorXcodePlugin")
        case .fileNotInTarget(let file):
            let format = String(localized: "'%@' does not belong to any compilation target, please check if the file is in the project", table: "EditorXcodePlugin")
            return String(format: format, file)
        case .fileInMultipleTargets(let file, let targets, let activeScheme):
            let targetList = targets.joined(separator: ", ")
            if let activeScheme, !activeScheme.isEmpty {
                let format = String(localized: "'%@' belongs to multiple targets (%@), current scheme '%@' cannot uniquely determine semantic context", table: "EditorXcodePlugin")
                return String(format: format, file, targetList, activeScheme)
            }
            let format = String(localized: "'%@' belongs to multiple targets (%@), cannot uniquely determine semantic context", table: "EditorXcodePlugin")
            return String(format: format, file, targetList)
        case .fileTargetsExcludedByActiveScheme(let file, let targets, let activeScheme):
            let targetList = targets.joined(separator: ", ")
            if let activeScheme, !activeScheme.isEmpty {
                let format = String(localized: "'%@' belongs to target (%@), but current scheme '%@' does not include these targets", table: "EditorXcodePlugin")
                return String(format: format, file, targetList, activeScheme)
            }
            let format = String(localized: "'%@' belongs to target (%@), but current active scheme does not include these targets", table: "EditorXcodePlugin")
            return String(format: format, file, targetList)
        case .requestTimeout:
            return String(localized: "LSP request timed out, please try again later", table: "EditorXcodePlugin")
        case .unknown(let message):
            return message
        }
    }
    
    /// 用户可操作的建议
    var suggestedAction: String? {
        switch self {
        case .serverNotStarted:
            return String(localized: "Try reopening the file or restarting Lumi", table: "EditorXcodePlugin")
        case .serverDisconnected:
            return String(localized: "Wait for auto-reconnect, or manually switch files to trigger rebuild", table: "EditorXcodePlugin")
        case .noProjectContext:
            return String(localized: "Ensure .xcodeproj/.xcworkspace is in the project root directory", table: "EditorXcodePlugin")
        case .buildContextUnavailable:
            return String(localized: "Run brew install xcode-build-server and reopen the project", table: "EditorXcodePlugin")
        case .symbolNotResolved:
            return String(localized: "Wait for indexing to complete and retry, or check sourcekit-lsp logs", table: "EditorXcodePlugin")
        case .symbolNotFound:
            return nil
        case .indexingInProgress:
            return String(localized: "Wait for indexing to complete and try again", table: "EditorXcodePlugin")
        case .fileNotInTarget:
            return String(localized: "Add the file to a target", table: "EditorXcodePlugin")
        case .fileInMultipleTargets:
            return String(localized: "Switch to a more specific scheme, or keep only one target membership and retry", table: "EditorXcodePlugin")
        case .fileTargetsExcludedByActiveScheme:
            return String(localized: "Switch to a scheme that includes the file's target and retry", table: "EditorXcodePlugin")
        case .requestTimeout:
            return String(localized: "Try again", table: "EditorXcodePlugin")
        case .unknown:
            return nil
        }
    }
    
    /// 错误分类（用于日志和统计）
    var category: String {
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
    var requiresUserAction: Bool {
        switch self {
        case .serverDisconnected, .indexingInProgress:
            return false
        default:
            return true
        }
    }
}

/// LSP 错误分类器
@MainActor
enum XcodeLSPErrorClassifier {
    static func classifyPreflight(context: LSPErrorContext) -> XcodeLSPError? {
        if let cached = XcodeProjectContextBridge.shared.cachedState, !cached.isXcodeProject {
            return nil
        }

        if let cached = XcodeProjectContextBridge.shared.cachedState, !cached.isInitialized {
            return .serverNotStarted
        }

        let bridge = XcodeProjectContextBridge.shared
        if case .unavailable(let reason) = bridge.buildContextProvider?.buildContextStatus {
            return .buildContextUnavailable(reason)
        }
        if case .needsResync = bridge.buildContextProvider?.buildContextStatus {
            return .buildContextUnavailable(String(localized: "Build context needs to be resynchronized", table: "EditorXcodePlugin"))
        }

        guard let uri = context.uri, let url = URL(string: uri) else {
            return nil
        }

        let matchedTargets = bridge.buildContextProvider?.findTargetsForFile(fileURL: url).map(\.name) ?? []
        if matchedTargets.isEmpty {
            return .fileNotInTarget(url.lastPathComponent)
        }

        let compatibleTargets = bridge.buildContextProvider?.targetsCompatibleWithActiveScheme(for: url).map(\.name) ?? matchedTargets
        if compatibleTargets.isEmpty {
            return .fileTargetsExcludedByActiveScheme(
                file: url.lastPathComponent,
                targets: matchedTargets,
                activeScheme: bridge.cachedActiveScheme
            )
        }

        if matchedTargets.count > 1, bridge.buildContextProvider?.resolvePreferredTarget(for: url) == nil {
            return .fileInMultipleTargets(
                file: url.lastPathComponent,
                targets: matchedTargets,
                activeScheme: bridge.cachedActiveScheme
            )
        }

        return nil
    }

    
    /// 将通用错误分类为 Xcode 特定错误
    static func classify(_ error: Error, context: LSPErrorContext) -> XcodeLSPError {
        let description = String(describing: error).lowercased()
        
        // 检查连接相关错误
        if description.contains("datastreamclosed") ||
           description.contains("protocoltransporterror") ||
           description.contains("streamclosed") ||
           description.contains("connection closed") {
            return .serverDisconnected
        }
        
        // 检查超时
        if description.contains("timeout") || description.contains("timed out") {
            return .requestTimeout
        }
        
        // 检查上下文
        if let cached = XcodeProjectContextBridge.shared.cachedState, !cached.isXcodeProject {
            return .noProjectContext
        }
        if let preflight = classifyPreflight(context: context) {
            return preflight
        }
        
        // 默认：检查是否语义解析失败
        if description.contains("nil") || description.contains("null") ||
           description.contains("empty") || description.contains("not found") {
            return .symbolNotResolved(symbolName: context.symbolName)
        }
        
        return .unknown(String(describing: error))
    }
    
    /// 从错误创建用户友好的消息
    static func userMessage(for error: XcodeLSPError, operation: String) -> String {
        var message = "\(operation): \(error.localizedDescription)"
        if let action = error.suggestedAction {
            message += "\n\n💡 \(action)"
        }
        return message
    }

    static func classifyMissingResult(context: LSPErrorContext) -> XcodeLSPError {
        if let cached = XcodeProjectContextBridge.shared.cachedState, !cached.isXcodeProject {
            return .symbolNotFound
        }

        if let preflight = classifyPreflight(context: context) {
            return preflight
        }

        return .symbolNotResolved(symbolName: context.symbolName)
    }
}

/// LSP 错误上下文
struct LSPErrorContext {
    let uri: String?
    let symbolName: String?
    let operation: String?
    
    init(uri: String? = nil, symbolName: String? = nil, operation: String? = nil) {
        self.uri = uri
        self.symbolName = symbolName
        self.operation = operation
    }
}
