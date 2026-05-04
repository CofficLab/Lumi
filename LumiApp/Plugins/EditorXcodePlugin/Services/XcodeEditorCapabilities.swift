import Foundation

@MainActor
final class XcodeProjectContextCapabilityAdapter: SuperEditorProjectContextCapability {
    let id = "XcodeProjectContextCapability"
    private let bridge: XcodeProjectContextBridge

    init(bridge: XcodeProjectContextBridge = .shared) {
        self.bridge = bridge
    }

    func canHandleProject(at path: String?) -> Bool {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: path))
    }

    func projectOpened(at path: String) async {
        await bridge.projectOpened(at: path)
    }

    func projectClosed() {
        bridge.projectClosed()
    }

    func resyncProjectContext() async {
        await bridge.resyncBuildContext()
    }

    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot? {
        guard let snapshot = bridge.makeEditorContextSnapshot(currentFileURL: currentFileURL) else { return nil }
        return EditorProjectContextSnapshot(
            projectPath: snapshot.projectPath,
            workspaceName: snapshot.workspaceName,
            workspacePath: snapshot.workspacePath,
            activeScheme: snapshot.activeScheme,
            activeSchemeBuildableTargets: snapshot.activeSchemeBuildableTargets,
            activeConfiguration: snapshot.activeConfiguration,
            activeDestination: snapshot.activeDestination,
            contextStatus: status(from: snapshot.buildContextStatus),
            isStructuredProject: snapshot.isXcodeProject,
            schemes: snapshot.schemes,
            configurations: snapshot.configurations,
            currentFilePath: snapshot.currentFilePath,
            currentFilePrimaryTarget: snapshot.currentFileTarget,
            currentFileMatchedTargets: snapshot.currentFileMatchedTargets,
            currentFileIsInTarget: snapshot.currentFileIsInTarget
        )
    }

    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?) {
        guard let snapshot else {
            bridge.updateLatestEditorSnapshot(nil)
            return
        }
        bridge.updateLatestEditorSnapshot(
            XcodeEditorContextSnapshot(
                projectPath: snapshot.projectPath,
                workspaceName: snapshot.workspaceName,
                workspacePath: snapshot.workspacePath,
                activeScheme: snapshot.activeScheme,
                activeSchemeBuildableTargets: snapshot.activeSchemeBuildableTargets,
                activeConfiguration: snapshot.activeConfiguration,
                activeDestination: snapshot.activeDestination,
                buildContextStatus: snapshot.contextStatus.displayDescription,
                isXcodeProject: snapshot.isStructuredProject,
                schemes: snapshot.schemes,
                configurations: snapshot.configurations,
                currentFilePath: snapshot.currentFilePath,
                currentFileTarget: snapshot.currentFilePrimaryTarget,
                currentFileMatchedTargets: snapshot.currentFileMatchedTargets,
                currentFileIsInTarget: snapshot.currentFileIsInTarget
            )
        )
    }

    private func status(from description: String) -> EditorProjectContextStatus {
        if description.contains(String(localized: "Needs resync", table: "EditorXcodePlugin")) {
            return .needsResync
        }
        if description.contains(String(localized: "Resolving build context...", table: "EditorXcodePlugin")) {
            return .resolving
        }
        if description.contains(": ") && !description.contains(String(localized: "Available", table: "EditorXcodePlugin")) {
            // Unavailable: <reason> format
            let prefix = String(localized: "Unavailable", table: "EditorXcodePlugin") + ": "
            if description.hasPrefix(prefix) {
                return .unavailable(String(description.dropFirst(prefix.count)))
            }
            return .unavailable(description)
        }
        if description.contains(String(localized: "Available", table: "EditorXcodePlugin")) {
            return .available(description)
        }
        if description == String(localized: "Not Initialized", table: "EditorXcodePlugin")
            || description == String(localized: "Unknown", table: "EditorXcodePlugin") {
            return .unknown
        }
        return .available(description)
    }
}

@MainActor
final class XcodeLanguageIntegrationCapabilityAdapter: SuperEditorLanguageIntegrationCapability {
    let id = "XcodeLanguageIntegrationCapability"
    private let bridge: XcodeProjectContextBridge

    init(bridge: XcodeProjectContextBridge = .shared) {
        self.bridge = bridge
    }

    func supports(languageId: String, projectPath: String?) -> Bool {
        guard languageId == "swift" || languageId == "sourcekit" else { return false }
        guard let projectPath, !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: projectPath))
    }

    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
        guard supports(languageId: languageId, projectPath: projectPath),
              let folders = bridge.makeWorkspaceFolders(),
              !folders.isEmpty else {
            return nil
        }
        return folders.compactMap { item in
            guard let uri = item["uri"], let name = item["name"] else { return nil }
            return EditorWorkspaceFolder(uri: uri, name: name)
        }
    }

    func initializationOptions(for languageId: String, projectPath: String) -> [String: String]? {
        guard supports(languageId: languageId, projectPath: projectPath),
              let options = bridge.makeInitializationOptions(),
              !options.isEmpty else {
            return nil
        }
        return options.reduce(into: [String: String]()) { partial, entry in
            partial[entry.key] = String(describing: entry.value)
        }
    }
}

@MainActor
final class XcodeSemanticCapabilityAdapter: SuperEditorSemanticCapability {
    let id = "XcodeSemanticCapability"

    func canHandle(uri: String?) -> Bool {
        guard let uri, !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }

    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport {
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(uri: uri)
        return EditorSemanticAvailabilityReport(
            reasons: report.reasons.map { reason in
                EditorSemanticAvailabilityReason(
                    id: reason.id,
                    severity: mapSeverity(reason.severity),
                    title: reason.title,
                    message: reason.message
                )
            }
        )
    }

    func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> String? {
        XcodeSemanticAvailability.preflightMessage(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            strength: strength == .hard ? .hard : .soft
        )
    }

    func preflightError(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> EditorLanguageFeatureError? {
        guard let error = XcodeSemanticAvailability.preflightError(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            strength: strength == .hard ? .hard : .soft
        ) else {
            return nil
        }

        return EditorLanguageFeatureError(
            domain: "xcode.semantic",
            code: error.category,
            message: error.localizedDescription,
            suggestion: error.suggestedAction
        )
    }

    func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String?
    ) -> String? {
        XcodeSemanticAvailability.missingResultMessage(
            uri: uri,
            operation: operation,
            symbolName: symbolName
        )
    }

    private func mapSeverity(
        _ severity: XcodeSemanticAvailability.ReasonSeverity
    ) -> EditorSemanticAvailabilitySeverity {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}
