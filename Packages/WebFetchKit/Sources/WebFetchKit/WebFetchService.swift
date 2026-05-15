@preconcurrency import Foundation

public protocol WebFetchFetching: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionWebFetchFetcher: WebFetchFetching {
    private let session: URLSession

    public init() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.httpMaximumConnectionsPerHost = 5
        self.session = URLSession(configuration: sessionConfig, delegate: RedirectDelegate(), delegateQueue: nil)
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebFetchError.invalidResponseType
        }
        return (data, httpResponse)
    }
}

public enum WebFetchError: LocalizedError, Equatable {
    case missingURL
    case invalidURL(String)
    case unsupportedScheme(String?)
    case invalidResponseType

    public var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Missing required 'url' parameter"
        case .invalidURL(let urlString):
            return "Invalid URL format: \(urlString)"
        case .unsupportedScheme:
            return "Only HTTP/HTTPS URLs are supported"
        case .invalidResponseType:
            return "Invalid response type"
        }
    }
}

public struct WebFetchService: Sendable {
    private let fetcher: any WebFetchFetching
    private let cache: WebFetchCache?
    private let tempDirectory: URL
    private let now: @Sendable () -> Date

    public init(
        fetcher: any WebFetchFetching = URLSessionWebFetchFetcher(),
        cache: WebFetchCache? = .shared,
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.tempDirectory = tempDirectory
        self.now = now
    }

    public func fetch(urlString: String, prompt: String? = nil) async -> String {
        do {
            guard !urlString.isEmpty else {
                throw WebFetchError.missingURL
            }
            guard let url = URL(string: urlString) else {
                throw WebFetchError.invalidURL(urlString)
            }
            guard url.scheme == "http" || url.scheme == "https" else {
                throw WebFetchError.unsupportedScheme(url.scheme)
            }

            if let cached = cache?.get(urlString, now: now()) {
                return processCachedContent(cached, prompt: prompt)
            }

            return try await fetchURL(url, prompt: prompt)
        } catch let error as WebFetchError {
            return "Error: \(error.localizedDescription)"
        } catch {
            return "Error: Failed to fetch URL - \(error.localizedDescription)"
        }
    }

    public func processContent(
        data: Data,
        contentType: String,
        url: URL,
        statusCode: Int,
        duration: Double,
        prompt: String? = nil
    ) -> String {
        let mimeType = contentType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces) ?? "text/plain"

