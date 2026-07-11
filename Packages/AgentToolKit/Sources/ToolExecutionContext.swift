import Foundation

/// 单次工具调用的执行上下文。
///
/// 除取消机制外，还携带沙箱目录信息，供工具判断路径是否在允许范围内。
/// 路径不在 `allowedDirectories` 中的操作应提升风险等级，提醒用户确认。
public final class ToolExecutionContext: @unchecked Sendable {
    public typealias CancellationHandler = @Sendable () -> Void

    public let conversationId: UUID
    public let toolCallId: String
    public let toolName: String

    /// 当前活跃项目的路径（可选）
    public let currentProjectPath: String?

    /// 允许的目录白名单（最近项目路径的规范化形式）
    /// 工具执行时若路径不在此列表内，应提升风险等级
    public let allowedDirectories: [String]

    /// 当前对话的详细程度（可选）
    /// 工具可以根据此值决定输出的详细程度
    public let verbosity: String?

    // MARK: - Path Sandbox

    /// 检查给定路径是否在允许的目录范围内。
    ///
    /// - Parameter path: 待检查的绝对路径（支持 ~ 展开、symlink 解析）
    /// - Returns: `true` 表示路径在沙箱内，安全操作；`false` 表示越界
    public func isPathAllowed(_ path: String) -> Bool {
        guard !allowedDirectories.isEmpty else { return true }

        let resolved = Self.resolvePath(path)
        return allowedDirectories.contains { allowedDir in
            let resolvedAllowedDir = Self.resolvePath(allowedDir)
            if resolvedAllowedDir == "/" { return true }
            return resolved == resolvedAllowedDir || resolved.hasPrefix(resolvedAllowedDir + "/")
        }
    }

    /// 规范化路径：展开 ~、解析 symlink、消除 `..` 和 `.`
    public static func resolvePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        let resolved = url.resolvingSymlinksInPath().path
        return resolved != "/" && resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }

    private let lock = NSLock()
    private var cancelled = false
    private var handlers: [UUID: CancellationHandler] = [:]

    public init(
        conversationId: UUID,
        toolCallId: String,
        toolName: String,
        currentProjectPath: String? = nil,
        allowedDirectories: [String] = [],
        verbosity: String? = nil
    ) {
        self.conversationId = conversationId
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.currentProjectPath = currentProjectPath
        self.allowedDirectories = allowedDirectories
        self.verbosity = verbosity
    }

    public var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value || Task.isCancelled
    }

    public func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    @discardableResult
    public func onCancel(_ handler: @escaping CancellationHandler) -> UUID? {
        lock.lock()
        if cancelled {
            lock.unlock()
            handler()
            return nil
        }
        let id = UUID()
        handlers[id] = handler
        lock.unlock()
        return id
    }

    public func removeCancellationHandler(_ id: UUID?) {
        guard let id else { return }
        lock.lock()
        handlers[id] = nil
        lock.unlock()
    }

    public func cancel() {
        let handlersToRun: [CancellationHandler]
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        cancelled = true
        handlersToRun = Array(handlers.values)
        handlers.removeAll()
        lock.unlock()

        for handler in handlersToRun {
            handler()
        }
    }
}
