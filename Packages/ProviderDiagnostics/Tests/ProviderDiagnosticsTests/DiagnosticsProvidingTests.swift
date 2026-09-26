import Foundation
import Testing
@testable import ProviderDiagnostics

@Suite("DiagnosticsArchive")
struct DiagnosticsArchiveTests {
    @Test("diagnostics archive preserves the export URL and filename")
    func diagnosticsArchivePreservesMetadata() {
        let url = URL(fileURLWithPath: "/tmp/Lumi-Diagnostics.zip")
        let archive = DiagnosticsArchive(url: url, filename: "Lumi-Diagnostics.zip")

        #expect(archive.url == url)
        #expect(archive.filename == "Lumi-Diagnostics.zip")
    }

    @Test("archives with identical url and filename are equal")
    func archivesAreEqualWhenIdentical() {
        let url = URL(fileURLWithPath: "/tmp/Lumi-Diagnostics.zip")
        let a = DiagnosticsArchive(url: url, filename: "Lumi-Diagnostics.zip")
        let b = DiagnosticsArchive(url: url, filename: "Lumi-Diagnostics.zip")
        #expect(a == b)
    }

    @Test("archives differing by url are not equal")
    func archivesDifferByURL() {
        let a = DiagnosticsArchive(
            url: URL(fileURLWithPath: "/tmp/a.zip"),
            filename: "Lumi-Diagnostics.zip"
        )
        let b = DiagnosticsArchive(
            url: URL(fileURLWithPath: "/tmp/b.zip"),
            filename: "Lumi-Diagnostics.zip"
        )
        #expect(a != b)
    }

    @Test("archives differing by filename are not equal")
    func archivesDifferByFilename() {
        let url = URL(fileURLWithPath: "/tmp/Lumi-Diagnostics.zip")
        let a = DiagnosticsArchive(url: url, filename: "Lumi-Diagnostics.zip")
        let b = DiagnosticsArchive(url: url, filename: "Other.zip")
        #expect(a != b)
    }

    @Test("archive accepts empty filename")
    func archiveAcceptsEmptyFilename() {
        let url = URL(fileURLWithPath: "/tmp/empty")
        let archive = DiagnosticsArchive(url: url, filename: "")
        #expect(archive.filename == "")
        #expect(archive.url == url)
    }

    @Test("archive preserves urls with spaces and special characters")
    func archivePreservesSpecialCharactersInURL() {
        let url = URL(fileURLWithPath: "/tmp/My Diagnostics/Report v1.2 (final).zip")
        let archive = DiagnosticsArchive(url: url, filename: "Report v1.2 (final).zip")
        #expect(archive.url == url)
        #expect(archive.filename == "Report v1.2 (final).zip")
    }
}

// MARK: - DiagnosticsProviding contract smoke test

/// A minimal in-memory conformer used only to verify the protocol surface can
/// be adopted and its async throwing contract compiles/behaves as documented.
private final class StubDiagnosticsProvider: DiagnosticsProviding, @unchecked Sendable {
    let logsDirectoryURL: URL
    private let makeArchive: () throws -> DiagnosticsArchive

    init(logsDirectoryURL: URL, makeArchive: @escaping () throws -> DiagnosticsArchive) {
        self.logsDirectoryURL = logsDirectoryURL
        self.makeArchive = makeArchive
    }

    func makeDiagnosticsArchive() async throws -> DiagnosticsArchive {
        try makeArchive()
    }
}

@Suite("DiagnosticsProviding contract")
struct DiagnosticsProvidingContractTests {
    @Test("conformer exposes logs directory URL")
    func exposesLogsDirectory() {
        let dir = URL(fileURLWithPath: "/tmp/logs")
        let provider = StubDiagnosticsProvider(logsDirectoryURL: dir) {
            DiagnosticsArchive(url: URL(fileURLWithPath: "/tmp/out.zip"), filename: "out.zip")
        }
        #expect(provider.logsDirectoryURL == dir)
    }

    @Test("makeDiagnosticsArchive rethrows errors from the underlying collector")
    func rethrowsCollectionErrors() async {
        enum TestError: Error, Equatable { case collectionFailed }
        let provider = StubDiagnosticsProvider(logsDirectoryURL: URL(fileURLWithPath: "/tmp/logs")) {
            throw TestError.collectionFailed
        }
        await #expect(throws: TestError.self) {
            _ = try await provider.makeDiagnosticsArchive()
        }
    }

    @Test("makeDiagnosticsArchive returns the produced archive on success")
    func returnsArchiveOnSuccess() async throws {
        let expected = DiagnosticsArchive(
            url: URL(fileURLWithPath: "/tmp/archive.zip"),
            filename: "archive.zip"
        )
        let provider = StubDiagnosticsProvider(logsDirectoryURL: URL(fileURLWithPath: "/tmp/logs")) {
            expected
        }
        let result = try await provider.makeDiagnosticsArchive()
        #expect(result == expected)
    }
}
