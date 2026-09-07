import Foundation

/// The result of an explicit user-requested diagnostic export.
public struct DiagnosticsArchive: Sendable, Equatable {
    public let url: URL
    public let filename: String

    public init(url: URL, filename: String) {
        self.url = url
        self.filename = filename
    }
}

/// Application diagnostics exposed to user-facing support surfaces.
///
/// The provider owns collection, retention, and redaction. Consumers only need
/// to request an archive and decide where the user wants to save it.
public protocol DiagnosticsProviding: AnyObject, Sendable {
    var logsDirectoryURL: URL { get }

    func makeDiagnosticsArchive() async throws -> DiagnosticsArchive
}
