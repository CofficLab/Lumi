@testable import HTMLPreviewKit
import Foundation
import Testing

@Suite("HTMLPreviewLoadPlanner")
struct HTMLPreviewLoadPlannerTests {

    @Test("loads raw HTML string without a base URL when no file URL is supplied")
    func rawHTMLWithoutFileURL() {
        let html = "<h1>Hello</h1>"
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in
            Issue.record("fileReader should not be called when fileURL is nil")
            return Data()
        })

        #expect(planner.loadRequest(html: html, fileURL: nil) == .html(html: html, baseURL: nil))
    }

    @Test("loads the file directly when in-memory UTF-8 HTML exactly matches the file")
    func matchingUTF8FileLoadsFileURL() throws {
        let html = "<html><body>cafè ☕️</body></html>"
        let fileURL = makeFileURL(fileName: "index.html")
        let planner = HTMLPreviewLoadPlanner(fileReader: { url in
            #expect(url == fileURL)
            return Data(html.utf8)
        })

        let request = planner.loadRequest(html: html, fileURL: fileURL)

        #expect(request == .file(
            fileURL: fileURL,
            readAccessURL: fileURL.deletingLastPathComponent()
        ))
    }

    @Test("loads the file directly when in-memory HTML matches a UTF-16 encoded file")
    func matchingUTF16FileLoadsFileURL() throws {
        let html = "<p>你好，世界</p>"
        let fileURL = makeFileURL(fileName: "utf16.htm")
        let utf16Data = try #require(html.data(using: .utf16))
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in utf16Data })

        #expect(planner.isHTMLInSyncWithFile(html, at: fileURL))
        #expect(planner.loadRequest(html: html, fileURL: fileURL) == .file(
            fileURL: fileURL,
            readAccessURL: fileURL.deletingLastPathComponent()
        ))
    }

    @Test("loads HTML string with the file parent directory as base URL when file content is different")
    func mismatchedFileLoadsHTMLWithBaseURL() {
        let html = "<link rel='stylesheet' href='style.css'><h1>Preview</h1>"
        let fileURL = makeFileURL(fileName: "preview.html")
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in Data("old content".utf8) })

        #expect(planner.loadRequest(html: html, fileURL: fileURL) == .html(
            html: html,
            baseURL: fileURL.deletingLastPathComponent().absoluteDirectoryURL
        ))
    }

    @Test("loads HTML string with a base URL when reading the file fails")
    func unreadableFileLoadsHTMLWithBaseURL() {
        struct ReadFailure: Error {}

        let html = "<img src='relative.png'>"
        let fileURL = makeFileURL(fileName: "missing.html")
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in throw ReadFailure() })

        #expect(!planner.isHTMLInSyncWithFile(html, at: fileURL))
        #expect(planner.loadRequest(html: html, fileURL: fileURL) == .html(
            html: html,
            baseURL: fileURL.deletingLastPathComponent().absoluteDirectoryURL
        ))
    }

    @Test("loads HTML string with a base URL when file data is not decodable as supported text")
    func undecodableFileLoadsHTMLWithBaseURL() {
        let html = "<p>Fallback</p>"
        let fileURL = makeFileURL(fileName: "binary.html")
        let invalidUTFData = Data([0xFF])
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in invalidUTFData })

        #expect(!planner.isHTMLInSyncWithFile(html, at: fileURL))
        #expect(planner.loadRequest(html: html, fileURL: fileURL) == .html(
            html: html,
            baseURL: fileURL.deletingLastPathComponent().absoluteDirectoryURL
        ))
    }

    @Test("absoluteDirectoryURL always has a trailing slash")
    func absoluteDirectoryURLAddsTrailingSlash() {
        let directoryURL = URL(fileURLWithPath: "/tmp/HTMLPreviewKit Assets")

        #expect(directoryURL.absoluteDirectoryURL.absoluteString.hasSuffix("/"))
        #expect(directoryURL.absoluteDirectoryURL.path == "/tmp/HTMLPreviewKit Assets")
    }

    @Test("absoluteDirectoryURL preserves an existing trailing slash")
    func absoluteDirectoryURLPreservesTrailingSlash() {
        let directoryURL = URL(fileURLWithPath: "/tmp/HTMLPreviewKit Assets/", isDirectory: true)

        #expect(directoryURL.absoluteDirectoryURL.absoluteString.hasSuffix("/"))
        #expect(directoryURL.absoluteDirectoryURL == directoryURL)
    }

    private func makeFileURL(fileName: String) -> URL {
        URL(fileURLWithPath: "/tmp/HTMLPreviewKit Tests/Nested/\(fileName)")
    }
}
