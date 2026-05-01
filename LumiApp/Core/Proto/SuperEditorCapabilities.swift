import Foundation

@MainActor
protocol SuperEditorProjectContextCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func canHandleProject(at path: String?) -> Bool
    func projectOpened(at path: String) async
    func projectClosed()
    func resyncProjectContext() async
    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot?
    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?)
}

extension SuperEditorProjectContextCapability {
    var priority: Int { 0 }

    func canHandleProject(at path: String?) -> Bool {
        guard let path else { return false }
        return !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
protocol SuperEditorLanguageIntegrationCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func supports(languageId: String, projectPath: String?) -> Bool
    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]?
    func initializationOptions(for languageId: String, projectPath: String) -> [String: String]?
}

extension SuperEditorLanguageIntegrationCapability {
    var priority: Int { 0 }
}

@MainActor
protocol SuperEditorSemanticCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func canHandle(uri: String?) -> Bool
    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport
    func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> String?
    func preflightError(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> EditorLanguageFeatureError?
    func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String?
    ) -> String?
}

extension SuperEditorSemanticCapability {
    var priority: Int { 0 }

    func canHandle(uri: String?) -> Bool {
        guard let uri else { return false }
        return !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String?
    ) -> String? {
        nil
    }
}

struct EditorProjectContextSnapshot: Equatable, Sendable {
    let projectPath: String
    let workspaceName: String
    let workspacePath: String
    let activeScheme: String?
    let activeSchemeBuildableTargets: [String]
    let activeConfiguration: String?
    let activeDestination: String?
    let contextStatus: EditorProjectContextStatus
    let isStructuredProject: Bool
    let schemes: [String]
    let configurations: [String]
    let currentFilePath: String?
    let currentFilePrimaryTarget: String?
    let currentFileMatchedTargets: [String]
    let currentFileIsInTarget: Bool
}

enum EditorProjectContextStatus: Equatable, Sendable {
    case unknown
    case resolving
    case available(String?)
    case unavailable(String)
    case needsResync

    var displayDescription: String {
        switch self {
        case .unknown:
            return "未初始化"
        case .resolving:
            return "解析中"
        case .available(let detail):
            return detail ?? "可用"
        case .unavailable(let reason):
            return "不可用: \(reason)"
        case .needsResync:
            return "需要重新同步"
        }
    }
}

struct EditorWorkspaceFolder: Equatable, Sendable {
    let uri: String
    let name: String
}

enum EditorSemanticPreflightStrength: Sendable {
    case soft
    case hard
}

enum EditorSemanticAvailabilitySeverity: String, Sendable {
    case info
    case warning
    case error
}

struct EditorSemanticAvailabilityReason: Equatable, Sendable, Identifiable {
    let id: String
    let severity: EditorSemanticAvailabilitySeverity
    let title: String
    let message: String
    let suggestion: String?

    init(
        id: String,
        severity: EditorSemanticAvailabilitySeverity,
        title: String,
        message: String,
        suggestion: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
        self.suggestion = suggestion
    }
}

struct EditorSemanticAvailabilityReport: Equatable, Sendable {
    let reasons: [EditorSemanticAvailabilityReason]

    static let empty = EditorSemanticAvailabilityReport(reasons: [])
}

struct EditorLanguageFeatureError: LocalizedError, Equatable, Sendable {
    let domain: String
    let code: String
    let message: String
    let suggestion: String?

    var errorDescription: String? { message }
    var recoverySuggestion: String? { suggestion }
}
