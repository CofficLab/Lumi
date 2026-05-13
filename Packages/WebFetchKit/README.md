# WebFetchKit

Core web fetching and content extraction utilities for Lumi.

`WebFetchKit` contains the reusable logic behind the Web Fetch plugin. The app plugin should stay as a thin adapter around this package.

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

## Running Tests

From this package directory:

```sh
swift test
```

The test suite covers HTML conversion, malformed list handling, response formatting, redirects, caching, prompt extraction, and binary file output.

## App Integration

The Lumi Web Fetch plugin imports `WebFetchKit` and delegates execution to `WebFetchService`. Keep plugin-specific code, tool schemas, permissions, and MagicKit integration in the app target; keep fetching, formatting, caching, and conversion behavior in this package.
