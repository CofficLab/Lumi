import Foundation

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
    public let language: LumiLanguagePreference
    public let verbosity: String?

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

    private let cancellationLock = NSLock()
    private var _cancelled = false
    private var cancellationHandlers: [UUID: CancellationHandler] = [:]

    public var isCancelled: Bool {
        cancellationLock.lock()
        let value = _cancelled
        cancellationLock.unlock()
        return value || Task.isCancelled
    }

    public func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
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
        for handler in handlersToRun { handler() }
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

// MARK: - LumiAgentTool Protocol

public protocol LumiAgentTool: Sendable {
    static var info: LumiAgentToolInfo { get }
    var tags: Set<LumiToolTag> { get }
    var name: String { get }
    var toolDescription: String { get }
    var inputSchema: LumiJSONValue { get }
    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel
    func displayDescription(arguments: [String: LumiJSONValue]) -> String
}

public extension LumiAgentTool {
    var name: String { Self.info.id }
    var toolDescription: String { Self.info.description }
    var tags: Set<LumiToolTag> { [] }
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }
    func displayDescription(arguments: [String: LumiJSONValue]) -> String { Self.info.displayName }
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

public extension [String: LumiJSONValue] {
    func string(_ key: String) -> String? { self[key]?.stringValue }
    func int(_ key: String) -> Int? {
        guard let value = self[key] else { return nil }
        switch value {
        case .int(let v): return v
        case .double(let v): return Int(v)
        case .string(let raw): return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }
    func double(_ key: String) -> Double? {
        guard let value = self[key] else { return nil }
        switch value {
        case .double(let v): return v
        case .int(let v): return Double(v)
        case .string(let raw): return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }
    func bool(_ key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        switch value {
        case .bool(let v): return v
        case .int(let v): return v != 0
        case .string(let raw):
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        default: return nil
        }
    }
    func stringArray(_ key: String) -> [String]? {
        guard case .array(let values) = self[key] else { return nil }
        return values.compactMap(\.stringValue)
    }
}

// MARK: - AgentToolItem

public struct AgentToolItem: Identifiable, Sendable {
    public let id: String
    public let tool: any LumiAgentTool
    public init(tool: any LumiAgentTool) { self.id = tool.name; self.tool = tool }
}
