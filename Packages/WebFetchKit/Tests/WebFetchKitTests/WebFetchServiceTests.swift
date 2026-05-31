import Foundation
import XCTest
@testable import WebFetchKit

final class WebFetchServiceTests: XCTestCase {
    func testFetchRejectsUnsupportedSchemes() async {
        let service = WebFetchService(fetcher: MockFetcher())

        let result = await service.fetch(urlString: "file:///tmp/example.html")

        XCTAssertEqual(result, "Error: Only HTTP/HTTPS URLs are supported")
    }

    func testFetchProcessesHTMLAndCachesResult() async {
        let fetcher = MockFetcher(
            data: Data("<html><body><h1>Hello</h1><p>World</p></body></html>".utf8),
            statusCode: 200,
            headers: ["Content-Type": "text/html; charset=utf-8"]
        )
        let cache = WebFetchCache(maxEntries: 10, ttl: 60)
        let date = Date(timeIntervalSince1970: 100)
        let service = WebFetchService(fetcher: fetcher, cache: cache, now: { date })

        let first = await service.fetch(urlString: "https://example.com/page")
        let second = await service.fetch(urlString: "https://example.com/page")

        XCTAssertTrue(first.contains("### Content (Markdown)"))
        XCTAssertTrue(first.contains("# Hello"))
        XCTAssertTrue(second.contains("## Web Fetch Result (Cached)"))
        XCTAssertTrue(second.contains("**Status**: 200"))
        XCTAssertTrue(second.contains("**Cached at**:"))
        XCTAssertTrue(second.contains(first))
        let requestCount = await fetcher.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testFetchTrimsCopiedURLWhitespace() async {
        let fetcher = MockFetcher(
            data: Data("<html><body><h1>Hello</h1></body></html>".utf8),
            statusCode: 200,
            headers: ["Content-Type": "text/html"]
        )
        let service = WebFetchService(fetcher: fetcher, cache: nil)

        let result = await service.fetch(urlString: " \nhttps://example.com/page\t")

        XCTAssertTrue(result.contains("**URL**: https://example.com/page"))
        let requestedURL = await fetcher.lastRequestURL
        XCTAssertEqual(requestedURL?.absoluteString, "https://example.com/page")
    }

    func testFetchReturnsRedirectInstruction() async {
        let fetcher = MockFetcher(
            data: Data(),
            statusCode: 302,
            headers: [
                "Location": "https://other.example/new",
                "Content-Type": "text/plain"
            ]
        )
        let service = WebFetchService(fetcher: fetcher, cache: nil)

        let result = await service.fetch(urlString: "https://example.com/old", prompt: "release notes")

        XCTAssertTrue(result.contains("## Redirect Detected"))
        XCTAssertTrue(result.contains("**Redirect URL**: https://other.example/new"))
        XCTAssertTrue(result.contains("Cross-domain redirect detected"))
        XCTAssertTrue(result.contains("- prompt: \"release notes\""))
    }

    func testProcessJSONPrettyPrintsValidJSON() {
        let service = WebFetchService(fetcher: MockFetcher(), cache: nil)

        let result = service.processContent(
            data: Data(#"{"b":2,"a":1}"#.utf8),
            contentType: "application/json",
            url: URL(string: "https://example.com/data")!,
            statusCode: 200,
            duration: 12.4
        )

        XCTAssertTrue(result.contains("**Content-Type**: JSON"))
        XCTAssertTrue(result.contains("\"a\" : 1"))
        XCTAssertTrue(result.contains("\"b\" : 2"))
    }

    func testInvalidJSONFallsBackToRawPayload() {
        let service = WebFetchService(fetcher: MockFetcher(), cache: nil)

        let result = service.processContent(
            data: Data(#"{invalid"#.utf8),
            contentType: "application/json",
            url: URL(string: "https://example.com/data")!,
            statusCode: 200,
            duration: 1
        )

        XCTAssertTrue(result.contains("```json\n{invalid\n```"))
        XCTAssertTrue(result.contains("(Note: Invalid JSON format)"))
    }

    func testContentTypeMatchingIsCaseInsensitive() {
        let service = WebFetchService(fetcher: MockFetcher(), cache: nil)

        let htmlResult = service.processContent(
            data: Data("<html><body><h1>Hello</h1></body></html>".utf8),
            contentType: "Text/HTML; Charset=UTF-8",
            url: URL(string: "https://example.com/page")!,
            statusCode: 200,
            duration: 1
        )
        let jsonResult = service.processContent(
            data: Data(#"{"ok":true}"#.utf8),
            contentType: "Application/JSON",
            url: URL(string: "https://example.com/data")!,
            statusCode: 200,
            duration: 1
        )

        XCTAssertTrue(htmlResult.contains("### Content (Markdown)"))
        XCTAssertTrue(htmlResult.contains("# Hello"))
        XCTAssertTrue(jsonResult.contains("**Content-Type**: JSON"))
        XCTAssertTrue(jsonResult.contains("\"ok\" : true"))
    }

    func testPromptExtractionReturnsMatchingParagraphsOnly() {
        let service = WebFetchService(fetcher: MockFetcher(), cache: nil)
        let markdown = """
        Intro paragraph.

        Install the package with SwiftPM.

        Runtime configuration details.
        """

        let result = service.extractWithPrompt(markdown: markdown, prompt: "package")

        XCTAssertEqual(result, "Install the package with SwiftPM.")
    }

    func testPromptExtractionMatchesChineseKeywordsSeparatedByChinesePunctuation() {
        let service = WebFetchService(fetcher: MockFetcher(), cache: nil)
        let markdown = """
        概览说明。

        安装插件后打开设置页面。

        运行时配置位于偏好设置。
        """

        let result = service.extractWithPrompt(markdown: markdown, prompt: "安装，配置")

        XCTAssertEqual(result, "安装插件后打开设置页面。\n\n运行时配置位于偏好设置。")
    }

    func testBinaryContentIsSavedToConfiguredDirectory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebFetchServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let service = WebFetchService(fetcher: MockFetcher(), cache: nil, tempDirectory: tempDirectory)

        let result = service.processContent(
            data: Data([0, 1, 2]),
            contentType: "application/pdf",
            url: URL(string: "https://example.com/file.pdf")!,
            statusCode: 200,
            duration: 5
        )

        XCTAssertTrue(result.contains("**Binary content saved to**: \(tempDirectory.path)/webfetch-"))
        XCTAssertTrue(result.contains("-file.pdf"))
        let savedFiles = try FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)
        XCTAssertEqual(savedFiles.count, 1)
    }

    func testRelativeSameDomainRedirectIsResolvedAgainstOriginalURL() {
        let service = WebFetchService(fetcher: MockFetcher(), cache: nil)

        let result = service.handleRedirect(
            originalURL: URL(string: "https://example.com/docs/old")!,
            redirectURL: "/docs/new",
            statusCode: 301
        )

        XCTAssertTrue(result.contains("**Redirect URL**: https://example.com/docs/new"))
        XCTAssertTrue(result.contains("redirects within the same domain"))
    }

    func testPathRelativeSameDomainRedirectIsResolvedAgainstOriginalDirectory() {
        let service = WebFetchService(fetcher: MockFetcher(), cache: nil)

        let result = service.handleRedirect(
            originalURL: URL(string: "https://example.com/docs/old")!,
            redirectURL: "new",
            statusCode: 302
        )

        XCTAssertTrue(result.contains("**Redirect URL**: https://example.com/docs/new"))
        XCTAssertTrue(result.contains("redirects within the same domain"))
        XCTAssertFalse(result.contains("Cross-domain redirect detected"))
    }

    func testCacheExpiresAndEvictsOldestEntry() {
        let cache = WebFetchCache(maxEntries: 1, ttl: 10)
        let first = CachedContent(
            content: "first",
            contentType: "text/plain",
            statusCode: 200,
            contentSize: 5,
            duration: 1,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let second = CachedContent(
            content: "second",
            contentType: "text/plain",
            statusCode: 200,
            contentSize: 6,
            duration: 1,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )

        cache.set("first", value: first, now: Date(timeIntervalSince1970: 0))
        cache.set("second", value: second, now: Date(timeIntervalSince1970: 1))

        XCTAssertNil(cache.get("first", now: Date(timeIntervalSince1970: 1)))
        XCTAssertEqual(cache.get("second", now: Date(timeIntervalSince1970: 1))?.content, "second")
        XCTAssertNil(cache.get("second", now: Date(timeIntervalSince1970: 20)))
    }
}

private actor MockFetcher: WebFetchFetching {
    private let data: Data
    private let statusCode: Int
    private let headers: [String: String]
    private var requests: [URLRequest] = []

    init(
        data: Data = Data(),
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }

    var requestCount: Int {
        requests.count
    }

    var lastRequestURL: URL? {
        requests.last?.url
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (data, response)
    }
}
