import Foundation
import LumiCoreMessage

// MARK: - LumiAgentToolInfo

public struct LumiAgentToolInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String

    public init(id: String, displayName: String, description: String) {
        self.id = id
        self.displayName = displayName
        self.description = description
    }
}

// MARK: - LumiCommandRiskLevel

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

public final class LumiToolExecutionContext: @unchecked Sendable {
    public typealias CancellationHandler = @Sendable () -> Void

    public let conversationID: UUID
    public let toolCallID: String
    public let toolName: String
    public let currentProjectPath: String?
    public let allowedDirectories: [String]

    /// 当前会话的用户语言偏好。
    ///
    /// 原生 `LumiAgentTool` 实现可据此返回本地化的描述、提示或错误，
    /// 不再依赖历史上向参数注入 `__lumi_language` 的做法。
    public let language: LumiLanguagePreference

    /// 当前对话的详细程度（可选）。
    ///
    /// 值为 `LumiResponseVerbosity.rawValue`（如 "v1"/"v2"/"v3"）。
    /// 工具可以据此决定输出的详细程度。
    public let verbosity: String?

    /// 工具执行过程中收集的图片附件（线程安全）。
    ///
    /// 工具在 `execute` 内可通过 `attachImage(_:)` 注册要回传给 LLM 的图片，
    /// 由 `LumiToolServicing.execute` 在执行结束后读取并填入 `LumiToolResult.imageAttachments`。
    /// 这样无需改变 `LumiAgentTool.execute -> String` 的签名，只有需要回传图片的工具主动调用即可。
    private let collectedImages = NSLock()
    private var _collectedImages: [LumiImageAttachment] = []

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
        guard !allowedDirectories.isEmpty else {
            return true
        }

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

    /// 取消状态（线程安全）。执行层在工具运行期间可调用 `cancel()` 触发取消，
    /// 工具在 `execute` 内通过 `checkCancellation()` / `isCancelled` 感知。
    private let cancellationLock = NSLock()
    private var _cancelled = false
    private var cancellationHandlers: [UUID: CancellationHandler] = [:]

    /// 是否已被取消（同时尊重当前 `Task` 的协作式取消）。
    public var isCancelled: Bool {
        cancellationLock.lock()
        let value = _cancelled
        cancellationLock.unlock()
        return value || Task.isCancelled
    }

    /// 若已取消则抛出 `CancellationError`，供长任务在关键节点主动检查。
    public func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    /// 注册一个取消回调；若已经取消，回调会立即同步执行并返回 `nil`。
    /// 返回的 `UUID` 可传给 `removeCancellationHandler(_:)` 注销。
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

    /// 注销此前 `onCancel(_:)` 返回的回调。
    public func removeCancellationHandler(_ id: UUID?) {
        guard let id else { return }
        cancellationLock.lock()
        cancellationHandlers[id] = nil
        cancellationLock.unlock()
    }

    /// 触发取消（由执行层/App 调度器调用，非插件直接调用）。
    /// 会同步执行所有已注册的取消回调。
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

    /// 注册一张要回传给 LLM 的图片。
    public func attachImage(_ image: LumiImageAttachment) {
        collectedImages.lock()
        _collectedImages.append(image)
        collectedImages.unlock()
    }

    /// 注册一组要回传给 LLM 的图片。
    public func attachImages(_ images: [LumiImageAttachment]) {
        guard !images.isEmpty else { return }
        collectedImages.lock()
        _collectedImages.append(contentsOf: images)
        collectedImages.unlock()
    }

    /// 读取并清空已收集的图片（由 `LumiToolServicing.execute` 在工具执行后调用）。
    public func collectImages() -> [LumiImageAttachment] {
        collectedImages.lock()
        let images = _collectedImages
        _collectedImages = []
        collectedImages.unlock()
        return images
    }
}

// MARK: - LumiAgentTool Protocol

public protocol LumiAgentTool: Sendable {
    static var info: LumiAgentToolInfo { get }

    /// 此工具的特征标签。一个工具可声明多个标签（叠加语义）。
    /// 子 Agent 通过 requiredTags / excludedTags 按标签过滤。
    /// 默认值 []：工具必须显式声明才能被按标签过滤找到。
    var tags: Set<LumiToolTag> { get }

    var name: String { get }
    var toolDescription: String { get }
    var inputSchema: LumiJSONValue { get }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel
    func displayDescription(arguments: [String: LumiJSONValue]) -> String
}

public extension LumiAgentTool {
    var name: String {
        Self.info.id
    }

    var toolDescription: String {
        Self.info.description
    }

    /// 默认无标签——工具必须显式声明 tags 才能被按标签过滤找到。
    var tags: Set<LumiToolTag> { [] }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        Self.info.displayName
    }
}

// MARK: - LumiToolServicing Protocol

@MainActor
public protocol LumiToolServicing: AnyObject {
    var tools: [any LumiAgentTool] { get }

    func registerTools(_ tools: [any LumiAgentTool]) throws
    func tool(named name: String) -> (any LumiAgentTool)?
    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult
}


// MARK: - Argument Accessors

/// 从工具调用参数中按类型安全地提取值。
///
/// 历史上每个插件都要自造 `arguments[key]?.value as? String` 之类的提取代码
/// （旧协议用的是 `ToolArgument(Any)`，弱类型且重复）。`LumiJSONValue` 是强类型枚举，
/// 这里提供一组统一访问器，迁移到原生 `LumiAgentTool` 的插件直接复用，避免重复样板。
public extension [String: LumiJSONValue] {
    /// 字符串参数。
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    /// 整数参数；兼容以浮点或数字字符串传入的值。
    func int(_ key: String) -> Int? {
        guard let value = self[key] else { return nil }
        switch value {
        case .int(let intValue):
            return intValue
        case .double(let doubleValue):
            return Int(doubleValue)
        case .string(let raw):
            return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    /// 浮点参数；兼容整数与数字字符串。
    func double(_ key: String) -> Double? {
        guard let value = self[key] else { return nil }
        switch value {
        case .double(let doubleValue):
            return doubleValue
        case .int(let intValue):
            return Double(intValue)
        case .string(let raw):
            return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    /// 布尔参数；兼容 `0/1` 等常见字面量。
    func bool(_ key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        switch value {
        case .bool(let boolValue):
            return boolValue
        case .int(let intValue):
            return intValue != 0
        case .string(let raw):
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        default:
            return nil
        }
    }

    /// 字符串数组参数（如文件列表）。
    func stringArray(_ key: String) -> [String]? {
        guard case .array(let values) = self[key] else { return nil }
        return values.compactMap(\.stringValue)
    }
}