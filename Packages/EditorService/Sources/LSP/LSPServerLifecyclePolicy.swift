import Foundation

/// Pure lifecycle rules for deciding when an existing SourceKit-LSP process can be reused.
enum LSPServerLifecyclePolicy {
    static func startTaskSignature(languageId: String, projectPath: String) -> String {
        "\(languageId)|\(projectPath)"
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
}
