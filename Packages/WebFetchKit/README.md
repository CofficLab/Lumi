# WebFetchKit

可复用的网页抓取与内容提取工具包。提供 URL 校验、HTTP 抓取、HTML→Markdown 转换、响应格式化、缓存与段落提取等能力。

## Package

- Product: `WebFetchKit`
- Platform: macOS 14+
- Swift tools: 6.0

## Features

- Validates HTTP and HTTPS URLs.
- Fetches remote content through an injectable network client.
- Converts HTML and XHTML into Markdown.
- Formats JSON and plain text responses.
- Saves binary and image responses to a temporary directory.
- Handles redirects without automatically following them.
- Caches fetched responses with TTL and max-entry limits.
- Supports simple prompt-based paragraph extraction.

## Basic Usage

```swift
import WebFetchKit

let service = WebFetchService()
let result = await service.fetch(
    urlString: "https://example.com/docs",
    prompt: "installation"
)
```

For pure HTML conversion:

```swift
import WebFetchKit

let markdown = HTMLToMarkdownConverter.convert(
    html,
    baseURL: URL(string: "https://example.com")
)
```

## Testing With a Mock Fetcher

`WebFetchService` accepts any `WebFetchFetching` implementation, so tests do not need real network access.

```swift
struct MockFetcher: WebFetchFetching {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data = Data("<h1>Hello</h1>".utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html"]
        )!
        return (data, response)
    }
}

let service = WebFetchService(fetcher: MockFetcher(), cache: nil)
```

## Testing

From this package directory:

```sh
swift test
```

Tests cover HTML conversion, malformed list handling, response formatting, redirects, caching, prompt extraction, and binary file output.

## Host integration

Keep plugin-specific code, tool schemas, permissions, and logging integration in the host app; keep fetching, formatting, caching, and conversion in this package.
