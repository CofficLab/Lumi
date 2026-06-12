import Testing
import LanguageServerProtocol
@testable import LSPDocumentLinkEditorPlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func documentLinkDetectsURLSchemesCaseInsensitively() {
    #expect(makeLink(target: "https://example.com").isURL)
    #expect(makeLink(target: "HTTP://example.com").isURL)
    #expect(makeLink(target: "HTTPS://example.com").isURL)
    #expect(!makeLink(target: "mailto:hello@example.com").isURL)
}

@Test func documentLinkDetectsFileSchemesCaseInsensitively() {
    #expect(makeLink(target: "file:///tmp/readme.md").isFilePath)
    #expect(makeLink(target: "FILE:///tmp/readme.md").isFilePath)
    #expect(!makeLink(target: "https://example.com/readme.md").isFilePath)
}

private func makeLink(target: DocumentUri?) -> EditorDocumentLink {
    EditorDocumentLink(
        range: LSPRange(
            start: Position(line: 0, character: 0),
            end: Position(line: 0, character: 1)
        ),
        target: target,
        tooltip: nil,
        data: nil
    )
}