        switch mimeType {
        case "text/html", "application/xhtml+xml":
            return processHTML(data: data, url: url, statusCode: statusCode, duration: duration, prompt: prompt)
        case "application/json":
            return processJSON(data: data, statusCode: statusCode, duration: duration)
        case "text/plain", "text/markdown":
            return processPlainText(data: data, statusCode: statusCode, duration: duration)
        case "application/pdf":
            return processBinary(data: data, contentType: mimeType, url: url, statusCode: statusCode, duration: duration)
        case "image/jpeg", "image/png", "image/gif", "image/webp":
            return processImage(data: data, contentType: mimeType, url: url, statusCode: statusCode, duration: duration)
        default:
            if let text = String(data: data, encoding: .utf8) {
                if text.contains("<html") || text.contains("<body") {
                    return processHTML(data: data, url: url, statusCode: statusCode, duration: duration, prompt: prompt)
                }
                return processPlainText(data: data, statusCode: statusCode, duration: duration)
            }
            return processBinary(data: data, contentType: mimeType, url: url, statusCode: statusCode, duration: duration)
        }
    }

    public func handleRedirect(
        originalURL: URL,
        redirectURL: String,
        statusCode: Int,
        prompt: String? = nil
    ) -> String {
        let resolvedRedirectURL: URL
        if let absoluteRedirect = URL(string: redirectURL) {
            if redirectURL.hasPrefix("/") || redirectURL.hasPrefix("./") {
                resolvedRedirectURL = URL(string: redirectURL, relativeTo: originalURL) ?? originalURL
            } else {
                resolvedRedirectURL = absoluteRedirect
            }
        } else {
            resolvedRedirectURL = originalURL
        }

        let isCrossDomain = originalURL.host != resolvedRedirectURL.host
        let statusText: String
        switch statusCode {
        case 301: statusText = "Moved Permanently"
        case 302: statusText = "Found"
        case 303: statusText = "See Other"
        case 307: statusText = "Temporary Redirect"
        case 308: statusText = "Permanent Redirect"
        default: statusText = "Redirect"
        }

        let redirectKind = isCrossDomain
            ? "⚠️ **Cross-domain redirect detected**\n\nThe URL redirects to a different domain."
            : "The URL redirects within the same domain."

        return """
## Redirect Detected

**Original URL**: \(originalURL.absoluteString)
**Redirect URL**: \(resolvedRedirectURL.absoluteString)
**Status**: \(statusCode) \(statusText)

---

\(redirectKind) Please use `web_fetch` again with the new URL:
- url: "\(resolvedRedirectURL.absoluteString)"
\(prompt != nil ? "- prompt: \"\(prompt!)\"" : "")

"""
    }

    public func extractWithPrompt(markdown: String, prompt: String) -> String {
        let keywords = prompt.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " ,.?!"))
            .filter { $0.count > 2 }

        let paragraphs = markdown.components(separatedBy: "\n\n")
        var relevantParagraphs: [String] = []

        for paragraph in paragraphs {
            let lowerParagraph = paragraph.lowercased()
            for keyword in keywords where lowerParagraph.contains(keyword) {
                relevantParagraphs.append(paragraph)
                break
            }
        }

        if relevantParagraphs.isEmpty {
            let firstParagraphs = paragraphs.prefix(5).joined(separator: "\n\n")
            return "\(firstParagraphs)\n\n[Note: No specific match found for prompt, showing first paragraphs]"
        }

        return relevantParagraphs.joined(separator: "\n\n")
    }

    private func fetchURL(_ url: URL, prompt: String?) async throws -> String {
        let startTime = now()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html, text/plain, application/json, */*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        let (data, httpResponse) = try await fetcher.data(for: request)
        let duration = now().timeIntervalSince(startTime) * 1000

        if let redirectURL = httpResponse.value(forHTTPHeaderField: "Location"),
           (300..<400).contains(httpResponse.statusCode) {
            return handleRedirect(
                originalURL: url,
                redirectURL: redirectURL,
                statusCode: httpResponse.statusCode,
                prompt: prompt
            )
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            return "Error: HTTP \(httpResponse.statusCode) - \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "text/plain"
        let result = processContent(
            data: data,
            contentType: contentType,
            url: url,
            statusCode: httpResponse.statusCode,
            duration: duration,
            prompt: prompt
        )

        cache?.set(
            url.absoluteString,
            value: CachedContent(
                content: result,
                contentType: contentType,
                statusCode: httpResponse.statusCode,
                contentSize: data.count,
                duration: duration,
                fetchedAt: startTime
            ),
            now: now()
        )

        return result
    }

    private func processHTML(data: Data, url: URL, statusCode: Int, duration: Double, prompt: String?) -> String {
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return "Error: Could not decode HTML content"
        }

        let markdown = HTMLToMarkdownConverter.convert(html, baseURL: url)
        var result = fetchHeader(
            url: url,
            statusCode: statusCode,
            duration: duration,
            size: data.count
        )

        if let prompt, !prompt.isEmpty {
            result += "### Extracted Content (Prompt: \(prompt))\n\n"
            result += extractWithPrompt(markdown: markdown, prompt: prompt)
        } else {
            result += "### Content (Markdown)\n\n\(markdown)"
        }

        return result
    }

    private func processJSON(data: Data, statusCode: Int, duration: Double) -> String {
        var result = fetchHeader(
            statusCode: statusCode,
            duration: duration,
            size: data.count,
            contentType: "JSON"
        )

        do {
            let json = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            let prettyString = String(data: prettyData, encoding: .utf8) ?? "Unable to format JSON"
            result += "```json\n\(prettyString)\n```"
        } catch {
            let rawString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            result += "```json\n\(rawString)\n```\n\n(Note: Invalid JSON format)"
        }

        return result
    }

    private func processPlainText(data: Data, statusCode: Int, duration: Double) -> String {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return "Error: Could not decode text content"
        }

        return fetchHeader(
            statusCode: statusCode,
            duration: duration,
            size: data.count,
            contentType: "Plain Text"
        ) + text + "\n"
    }

    private func processBinary(data: Data, contentType: String, url: URL, statusCode: Int, duration: Double) -> String {
        let filename = url.lastPathComponent.isEmpty ? "downloaded-file" : url.lastPathComponent
        let tempFile = tempDirectory.appendingPathComponent("webfetch-\(UUID().uuidString)-\(filename)")

        do {
            try data.write(to: tempFile)
            return fetchHeader(
                url: url,
                statusCode: statusCode,
                duration: duration,
                size: data.count,
                contentType: contentType
            ) + """
**Binary content saved to**: \(tempFile.path)

Note: This is a binary file and cannot be displayed as text. You can use the file path above to read it with appropriate tools.
"""
        } catch {
            return fetchHeader(
                url: url,
                statusCode: statusCode,
                duration: duration,
                size: data.count,
                contentType: contentType
            ) + "**Binary content** - Unable to save to temporary directory: \(error.localizedDescription)\n"
        }
    }

    private func processImage(data: Data, contentType: String, url: URL, statusCode: Int, duration: Double) -> String {
        let ext = contentType.split(separator: "/").last ?? "png"
        let tempFile = tempDirectory.appendingPathComponent("webfetch-\(UUID().uuidString).\(ext)")

        do {
            try data.write(to: tempFile)
            return fetchHeader(
                url: url,
                statusCode: statusCode,
                duration: duration,
                size: data.count,
                contentType: contentType
            ) + """
**Image saved to**: \(tempFile.path)

Note: This is an image file. The file has been saved to the path above.
"""
        } catch {
            return fetchHeader(
                url: url,
                statusCode: statusCode,
                duration: duration,
                size: data.count,
                contentType: contentType
            ) + "**Image content** - Unable to save: \(error.localizedDescription)\n"
        }
    }

    private func processCachedContent(_ cached: CachedContent, prompt: String?) -> String {
        var result = """
## Web Fetch Result (Cached)

**Status**: \(cached.statusCode)
**Size**: \(formatBytes(cached.contentSize))
**Cached at**: \(formatDate(cached.fetchedAt))

---

"""

        if let prompt, !prompt.isEmpty {
            result += "### Extracted Content (Prompt: \(prompt))\n\n"
            result += extractWithPrompt(markdown: cached.content, prompt: prompt)
        } else {
            result += cached.content
        }

        return result
    }

    private func fetchHeader(
        url: URL? = nil,
        statusCode: Int,
        duration: Double,
        size: Int,
        contentType: String? = nil
    ) -> String {
        var lines = ["## Web Fetch Result", ""]
        if let url {
            lines.append("**URL**: \(url.absoluteString)")
        }
        lines.append("**Status**: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))")
        lines.append("**Duration**: \(String(format: "%.0f", duration))ms")
        lines.append("**Size**: \(formatBytes(size))")
        if let contentType {
            lines.append("**Content-Type**: \(contentType)")
        }
        lines.append("")
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

private final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
