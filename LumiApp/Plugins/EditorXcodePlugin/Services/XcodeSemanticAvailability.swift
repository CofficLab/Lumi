import Foundation

@MainActor
enum XcodeSemanticAvailability {
    enum Strength {
        case hard
        case soft
    }

    enum ReasonSeverity: String, Sendable {
        case info
        case warning
        case error
    }

    struct Reason: Identifiable, Sendable, Equatable {
        let id: String
        let severity: ReasonSeverity
        let title: String
        let message: String
    }

    struct Report: Sendable, Equatable {
        let reasons: [Reason]

        var hasBlockingIssue: Bool {
            reasons.contains { $0.severity == .error }
        }

        var hasWarnings: Bool {
            reasons.contains { $0.severity == .warning }
        }
    }

    struct WorkspaceInspectionInput: Sendable, Equatable {
        let isXcodeProject: Bool
        let isInitialized: Bool
        let buildContextStatus: XcodeBuildContextProvider.BuildContextStatus
    }

    struct FileInspectionInput: Sendable, Equatable {
        let workspace: WorkspaceInspectionInput
        let fileName: String?
        let activeScheme: String?
        let activeDestinationName: String?
        let matchedTargets: [String]
        let compatibleTargets: [String]
        let preferredTarget: String?
    }

    static func inspectWorkspaceContext(input: WorkspaceInspectionInput) -> Report {
        guard input.isXcodeProject else {
            return Report(reasons: [])
        }

        var reasons: [Reason] = []

        if !input.isInitialized {
            reasons.append(
                Reason(
                    id: "server-not-started",
                    severity: .error,
                    title: String(localized: "LSP Not Initialized", table: "EditorXcodePlugin"),
                    message: String(localized: "The current Xcode project context has not yet completed initialization.", table: "EditorXcodePlugin")
                )
            )
        }

        if case .unavailable(let reason) = input.buildContextStatus {
            reasons.append(
                Reason(
                    id: "build-context-unavailable",
                    severity: .error,
                    title: String(localized: "Build Context Unavailable", table: "EditorXcodePlugin"),
                    message: reason
                )
            )
        }

        if case .needsResync = input.buildContextStatus {
            reasons.append(
                Reason(
                    id: "build-context-resync",
                    severity: .warning,
                    title: String(localized: "Build Context Needs Sync", table: "EditorXcodePlugin"),
                    message: String(localized: "The current build context has expired, workspace semantic results may be inaccurate.", table: "EditorXcodePlugin")
                )
            )
        }

        return Report(reasons: reasons)
    }

    static func inspectCurrentFileContext(input: FileInspectionInput) -> Report {
        var reasons = inspectWorkspaceContext(input: input.workspace).reasons

        guard let fileName = input.fileName else {
            return Report(reasons: reasons)
        }

        if input.matchedTargets.isEmpty {
            let format = String(localized: "'%@' does not belong to any compilation target.", table: "EditorXcodePlugin")
            reasons.append(
                Reason(
                    id: "file-not-in-target",
                    severity: .error,
                    title: String(localized: "File Not in Target", table: "EditorXcodePlugin"),
                    message: String(format: format, fileName)
                )
            )
            return Report(reasons: reasons)
        }

        if input.compatibleTargets.isEmpty {
            let format = String(localized: "Current scheme '%@' does not include %@.", table: "EditorXcodePlugin")
            let scheme = input.activeScheme ?? String(localized: "Not Selected", table: "EditorXcodePlugin")
            let targets = input.matchedTargets.joined(separator: ", ")
            reasons.append(
                Reason(
                    id: "scheme-excludes-targets",
                    severity: .error,
                    title: String(localized: "Scheme Does Not Cover File Target", table: "EditorXcodePlugin"),
                    message: String(format: format, scheme, targets)
                )
            )
        }

        if input.matchedTargets.count > 1 {
            if let preferredTarget = input.preferredTarget {
                let format = String(localized: "Current file matches multiple targets, currently resolving with '%@'.", table: "EditorXcodePlugin")
                reasons.append(
                    Reason(
                        id: "multiple-targets-resolved",
                        severity: .info,
                        title: String(localized: "Multi-Target File", table: "EditorXcodePlugin"),
                        message: String(format: format, preferredTarget)
                    )
                )
            } else {
                let format = String(localized: "Current file belongs to %@, but current scheme cannot uniquely determine semantic context.", table: "EditorXcodePlugin")
                let targets = input.matchedTargets.joined(separator: ", ")
                reasons.append(
                    Reason(
                        id: "multiple-targets-ambiguous",
                        severity: .warning,
                        title: String(localized: "Multi-Target Ambiguity", table: "EditorXcodePlugin"),
                        message: String(format: format, targets)
                    )
                )
            }
        }

        if input.activeDestinationName == nil {
            reasons.append(
                Reason(
                    id: "destination-unknown",
                    severity: .warning,
                    title: String(localized: "Destination Undetermined", table: "EditorXcodePlugin"),
                    message: String(localized: "The current target platform has not yet been resolved.", table: "EditorXcodePlugin")
                )
            )
        }

        return Report(reasons: reasons)
    }

