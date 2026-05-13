import Foundation

/// 语义可用性检查的上下文提供者协议
///
/// XcodeKit 通过此协议获取运行时状态，避免直接依赖 App 层单例。
/// App 层在桥接时实现此协议，将 Bridge 的状态传递给 XcodeKit。
@MainActor
public protocol XcodeContextProviding: AnyObject {
    var cachedState: BridgeCachedState? { get }
    var buildContextProvider: XcodeBuildContextProvider? { get }
    var cachedActiveScheme: String? { get }
    var activeDestination: String? { get }
}

@MainActor
public enum XcodeSemanticAvailability {
    public enum Strength {
        case hard
        case soft
    }

    public enum ReasonSeverity: String, Sendable {
        case info
        case warning
        case error
    }

    public struct Reason: Identifiable, Sendable, Equatable {
        public let id: String
        public let severity: ReasonSeverity
        public let title: String
        public let message: String

        public init(id: String, severity: ReasonSeverity, title: String, message: String) {
            self.id = id
            self.severity = severity
            self.title = title
            self.message = message
        }
    }

    public struct Report: Sendable, Equatable {
        public let reasons: [Reason]

        public init(reasons: [Reason]) {
            self.reasons = reasons
        }

        public var hasBlockingIssue: Bool {
            reasons.contains { $0.severity == .error }
        }

        public var hasWarnings: Bool {
            reasons.contains { $0.severity == .warning }
        }
    }

    public struct WorkspaceInspectionInput: Sendable, Equatable {
        public let isXcodeProject: Bool
        public let isInitialized: Bool
        public let buildContextStatus: XcodeBuildContextProvider.BuildContextStatus

        public init(isXcodeProject: Bool, isInitialized: Bool, buildContextStatus: XcodeBuildContextProvider.BuildContextStatus) {
            self.isXcodeProject = isXcodeProject
            self.isInitialized = isInitialized
            self.buildContextStatus = buildContextStatus
        }
    }

    public struct FileInspectionInput: Sendable, Equatable {
        public let workspace: WorkspaceInspectionInput
        public let fileName: String?
        public let activeScheme: String?
        public let activeDestinationName: String?
        public let matchedTargets: [String]
        public let compatibleTargets: [String]
        public let preferredTarget: String?

        public init(
            workspace: WorkspaceInspectionInput,
            fileName: String?,
            activeScheme: String?,
            activeDestinationName: String?,
            matchedTargets: [String],
            compatibleTargets: [String],
            preferredTarget: String?
        ) {
            self.workspace = workspace
            self.fileName = fileName
            self.activeScheme = activeScheme
            self.activeDestinationName = activeDestinationName
            self.matchedTargets = matchedTargets
            self.compatibleTargets = compatibleTargets
            self.preferredTarget = preferredTarget
        }
    }

    // MARK: - Pure Logic (no dependencies)

    public static func inspectWorkspaceContext(input: WorkspaceInspectionInput) -> Report {
        guard input.isXcodeProject else {
            return Report(reasons: [])
        }

        var reasons: [Reason] = []

        if !input.isInitialized {
            reasons.append(
                Reason(
                    id: "server-not-started",
                    severity: .error,
                    title: "LSP Not Initialized",
                    message: "The current Xcode project context has not yet completed initialization."
                )
            )
        }

        if case .unavailable(let reason) = input.buildContextStatus {
            reasons.append(
                Reason(
                    id: "build-context-unavailable",
                    severity: .error,
                    title: "Build Context Unavailable",
                    message: reason
                )
            )
        }

        if case .needsResync = input.buildContextStatus {
            reasons.append(
                Reason(
                    id: "build-context-resync",
                    severity: .warning,
                    title: "Build Context Needs Sync",
                    message: "The current build context has expired, workspace semantic results may be inaccurate."
                )
            )
        }

        return Report(reasons: reasons)
    }

    public static func inspectCurrentFileContext(input: FileInspectionInput) -> Report {
        var reasons = inspectWorkspaceContext(input: input.workspace).reasons

        guard let fileName = input.fileName else {
            return Report(reasons: reasons)
        }

        if input.matchedTargets.isEmpty {
            reasons.append(
                Reason(
                    id: "file-not-in-target",
                    severity: .error,
                    title: "File Not in Target",
                    message: "'\(fileName)' does not belong to any compilation target."
                )
            )
            return Report(reasons: reasons)
        }

        if input.compatibleTargets.isEmpty {
            let scheme = input.activeScheme ?? "Not Selected"
            let targets = input.matchedTargets.joined(separator: ", ")
            reasons.append(
                Reason(
                    id: "scheme-excludes-targets",
                    severity: .error,
                    title: "Scheme Does Not Cover File Target",
                    message: "Current scheme '\(scheme)' does not include \(targets)."
                )
            )
        }

        if input.matchedTargets.count > 1 {
            if let preferredTarget = input.preferredTarget {
                reasons.append(
                    Reason(
                        id: "multiple-targets-resolved",
                        severity: .info,
                        title: "Multi-Target File",
                        message: "Current file matches multiple targets, currently resolving with '\(preferredTarget)'."
                    )
                )
            } else {
                let targets = input.matchedTargets.joined(separator: ", ")
                reasons.append(
                    Reason(
                        id: "multiple-targets-ambiguous",
                        severity: .warning,
                        title: "Multi-Target Ambiguity",
                        message: "Current file belongs to \(targets), but current scheme cannot uniquely determine semantic context."
                    )
                )
            }
        }

        if input.activeDestinationName == nil {
            reasons.append(
                Reason(
                    id: "destination-unknown",
                    severity: .warning,
                    title: "Destination Undetermined",
                    message: "The current target platform has not yet been resolved."
                )
            )
        }

        return Report(reasons: reasons)
    }

