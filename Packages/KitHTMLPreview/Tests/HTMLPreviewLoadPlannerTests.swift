@testable import KitHTMLPreview
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

    @Test("default file reader reads real files from disk and detects sync")
    func defaultFileReaderUsesFileSystem() throws {
        let html = "<html><body>on disk</body></html>"
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitHTMLPreview DefaultReader", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("index.html")
        try Data(html.utf8).write(to: fileURL)

        let planner = HTMLPreviewLoadPlanner()

        #expect(planner.isHTMLInSyncWithFile(html, at: fileURL))
        #expect(planner.loadRequest(html: html, fileURL: fileURL) == .file(
            fileURL: fileURL,
            readAccessURL: directory
        ))
        #expect(!planner.isHTMLInSyncWithFile("<p>stale</p>", at: fileURL))
    }

    @Test("absoluteDirectoryURL always has a trailing slash")
    func absoluteDirectoryURLAddsTrailingSlash() {
        let directoryURL = URL(fileURLWithPath: "/tmp/KitHTMLPreview Assets")

        #expect(directoryURL.absoluteDirectoryURL.absoluteString.hasSuffix("/"))
        #expect(directoryURL.absoluteDirectoryURL.path == "/tmp/KitHTMLPreview Assets")
    }

    @Test("absoluteDirectoryURL preserves an existing trailing slash")
    func absoluteDirectoryURLPreservesTrailingSlash() {
        let directoryURL = URL(fileURLWithPath: "/tmp/KitHTMLPreview Assets/", isDirectory: true)

        #expect(directoryURL.absoluteDirectoryURL.absoluteString.hasSuffix("/"))
        #expect(directoryURL.absoluteDirectoryURL == directoryURL)
    }

    @Test("read access root from an ancestor directory is honored for nested pages")
    func ancestorReadAccessRootIsHonored() {
        let fileURL = makeFileURL(fileName: "zh-Hans.html")
        let root = URL(fileURLWithPath: "/tmp/KitHTMLPreview Tests", isDirectory: true)
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in Data("<html></html>".utf8) })

        #expect(planner.loadRequest(html: "<html></html>", fileURL: fileURL, readAccessRootURL: root) == .file(
            fileURL: fileURL,
            readAccessURL: root
        ))
    }

    @Test("read access root that does not contain the file falls back to the file directory")
    func unrelatedReadAccessRootFallsBackToParent() {
        let fileURL = makeFileURL(fileName: "index.html")
        let unrelated = URL(fileURLWithPath: "/tmp/KitHTMLPreview Other", isDirectory: true)
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in Data("<html></html>".utf8) })

        #expect(planner.loadRequest(html: "<html></html>", fileURL: fileURL, readAccessRootURL: unrelated) == .file(
            fileURL: fileURL,
            readAccessURL: fileURL.deletingLastPathComponent()
        ))
    }

    @Test("empty HTML with a readable file loads the file (Canvas snapshot fallback, #1052)")
    func emptyHTMLWithReadableFileLoadsFileURL() {
        let fileURL = makeFileURL(fileName: "canvas.html")
        let fileHTML = "<html><body>canvas</body></html>"
        let planner = HTMLPreviewLoadPlanner(fileReader: { url in
            #expect(url == fileURL)
            return Data(fileHTML.utf8)
        })

        #expect(planner.loadRequest(html: "", fileURL: fileURL) == .file(
            fileURL: fileURL,
            readAccessURL: fileURL.deletingLastPathComponent()
        ))
    }

    @Test("empty HTML with an unreadable file falls back to an empty HTML document")
    func emptyHTMLWithUnreadableFileFallsBackToHTML() {
        struct ReadFailure: Error {}

        let fileURL = makeFileURL(fileName: "missing-canvas.html")
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in throw ReadFailure() })

        #expect(planner.loadRequest(html: "", fileURL: fileURL) == .html(
            html: "",
            baseURL: fileURL.deletingLastPathComponent().absoluteDirectoryURL
        ))
    }

    @Test("empty HTML without a file URL stays an empty HTML document")
    func emptyHTMLWithoutFileURLStaysHTML() {
        let planner = HTMLPreviewLoadPlanner(fileReader: { _ in
            Issue.record("fileReader should not be called when fileURL is nil")
            return Data()
        })

        #expect(planner.loadRequest(html: "", fileURL: nil) == .html(html: "", baseURL: nil))
    }

    @Test("view only shows the empty state without both HTML text and a file (#1052)")
    func viewEmptyStateRequiresNoTextAndNoFile() {
        #expect(HTMLPreviewView.hasNoContent(htmlText: "", fileURL: nil))

        let fileURL = makeFileURL(fileName: "canvas.html")
        #expect(!HTMLPreviewView.hasNoContent(htmlText: "", fileURL: fileURL))
        #expect(!HTMLPreviewView.hasNoContent(htmlText: "<p>hi</p>", fileURL: nil))
        #expect(!HTMLPreviewView.hasNoContent(htmlText: "<p>hi</p>", fileURL: fileURL))
    }

    private func makeFileURL(fileName: String) -> URL {
        URL(fileURLWithPath: "/tmp/KitHTMLPreview Tests/Nested/\(fileName)")
    }
}