    static func inspectWorkspaceContext() -> Report {
        inspectWorkspaceContext(input: makeWorkspaceInspectionInput())
    }

    static func inspectCurrentFileContext(uri: String?) -> Report {
        guard let input = makeFileInspectionInput(uri: uri) else {
            return inspectWorkspaceContext()
        }
        return inspectCurrentFileContext(input: input)
    }

    static func workspacePreflightError(operation: String, strength: Strength) -> XcodeLSPError? {
        workspacePreflightError(report: inspectWorkspaceContext(), strength: strength)
    }

    static func workspacePreflightMessage(operation: String, strength: Strength) -> String? {
        guard let error = workspacePreflightError(operation: operation, strength: strength) else {
            return nil
        }
        return XcodeLSPErrorClassifier.userMessage(for: error, operation: operation)
    }

    static func preflightError(
        uri: String?,
        operation: String,
        symbolName: String? = nil,
        strength: Strength
    ) -> XcodeLSPError? {
        guard let input = makeFileInspectionInput(uri: uri) else {
            return workspacePreflightError(operation: operation, strength: strength)
        }
        return preflightError(input: input, strength: strength)
    }

    static func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String? = nil,
        strength: Strength
    ) -> String? {
        guard let error = preflightError(uri: uri, operation: operation, symbolName: symbolName, strength: strength) else {
            return nil
        }
        return XcodeLSPErrorClassifier.userMessage(for: error, operation: operation)
    }

    static func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String? = nil
    ) -> String? {
        let context = LSPErrorContext(uri: uri, symbolName: symbolName, operation: operation)
        let classified = XcodeLSPErrorClassifier.classifyMissingResult(context: context)
        guard classified != .symbolNotFound else { return nil }
        return XcodeLSPErrorClassifier.userMessage(for: classified, operation: operation)
    }

    static func workspacePreflightError(report: Report, strength: Strength) -> XcodeLSPError? {
        guard let firstBlockingReason = report.reasons.first(where: { $0.severity == .error || (strength == .hard && $0.severity == .warning) }) else {
            return nil
        }

        switch firstBlockingReason.id {
        case "server-not-started":
            return .serverNotStarted
        case "build-context-unavailable", "build-context-resync":
            return .buildContextUnavailable(firstBlockingReason.message)
        default:
            return nil
        }
    }

    static func preflightError(input: FileInspectionInput, strength: Strength) -> XcodeLSPError? {
        let report = inspectCurrentFileContext(input: input)
        let workspaceError = workspacePreflightError(
            report: Report(reasons: report.reasons.filter { $0.id == "server-not-started" || $0.id == "build-context-unavailable" || $0.id == "build-context-resync" }),
            strength: strength
        )
        if let workspaceError {
            return workspaceError
        }

        let fileReasons = report.reasons.filter { reason in
            switch reason.id {
            case "file-not-in-target", "scheme-excludes-targets", "multiple-targets-ambiguous":
                return true
            case "multiple-targets-resolved", "destination-unknown":
                return strength == .hard && reason.severity == .warning
            default:
                return false
            }
        }

        guard let reason = fileReasons.first(where: { $0.severity == .error || (strength == .hard && $0.severity == .warning) }) else {
            return nil
        }

        switch reason.id {
        case "file-not-in-target":
            return .fileNotInTarget(input.fileName ?? String(localized: "Current File", table: "EditorXcodePlugin"))
        case "scheme-excludes-targets":
            return .fileTargetsExcludedByActiveScheme(
                file: input.fileName ?? String(localized: "Current File", table: "EditorXcodePlugin"),
                targets: input.matchedTargets,
                activeScheme: input.activeScheme
            )
        case "multiple-targets-ambiguous":
            return .fileInMultipleTargets(
                file: input.fileName ?? String(localized: "Current File", table: "EditorXcodePlugin"),
                targets: input.matchedTargets,
                activeScheme: input.activeScheme
            )
        default:
            return nil
        }
    }

    private static func makeWorkspaceInspectionInput() -> WorkspaceInspectionInput {
        let bridge = XcodeProjectContextBridge.shared
        return WorkspaceInspectionInput(
            isXcodeProject: bridge.cachedState?.isXcodeProject ?? false,
            isInitialized: bridge.cachedState?.isInitialized ?? false,
            buildContextStatus: bridge.buildContextProvider?.buildContextStatus ?? .unknown
        )
    }

    private static func makeFileInspectionInput(uri: String?) -> FileInspectionInput? {
        let bridge = XcodeProjectContextBridge.shared
        guard let uri, let url = URL(string: uri) else {
            return nil
        }

        return FileInspectionInput(
            workspace: makeWorkspaceInspectionInput(),
            fileName: url.lastPathComponent,
            activeScheme: bridge.cachedActiveScheme,
            activeDestinationName: bridge.activeDestination,
            matchedTargets: bridge.buildContextProvider?.findTargetsForFile(fileURL: url).map(\.name).sorted() ?? [],
            compatibleTargets: bridge.buildContextProvider?.targetsCompatibleWithActiveScheme(for: url).map(\.name).sorted() ?? [],
            preferredTarget: bridge.buildContextProvider?.resolvePreferredTarget(for: url)?.name
        )
    }
}