    // MARK: - Preflight Errors (pure logic)

    public static func workspacePreflightError(report: Report, strength: Strength) -> XcodeLSPError? {
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

    public static func preflightError(input: FileInspectionInput, strength: Strength) -> XcodeLSPError? {
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
            return .fileNotInTarget(input.fileName ?? "Current File")
        case "scheme-excludes-targets":
            return .fileTargetsExcludedByActiveScheme(
                file: input.fileName ?? "Current File",
                targets: input.matchedTargets,
                activeScheme: input.activeScheme
            )
        case "multiple-targets-ambiguous":
            return .fileInMultipleTargets(
                file: input.fileName ?? "Current File",
                targets: input.matchedTargets,
                activeScheme: input.activeScheme
            )
        default:
            return nil
        }
    }

    // MARK: - Convenience methods with context provider

    public static func inspectWorkspaceContext(contextProvider: any XcodeContextProviding) -> Report {
        inspectWorkspaceContext(input: makeWorkspaceInspectionInput(contextProvider: contextProvider))
    }

    public static func inspectCurrentFileContext(uri: String?, contextProvider: any XcodeContextProviding) -> Report {
        guard let input = makeFileInspectionInput(uri: uri, contextProvider: contextProvider) else {
            return inspectWorkspaceContext(contextProvider: contextProvider)
        }
        return inspectCurrentFileContext(input: input)
    }

    public static func inspectCurrentFileContext(
        snapshot: XcodeEditorContextSnapshot?,
        cachedState: BridgeCachedState?,
        buildContextStatus: XcodeBuildContextProvider.BuildContextStatus
    ) -> Report {
        let workspace = WorkspaceInspectionInput(
            isXcodeProject: cachedState?.isXcodeProject ?? snapshot?.isXcodeProject ?? false,
            isInitialized: cachedState?.isInitialized ?? false,
            buildContextStatus: buildContextStatus
        )

        guard let snapshot else {
            return inspectWorkspaceContext(input: workspace)
        }

        let matchedTargets = snapshot.currentFileMatchedTargets.sorted()
        let compatibleTargets = matchedTargets.filter { snapshot.activeSchemeBuildableTargets.contains($0) }.sorted()
        let fileName = snapshot.currentFilePath.map { URL(filePath: $0).lastPathComponent }

        return inspectCurrentFileContext(
            input: FileInspectionInput(
                workspace: workspace,
                fileName: fileName,
                activeScheme: snapshot.activeScheme,
                activeDestinationName: snapshot.activeDestination,
                matchedTargets: matchedTargets,
                compatibleTargets: compatibleTargets,
                preferredTarget: snapshot.currentFileTarget
            )
        )
    }

    public static func workspacePreflightError(operation: String, strength: Strength, contextProvider: any XcodeContextProviding) -> XcodeLSPError? {
        workspacePreflightError(report: inspectWorkspaceContext(contextProvider: contextProvider), strength: strength)
    }

    public static func workspacePreflightMessage(operation: String, strength: Strength, contextProvider: any XcodeContextProviding) -> String? {
        guard let error = workspacePreflightError(operation: operation, strength: strength, contextProvider: contextProvider) else {
            return nil
        }
        return XcodeLSPError.userMessage(for: error, operation: operation)
    }

    public static func preflightError(
        uri: String?,
        operation: String,
        symbolName: String? = nil,
        strength: Strength,
        contextProvider: any XcodeContextProviding
    ) -> XcodeLSPError? {
        guard let input = makeFileInspectionInput(uri: uri, contextProvider: contextProvider) else {
            return workspacePreflightError(operation: operation, strength: strength, contextProvider: contextProvider)
        }
        return preflightError(input: input, strength: strength)
    }

