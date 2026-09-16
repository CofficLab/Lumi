import Foundation
import Testing
@testable import PluginWebFetch

@Suite("Web fetch service")
struct WebFetchServiceTests {
    @Test("rejects empty, malformed, and non-HTTP URLs without a request")
    func validatesURLsBeforeFetching() async {
        let requests = RequestCounter()
        let service = WebFetchService(fetcher: StubFetcher(data: Data(), counter: requests), cache: nil)

        #expect(await service.fetch(urlString: "  ") == "Error: Missing required 'url' parameter")
        #expect(await service.fetch(urlString: "http://[") == "Error: Invalid URL format: http://[")
        #expect(await service.fetch(urlString: "file:///tmp/page.html") == "Error: Only HTTP/HTTPS URLs are supported")
        #expect(await requests.count() == 0)
    }

    @Test("fetches and caches a successful response")
    func fetchesResponseOnceAndServesItFromCache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let requests = RequestCounter()
        let html = Data("<h1>Documentation</h1><p>Install the package.</p>".utf8)
        let fetcher = StubFetcher(
            data: html,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            counter: requests
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let service = WebFetchService(
            fetcher: fetcher,
            cache: WebFetchCache(),
            tempDirectory: root,
            now: { now }
        )

        let first = await service.fetch(urlString: "https://example.com/docs")
        let second = await service.fetch(urlString: "https://example.com/docs")

        #expect(first.contains("# Documentation"))
        #expect(first.contains("Install the package."))
        #expect(second.contains("Web Fetch Result (Cached)"))
        #expect(second.contains("# Documentation"))
        #expect(await requests.count() == 1)
    }

    @Test("does not cache HTTP errors")
    func retriesFailedHTTPResponses() async {
        let requests = RequestCounter()
        let service = WebFetchService(
            fetcher: StubFetcher(data: Data("busy".utf8), statusCode: 503, counter: requests),
            cache: WebFetchCache()
        )

        let first = await service.fetch(urlString: "https://example.com/unavailable")
        let second = await service.fetch(urlString: "https://example.com/unavailable")

        #expect(first.contains("Error: HTTP 503"))
        #expect(second.contains("Error: HTTP 503"))
        #expect(await requests.count() == 2)
    }

    @Test("resolves redirects and rejects redirect targets with unsafe schemes")
    func handlesRedirectTargets() {
        let service = WebFetchService(fetcher: StubFetcher(data: Data(), counter: RequestCounter()), cache: nil)
        let original = URL(string: "https://example.com/docs/start")!

        let redirect = service.handleRedirect(
            originalURL: original,
            redirectURL: "//cdn.example.com/guide",
            statusCode: 302,
            prompt: "find setup"
        )
        #expect(redirect.contains("https://cdn.example.com/guide"))
        #expect(redirect.contains("Found"))
        #expect(redirect.contains("- prompt: \"find setup\""))

        let blocked = service.handleRedirect(
            originalURL: original,
            redirectURL: "file:///etc/passwd",
            statusCode: 301
        )
        #expect(blocked.contains("Error: Redirect target uses an unsupported URL scheme"))
    }

    @Test("extracts matching English and Chinese paragraphs and explains a miss")
    func extractsPromptMatches() {
        let service = WebFetchService(fetcher: StubFetcher(data: Data(), counter: RequestCounter()), cache: nil)
        let markdown = "Overview of the product.\n\nInstall the package with the command line.\n\n本页面介绍安装配置和常见问题。"

        #expect(service.extractWithPrompt(markdown: markdown, prompt: "install") == "Install the package with the command line.")
        #expect(service.extractWithPrompt(markdown: markdown, prompt: "安装配置") == "本页面介绍安装配置和常见问题。")
        #expect(service.extractWithPrompt(markdown: markdown, prompt: "no-match").contains("No specific match found"))
    }

    @Test("formats valid JSON and reports invalid JSON without losing its body")
    func formatsJSONResponses() {
        let service = WebFetchService(fetcher: StubFetcher(data: Data(), counter: RequestCounter()), cache: nil)
        let valid = service.processContent(
            data: Data(#"{"z":1,"a":2}"#.utf8),
            contentType: "application/json; charset=utf-8",
            url: URL(string: "https://example.com/data.json")!,
            statusCode: 200,
            duration: 1
        )
        let invalid = service.processContent(
            data: Data("{invalid".utf8),
            contentType: "application/json",
            url: URL(string: "https://example.com/data.json")!,
            statusCode: 200,
            duration: 1
        )

        #expect(valid.contains("```json"))
        #expect(valid.range(of: "\"a\"")!.lowerBound < valid.range(of: "\"z\"")!.lowerBound)
        #expect(invalid.contains("{invalid"))
        #expect(invalid.contains("Invalid JSON format"))
    }

    @Test("routes plain text, sniffed HTML, and undecodable text")
    func processesTextContentTypes() {
        let service = WebFetchService(fetcher: StubFetcher(data: Data(), counter: RequestCounter()), cache: nil)
        let url = URL(string: "https://example.com/content")!

        let plainText = service.processContent(
            data: Data("plain body".utf8),
            contentType: "text/plain; charset=utf-8",
            url: url,
            statusCode: 200,
            duration: 1
        )
        let sniffedHTML = service.processContent(
            data: Data("<html><body><p>sniffed body</p></body></html>".utf8),
            contentType: "application/x-custom",
            url: url,
            statusCode: 200,
            duration: 1
        )
        let invalidText = service.processContent(
            data: Data([0xFF]),
            contentType: "text/plain",
            url: url,
            statusCode: 200,
            duration: 1
        )

        #expect(plainText.contains("Content-Type**: Plain Text"))
        #expect(plainText.contains("plain body"))
        #expect(sniffedHTML.contains("sniffed body"))
        #expect(invalidText == "Error: Could not decode text content")
    }

    @Test("saves binary and image responses under the supplied temporary directory")
    func savesDownloadedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let service = WebFetchService(fetcher: StubFetcher(data: Data(), counter: RequestCounter()), cache: nil, tempDirectory: root)
        let url = URL(string: "https://example.com/report.pdf")!
        let pdfData = Data([0x25, 0x50, 0x44, 0x46])
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])

        let binaryResult = service.processContent(
            data: pdfData,
            contentType: "application/pdf",
            url: url,
            statusCode: 200,
            duration: 1
        )
        let imageResult = service.processContent(
            data: imageData,
            contentType: "image/png",
            url: url,
            statusCode: 200,
            duration: 1
        )

        #expect(binaryResult.contains("Binary content saved to"))
        #expect(imageResult.contains("Image saved to"))
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        #expect(try Data(contentsOf: files.first { $0.pathExtension == "pdf" }!) == pdfData)
        #expect(try Data(contentsOf: files.first { $0.pathExtension == "png" }!) == imageData)
    }
}

private struct StubFetcher: WebFetchFetching {
    let data: Data
    var statusCode = 200
    var headers: [String: String] = ["Content-Type": "text/plain"]
    let counter: RequestCounter

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        await counter.record()
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (data, response)
    }
}

private actor RequestCounter {
    private var requests = 0

    func record() {
        requests += 1
    }

    func count() -> Int {
        requests
    }
}
