import Foundation

// MARK: - Mobile Document Store

/// Owns the mobile session's input copy and temporary output directory.
///
/// Import flow:
/// 1. The system file picker returns a (possibly security-scoped) URL.
/// 2. The store starts the security scope, copies the file into this
///    session's unique inbox in Caches on a background executor, and
///    inspects the copy.
/// 3. On success the copy is committed (keeping the user's file name as the
///    final basename) and the external scope is released; on failure or
///    cancellation the candidate copy is removed and the previous session
///    is untouched.
///
/// The store deliberately stays platform-agnostic (Foundation only) so the
/// copy / validate / rollback logic is covered by the shared package tests.
@MainActor
final class MobileDocumentStore {
    enum ImportError: LocalizedError {
        case copyFailed(URL)
        case inspectionFailed(URL, message: String)

        var errorDescription: String? {
            switch self {
            case .copyFailed(let url):
                return BookletLocalization.string(
                    "Could not read this PDF. Please make sure the file is downloaded or pick it again. (%@)",
                    url.lastPathComponent
                )
            case .inspectionFailed(_, let message):
                return message
            }
        }
    }

    private let inspector: PDFInspector
    private let sessionID = UUID()
    private var committedCopyURL: URL?

    /// Unique directory for this session's inbox and outputs.
    let sessionDirectory: URL

    init(inspector: PDFInspector = PDFInspector()) {
        self.inspector = inspector
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        sessionDirectory = base
            .appendingPathComponent("BookletMakerMobile", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
    }

    var inboxDirectory: URL {
        sessionDirectory.appendingPathComponent("inbox", isDirectory: true)
    }

    /// Directory where generated results live, isolated per job.
    var outputDirectory: URL {
        sessionDirectory.appendingPathComponent("output", isDirectory: true)
    }

    /// Copy `url` into the session inbox and inspect the copy.
    ///
    /// - Returns: the committed document backed by the local copy.
    /// - Throws: `ImportError` on any failure. A failed import removes the
    ///   candidate copy and leaves the previous document untouched.
    func importPDF(from url: URL) async throws -> CurrentPDFDocument {
        let didStartScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(
            at: inboxDirectory,
            withIntermediateDirectories: true
        )
        let candidate = inboxDirectory
            .appendingPathComponent(".candidate-\(UUID().uuidString).pdf")

        // Copy on a background executor so iCloud / File Provider
        // materialisation never blocks the UI thread.
        do {
            try await Task.detached(priority: .userInitiated) {
                if FileManager.default.fileExists(atPath: candidate.path) {
                    try FileManager.default.removeItem(at: candidate)
                }
                try FileManager.default.copyItem(at: url, to: candidate)
            }.value
        } catch {
            try? FileManager.default.removeItem(at: candidate)
            throw ImportError.copyFailed(url)
        }

        do {
            let info = try await inspector.inspect(candidate)
            // Commit: keep the user's file name as the final basename.
            let finalURL = inboxDirectory
                .appendingPathComponent(url.lastPathComponent, isDirectory: false)
            try? FileManager.default.removeItem(at: finalURL)
            try FileManager.default.moveItem(at: candidate, to: finalURL)
            committedCopyURL = finalURL
            return CurrentPDFDocument(source: .user, url: finalURL, info: info)
        } catch {
            try? FileManager.default.removeItem(at: candidate)
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            throw ImportError.inspectionFailed(url, message: message)
        }
    }

    /// Remove the committed copy and this session's output directory.
    ///
    /// Call when the user closes the document. URLs still referenced by a
    /// system save/share sheet are the responsibility of the caller to
    /// release before this is invoked.
    func clearSession() {
        committedCopyURL = nil
        try? FileManager.default.removeItem(at: inboxDirectory)
        try? FileManager.default.removeItem(at: outputDirectory)
    }

    /// Remove stale session directories left behind by earlier launches,
    /// keeping the active session (if any).
    static func cleanupStaleSessions(keeping active: MobileDocumentStore? = nil) {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return }
        let root = base.appendingPathComponent("BookletMakerMobile", isDirectory: true)
        let activePath = active?.sessionDirectory.path
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else { return }
        for entry in entries where entry.hasDirectoryPath && entry.path != activePath {
            try? FileManager.default.removeItem(at: entry)
        }
    }
}
