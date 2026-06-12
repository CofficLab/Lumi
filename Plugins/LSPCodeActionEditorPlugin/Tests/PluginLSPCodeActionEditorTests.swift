import Testing
import Foundation
@testable import LSPCodeActionEditorPlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func uriMatchesDocumentAcceptsUnescapedFileURL() {
    let documentURL = URL(fileURLWithPath: "/tmp/project/My File.swift")

    #expect(CodeActionProvider.uriMatchesDocument(
        "file:///tmp/project/My File.swift",
        documentURL: documentURL
    ))
}

@Test func normalizeFileURIAcceptsUnescapedFileURL() {
    #expect(
        CodeActionProvider.normalizeFileURI("file:///tmp/project/My File.swift")
            == URL(fileURLWithPath: "/tmp/project/My File.swift").standardizedFileURL.absoluteString
    )
}
