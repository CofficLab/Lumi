import Foundation
import LanguageServerProtocol

/// Filters SourceKit diagnostics that are expected before Xcode build context is ready.
enum LSPDiagnosticBuildContextPolicy {
    static func isNoSuchModuleDiagnostic(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("no such module")
    }

    static func shouldPublishDiagnostic(
        _ diagnostic: Diagnostic,
        buildServerPathAvailable: Bool
    ) -> Bool {
        guard !buildServerPathAvailable else { return true }
        return !isNoSuchModuleDiagnostic(diagnostic.message)
    }

    static func filteredDiagnostics(
        _ diagnostics: [Diagnostic],
        buildServerPathAvailable: Bool
    ) -> [Diagnostic] {
        diagnostics.filter {
            shouldPublishDiagnostic($0, buildServerPathAvailable: buildServerPathAvailable)
        }
    }
}
