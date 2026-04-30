import Foundation
import os
import MagicKit

/// LSP Error Taxonomy for Xcode Projects
/// 对应 Phase 4: 对 LSP 错误分类
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
            return "LSP 服务器未启动，无法处理请求"
        case .serverDisconnected:
            return "LSP 服务器连接已断开，正在尝试重新连接..."
        case .noProjectContext:
            return "当前文件未绑定有效的 Xcode 项目上下文"
        case .buildContextUnavailable(let reason):
            return "Build context 不可用: \(reason)"
        case .symbolNotResolved(let symbol):
            return "无法解析符号\((symbol.map { " '\($0)'" }) ?? "")"
        case .symbolNotFound:
            return "未找到匹配的符号"
        case .indexingInProgress:
            return "正在索引项目，语义导航可能不完整"
        case .fileNotInTarget(let file):
            return "'\(file)' 不属于任何编译 target，请检查文件是否在项目中"
        case .fileInMultipleTargets(let file, let targets, let activeScheme):
            let targetList = targets.joined(separator: ", ")
            if let activeScheme, !activeScheme.isEmpty {
                return "'\(file)' 同时属于多个 target（\(targetList)），当前 scheme '\(activeScheme)' 无法唯一确定语义上下文"
            }
            return "'\(file)' 同时属于多个 target（\(targetList)），当前无法唯一确定语义上下文"
        case .fileTargetsExcludedByActiveScheme(let file, let targets, let activeScheme):
            let targetList = targets.joined(separator: ", ")
            if let activeScheme, !activeScheme.isEmpty {
                return "'\(file)' 属于 target（\(targetList)），但当前 scheme '\(activeScheme)' 不包含这些 target"
            }
            return "'\(file)' 属于 target（\(targetList)），但当前 active scheme 不包含这些 target"
        case .requestTimeout:
            return "LSP 请求超时，请稍后重试"
        case .unknown(let message):
            return message
        }
    }
    
    /// 用户可操作的建议
    var suggestedAction: String? {
        switch self {
        case .serverNotStarted:
            return "尝试重新打开文件或重启 Lumi"
        case .serverDisconnected:
            return "等待自动重连，或手动切换文件触发重建"
        case .noProjectContext:
            return "确保 .xcodeproj/.xcworkspace 在项目根目录"
        case .buildContextUnavailable:
            return "运行 brew install xcode-build-server 并重新打开项目"
        case .symbolNotResolved:
            return "等待索引完成后重试，或检查 sourcekit-lsp 日志"
        case .symbolNotFound:
            return nil
        case .indexingInProgress:
            return "等待索引完成后再次尝试"
        case .fileNotInTarget:
            return "将文件添加到 target 中"
        case .fileInMultipleTargets:
            return "切换到更精确的 scheme，或仅保留一个 target 归属后重试"
        case .fileTargetsExcludedByActiveScheme:
            return "切换到包含该文件 target 的 scheme 后重试"
        case .requestTimeout:
            return "尝试重试"
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
            return .buildContextUnavailable("Build context 需要重新同步")
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
