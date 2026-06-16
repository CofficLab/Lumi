import Foundation

/// Pure lifecycle rules for deciding when an existing SourceKit-LSP process can be reused.
enum LSPServerLifecyclePolicy {
    static func startTaskSignature(
        languageId: String,
        projectPath: String,
        buildServerPath: String? = nil
    ) -> String {
        let buildServerComponent = buildServerPath ?? "<none>"
        return "\(languageId)|\(projectPath)|\(buildServerComponent)"
    }

    static func buildServerPath(from options: [String: String]?) -> String? {
        guard let raw = options?["buildServerPath"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    /// Returns whether the currently running server already matches the requested context.
    static func canReuseExistingServer(
        hasServer: Bool,
        activeLanguageId: String?,
        requestedLanguageId: String,
        activeProjectPath: String?,
        requestedProjectPath: String,
        activeBuildServerPath: String?,
        requestedBuildServerPath: String?
    ) -> Bool {
        guard hasServer,
              activeLanguageId == requestedLanguageId,
              activeProjectPath == requestedProjectPath else {
            return false
        }
        return activeBuildServerPath == requestedBuildServerPath
    }

    /// Mirrors the pre-fix reuse guard in `ensureServer` that ignored buildServerPath changes.
    static func legacyCanReuseExistingServer(
        hasServer: Bool,
        activeLanguageId: String?,
        requestedLanguageId: String,
        activeProjectPath: String?,
        requestedProjectPath: String
    ) -> Bool {
        hasServer
            && activeLanguageId == requestedLanguageId
            && activeProjectPath == requestedProjectPath
    }

    /// Mirrors pre-fix `openDocument`, which skipped `ensureServer` whenever a server was already running.
    static func legacyOpenDocumentWouldSkipEnsureServer(
        hasServer: Bool,
        activeLanguageId: String?,
        requestedLanguageId: String
    ) -> Bool {
        hasServer && activeLanguageId == requestedLanguageId
    }

    /// Current `openDocument` always re-evaluates server reuse via `ensureServer`.
    static func openDocumentShouldEnsureServer(
        hasServer: Bool,
        activeLanguageId: String?,
        requestedLanguageId: String,
        activeProjectPath: String?,
        requestedProjectPath: String,
        activeBuildServerPath: String?,
        requestedBuildServerPath: String?
    ) -> Bool {
        !canReuseExistingServer(
            hasServer: hasServer,
            activeLanguageId: activeLanguageId,
            requestedLanguageId: requestedLanguageId,
            activeProjectPath: activeProjectPath,
            requestedProjectPath: requestedProjectPath,
            activeBuildServerPath: activeBuildServerPath,
            requestedBuildServerPath: requestedBuildServerPath
        )
    }
}
