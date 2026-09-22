import Foundation

public struct EditorWorkspaceFolder: Equatable, Sendable {
    public let uri: String
    public let name: String

    public init(uri: String, name: String) {
        self.uri = uri
        self.name = name
    }
}

public enum EditorSemanticPreflightStrength: Sendable {
    case soft
    case hard
}

public enum EditorSemanticAvailabilitySeverity: String, Sendable {
    case info
    case warning
    case error
}

public struct EditorSemanticAvailabilityReason: Equatable, Sendable, Identifiable {
    public let id: String
    public let severity: EditorSemanticAvailabilitySeverity
    public let title: String
    public let message: String
    public let suggestion: String?

    public init(
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

public struct EditorSemanticAvailabilityReport: Equatable, Sendable {
    public let reasons: [EditorSemanticAvailabilityReason]

    public init(reasons: [EditorSemanticAvailabilityReason]) {
        self.reasons = reasons
    }

    public static let empty = EditorSemanticAvailabilityReport(reasons: [])
}

public struct EditorLanguageFeatureError: LocalizedError, Equatable, Sendable {
    public let domain: String
    public let code: String
    public let message: String
    public let suggestion: String?

    public init(
        domain: String,
        code: String,
        message: String,
        suggestion: String? = nil
    ) {
        self.domain = domain
        self.code = code
        self.message = message
        self.suggestion = suggestion
    }

    public var errorDescription: String? { message }
    public var recoverySuggestion: String? { suggestion }
}

public struct EditorSemanticProblem: Identifiable, Equatable, Sendable {
    public let id: String
    public let severity: EditorSemanticAvailabilitySeverity
    public let title: String
    public let message: String

    public init(
        id: String,
        severity: EditorSemanticAvailabilitySeverity,
        title: String,
        message: String
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
    }

    public init(reason: EditorSemanticAvailabilityReason) {
        self.id = reason.id
        self.severity = reason.severity
        self.title = reason.title
        self.message = reason.message
    }
}
