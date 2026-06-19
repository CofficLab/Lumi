import Foundation

// MARK: - Build Run Phase

public enum SwiftBuildRunPhase: Equatable, Sendable {
    case idle
    case preflighting
    case building
    case launching
    case succeeded
    case failed
    case cancelled

    public var isActive: Bool {
        switch self {
        case .preflighting, .building, .launching:
            return true
        case .idle, .succeeded, .failed, .cancelled:
            return false
        }
    }
}

// MARK: - Issue Severity

public enum SwiftBuildIssueSeverity: String, Sendable, Equatable {
    case error
    case warning
}

// MARK: - Build Issue

public struct SwiftBuildIssue: Identifiable, Sendable, Equatable {
    public let id: String
    public let file: String?
    public let line: Int?
    public let column: Int?
    public let severity: SwiftBuildIssueSeverity
    public let message: String

    public init(
        file: String?,
        line: Int?,
        column: Int?,
        severity: SwiftBuildIssueSeverity,
        message: String
    ) {
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
        let location = [file, line.map(String.init), column.map(String.init)]
            .compactMap { $0 }
            .joined(separator: ":")
        self.id = "\(severity.rawValue)|\(location)|\(message)"
    }
}

// MARK: - Run Context

public enum SwiftProjectRunContext: Sendable, Equatable {
    case xcode(
        workspaceURL: URL,
        scheme: String,
        configuration: String,
        destinationQuery: String,
        derivedDataPath: URL,
        preferredTargetName: String?
    )
    case spm(
        packageRoot: URL,
        executableTarget: String,
        configuration: String
    )
}

// MARK: - Preflight

public enum SwiftBuildRunPreflightFailure: Sendable, Equatable {
    case unsupportedProject
    case missingScheme
    case nonMacOSDestination
    case noRunnableTarget
    case needsTargetSelection([String])
    case toolNotFound(String)
    case message(String)
}

public struct SwiftBuildRunPreflightResult: Sendable, Equatable {
    public let context: SwiftProjectRunContext?
    public let failure: SwiftBuildRunPreflightFailure?
    public let disabledReason: String?

    public var isReady: Bool { context != nil && failure == nil }

    public static func ready(_ context: SwiftProjectRunContext) -> SwiftBuildRunPreflightResult {
        SwiftBuildRunPreflightResult(context: context, failure: nil, disabledReason: nil)
    }

    public static func failed(
        _ failure: SwiftBuildRunPreflightFailure,
        disabledReason: String
    ) -> SwiftBuildRunPreflightResult {
        SwiftBuildRunPreflightResult(context: nil, failure: failure, disabledReason: disabledReason)
    }
}

// MARK: - Build Result

public struct SwiftBuildRunResult: Sendable, Equatable {
    public let exitCode: Int
    public let stdout: String
    public let stderr: String
    public let issues: [SwiftBuildIssue]
    public let productURL: URL?
    public let wasCancelled: Bool

    public init(
        exitCode: Int,
        stdout: String = "",
        stderr: String = "",
        issues: [SwiftBuildIssue] = [],
        productURL: URL? = nil,
        wasCancelled: Bool = false
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.issues = issues
        self.productURL = productURL
        self.wasCancelled = wasCancelled
    }

    public var isSuccess: Bool { exitCode == 0 && !wasCancelled }
}