    public static func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String? = nil,
        strength: Strength,
        contextProvider: any XcodeContextProviding
    ) -> String? {
        guard let error = preflightError(uri: uri, operation: operation, symbolName: symbolName, strength: strength, contextProvider: contextProvider) else {
            return nil
        }
        return XcodeLSPError.userMessage(for: error, operation: operation)
    }

    public static func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String? = nil,
        contextProvider: any XcodeContextProviding
    ) -> String? {
        let context = LSPErrorContext(uri: uri, symbolName: symbolName, operation: operation)
        let classified = classifyMissingResult(context: context, contextProvider: contextProvider)
        guard classified != .symbolNotFound else { return nil }
        return XcodeLSPError.userMessage(for: classified, operation: operation)
    }

    // MARK: - Classifiers

    public static func classifyPreflight(context: LSPErrorContext, contextProvider: any XcodeContextProviding) -> XcodeLSPError? {
        if let cached = contextProvider.cachedState, !cached.isXcodeProject {
            return nil
        }

        if let cached = contextProvider.cachedState, !cached.isInitialized {
            return .serverNotStarted
        }

        if case .unavailable(let reason) = contextProvider.buildContextProvider?.buildContextStatus {
            return .buildContextUnavailable(reason)
        }
        if case .needsResync = contextProvider.buildContextProvider?.buildContextStatus {
            return .buildContextUnavailable("Build context needs to be resynchronized")
        }

        guard let uri = context.uri, let url = URL(string: uri) else {
            return nil
        }

        let matchedTargets = contextProvider.buildContextProvider?.findTargetsForFile(fileURL: url).map(\.name) ?? []
        if matchedTargets.isEmpty {
            return .fileNotInTarget(url.lastPathComponent)
        }

        let compatibleTargets = contextProvider.buildContextProvider?.targetsCompatibleWithActiveScheme(for: url).map(\.name) ?? matchedTargets
        if compatibleTargets.isEmpty {
            return .fileTargetsExcludedByActiveScheme(
                file: url.lastPathComponent,
                targets: matchedTargets,
                activeScheme: contextProvider.cachedActiveScheme
            )
        }

        if matchedTargets.count > 1, contextProvider.buildContextProvider?.resolvePreferredTarget(for: url) == nil {
            return .fileInMultipleTargets(
                file: url.lastPathComponent,
                targets: matchedTargets,
                activeScheme: contextProvider.cachedActiveScheme
            )
        }

        return nil
    }

    public static func classify(_ error: Error, context: LSPErrorContext, contextProvider: any XcodeContextProviding) -> XcodeLSPError {
        let description = String(describing: error).lowercased()

        if description.contains("datastreamclosed") ||
           description.contains("protocoltransporterror") ||
           description.contains("streamclosed") ||
           description.contains("connection closed") {
            return .serverDisconnected
        }

        if description.contains("timeout") || description.contains("timed out") {
            return .requestTimeout
        }

        if let cached = contextProvider.cachedState, !cached.isXcodeProject {
            return .noProjectContext
        }
        if let preflight = classifyPreflight(context: context, contextProvider: contextProvider) {
            return preflight
        }

        if description.contains("nil") || description.contains("null") ||
           description.contains("empty") || description.contains("not found") {
            return .symbolNotResolved(symbolName: context.symbolName)
        }

        return .unknown(String(describing: error))
    }

    public static func classifyMissingResult(context: LSPErrorContext, contextProvider: any XcodeContextProviding) -> XcodeLSPError {
        if let cached = contextProvider.cachedState, !cached.isXcodeProject {
            return .symbolNotFound
        }

        if let preflight = classifyPreflight(context: context, contextProvider: contextProvider) {
            return preflight
        }

        return .symbolNotResolved(symbolName: context.symbolName)
    }

    // MARK: - Private Helpers

    private static func makeWorkspaceInspectionInput(contextProvider: any XcodeContextProviding) -> WorkspaceInspectionInput {
        WorkspaceInspectionInput(
            isXcodeProject: contextProvider.cachedState?.isXcodeProject ?? false,
            isInitialized: contextProvider.cachedState?.isInitialized ?? false,
            buildContextStatus: contextProvider.buildContextProvider?.buildContextStatus ?? .unknown
        )
    }

    private static func makeFileInspectionInput(uri: String?, contextProvider: any XcodeContextProviding) -> FileInspectionInput? {
        guard let uri, let url = URL(string: uri) else {
            return nil
        }

        return FileInspectionInput(
            workspace: makeWorkspaceInspectionInput(contextProvider: contextProvider),
            fileName: url.lastPathComponent,
            activeScheme: contextProvider.cachedActiveScheme,
            activeDestinationName: contextProvider.activeDestination,
            matchedTargets: contextProvider.buildContextProvider?.findTargetsForFile(fileURL: url).map(\.name).sorted() ?? [],
            compatibleTargets: contextProvider.buildContextProvider?.targetsCompatibleWithActiveScheme(for: url).map(\.name).sorted() ?? [],
            preferredTarget: contextProvider.buildContextProvider?.resolvePreferredTarget(for: url)?.name
        )
    }
}
