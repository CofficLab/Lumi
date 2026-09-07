import Foundation
import Testing
@testable import ProviderDiagnostics

@Test("diagnostics archive preserves the export URL and filename")
func diagnosticsArchivePreservesMetadata() {
    let url = URL(fileURLWithPath: "/tmp/Lumi-Diagnostics.zip")
    let archive = DiagnosticsArchive(url: url, filename: "Lumi-Diagnostics.zip")

    #expect(archive.url == url)
    #expect(archive.filename == "Lumi-Diagnostics.zip")
}
