import Foundation

// MARK: - LumiCommandRiskLevel

/// 命令风险等级。
public enum LumiCommandRiskLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case safe
    case low
    case medium
    case high

    public var requiresPermission: Bool {
        self == .high
    }
}

// MARK: - LumiToolExecutionContext

/// 工具执行上下文。
///
/// 提供工具执行时的环境信息、取消支持和图片附件收集。
public final class LumiToolExecutionContext: @unchecked Sendable {
    public typealias CancellationHandler = @Sendable () -> Void

    public let conversationID: UUID
    public let toolCallID: String
    public let toolName: String
    public let currentProjectPath: String?
    public let allowedDirectories: [String]

    /// 当前会话的用户语言偏好。
    public let language: LumiLanguagePreference

    /// 当前对话的详细程度（可选）。
    public let verbosity: String?

    // MARK: - Image Collection

    private let collectedImages = NSLock()
    private var _collectedImages: [LumiImageAttachment] = []

    // MARK: - Cancellation

    private let cancellationLock = NSLock()
    private var _cancelled = false
    private var cancellationHandlers: [UUID: CancellationHandler] = [:]

    public init(
        conversationID: UUID,
        toolCallID: String,
        toolName: String,
        currentProjectPath: String? = nil,
        allowedDirectories: [String] = [],
        language: LumiLanguagePreference = .english,
        verbosity: String? = nil
    ) {
        self.conversationID = conversationID
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.currentProjectPath = currentProjectPath
        self.allowedDirectories = allowedDirectories.map(Self.resolvePath)
        self.language = language
        self.verbosity = verbosity
    }

    public func isPathAllowed(_ path: String) -> Bool {
        guard !allowedDirectories.isEmpty else { return true }

        let resolvedPath = Self.resolvePath(path)
        return allowedDirectories.contains { allowedDirectory in
            resolvedPath == allowedDirectory || resolvedPath.hasPrefix("\(allowedDirectory)/")
        }
    }

    public static func resolvePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let resolved = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().standardizedFileURL.path
        return resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }

    // MARK: - Cancellation

    public var isCancelled: Bool {
        cancellationLock.lock()
        let value = _cancelled
        cancellationLock.unlock()
        return value || Task.isCancelled
    }

    public func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    @discardableResult
    public func onCancel(_ handler: @escaping CancellationHandler) -> UUID? {
        cancellationLock.lock()
        if _cancelled {
            cancellationLock.unlock()
            handler()
            return nil
        }
        let id = UUID()
        cancellationHandlers[id] = handler
        cancellationLock.unlock()
        return id
    }

    public func removeCancellationHandler(_ id: UUID?) {
        guard let id else { return }
        cancellationLock.lock()
        cancellationHandlers[id] = nil
        cancellationLock.unlock()
    }

    public func cancel() {
        cancellationLock.lock()
        guard !_cancelled else {
            cancellationLock.unlock()
            return
        }
        _cancelled = true
        let handlersToRun = Array(cancellationHandlers.values)
        cancellationHandlers.removeAll()
        cancellationLock.unlock()

        for handler in handlersToRun {
            handler()
        }
    }

    // MARK: - Image Collection

    public func attachImage(_ image: LumiImageAttachment) {
        collectedImages.lock()
        _collectedImages.append(image)
        collectedImages.unlock()
    }

    public func attachImages(_ images: [LumiImageAttachment]) {
        guard !images.isEmpty else { return }
        collectedImages.lock()
        _collectedImages.append(contentsOf: images)
        collectedImages.unlock()
    }

    public func collectImages() -> [LumiImageAttachment] {
        collectedImages.lock()
        let images = _collectedImages
        _collectedImages = []
        collectedImages.unlock()
        return images
    }
}