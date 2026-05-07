import Foundation
import MagicKit

/// 网页抓取工具
///
/// 从指定 URL 抓取内容并转换为 Markdown 格式。
/// 支持处理 HTML、纯文本、JSON 等多种内容类型。
struct WebFetchTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false
    
    let name = "web_fetch"
    let description = """
Fetch and extract content from a URL. Converts HTML to Markdown format automatically.
Use this tool to retrieve web pages, documentation, or any publicly accessible HTTP content.

Note: This tool does NOT work with authenticated/private URLs (requires login, cookies, etc.).

Supported content types:
- HTML pages → converted to Markdown
- JSON → formatted as code block
- Plain text → returned directly
- Binary files (PDF, images) → returns file info and saves to temp directory
"""
    
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "The URL to fetch content from (must be a valid HTTP/HTTPS URL)"
                ],
                "prompt": [
                    "type": "string",
                    "description": "Optional: A prompt to process/extract specific information from the fetched content. If provided, the content will be summarized or filtered based on this prompt."
                ]
            ],
            "required": ["url"]
        ]
    }
    
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 网络请求风险较低，但需要用户确认 URL
        .medium
    }
    
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let urlString = arguments["url"]?.value as? String else {
            return "Error: Missing required 'url' parameter"
        }
        
        let prompt = arguments["prompt"]?.value as? String
        
        // 验证 URL
        guard let url = URL(string: urlString) else {
            return "Error: Invalid URL format: \(urlString)"
        }
        
        // 只支持 HTTP/HTTPS
        guard url.scheme == "http" || url.scheme == "https" else {
            return "Error: Only HTTP/HTTPS URLs are supported"
        }
        
        if Self.verbose {
            AppLogger.core.info("\(self.t)🌐 Fetching: \(urlString)")
        }
        
        // 检查缓存
        if let cached = Cache.shared.get(urlString) {
            if Self.verbose {
                AppLogger.core.info("\(self.t)📦 Using cached content")
            }
            return processCachedContent(cached, prompt: prompt)
        }
        
        // 发送请求
        let result = try await fetchURL(url, prompt: prompt)
        
        return result
    }
    
    // MARK: - Fetch Implementation
    
    private func fetchURL(_ url: URL, prompt: String?) async throws -> String {
        let startTime = Date()
        
        // 配置请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60 // 60 秒超时
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html, text/plain, application/json, */*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        // 不自动跟随重定向（手动处理）
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.httpMaximumConnectionsPerHost = 5
        let session = URLSession(configuration: sessionConfig, delegate: RedirectDelegate(), delegateQueue: nil)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            let duration = Date().timeIntervalSince(startTime) * 1000
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response type"
            }
            
            // 处理重定向
            if let redirectURL = httpResponse.value(forHTTPHeaderField: "Location"),
               (300..<400).contains(httpResponse.statusCode) {
                return handleRedirect(originalURL: url, redirectURL: redirectURL, statusCode: httpResponse.statusCode, prompt: prompt)
            }
            
            // 检查状态码
            guard (200..<300).contains(httpResponse.statusCode) else {
                return "Error: HTTP \(httpResponse.statusCode) - \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
            }
            
            // 获取内容类型
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "text/plain"
            let contentSize = data.count
            
            if Self.verbose {
                AppLogger.core.info("\(self.t)✅ Fetched \(contentSize) bytes in \(String(format: "%.0f", duration))ms")
                AppLogger.core.info("\(self.t)📄 Content-Type: \(contentType)")
            }
            
            // 处理内容
            let result = try processContent(
                data: data,
                contentType: contentType,
                url: url,
                statusCode: httpResponse.statusCode,
                duration: duration,
                prompt: prompt
            )
            
            // 缓存结果
            let cached = CachedContent(
                content: result,
                contentType: contentType,
                statusCode: httpResponse.statusCode,
                contentSize: contentSize,
                duration: duration,
                fetchedAt: startTime
            )
            Cache.shared.set(url.absoluteString, value: cached)
            
            return result
            
        } catch {
            if Self.verbose {
                AppLogger.core.error("\(self.t)❌ Fetch failed: \(error.localizedDescription)")
            }
            return "Error: Failed to fetch URL - \(error.localizedDescription)"
        }
    }
    
    // MARK: - Content Processing
    
    private func processContent(
        data: Data,
        contentType: String,
        url: URL,
        statusCode: Int,
        duration: Double,
        prompt: String?
    ) throws -> String {
        let mimeType = contentType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces) ?? "text/plain"
        
        // 根据内容类型处理
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
            // 尝试作为文本处理
            if let text = String(data: data, encoding: .utf8) {
                if text.contains("<html") || text.contains("<body") {
                    return processHTML(data: data, url: url, statusCode: statusCode, duration: duration, prompt: prompt)
                }
                return processPlainText(data: data, statusCode: statusCode, duration: duration)
            }
            return processBinary(data: data, contentType: mimeType, url: url, statusCode: statusCode, duration: duration)
        }
    }
    
    /// 处理 HTML 内容
    private func processHTML(
        data: Data,
        url: URL,
        statusCode: Int,
        duration: Double,
        prompt: String?
    ) -> String {
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return "Error: Could not decode HTML content"
        }
        
        // 转换为 Markdown
        let markdown = HTMLToMarkdownConverter.convert(html, baseURL: url)
        
        // 构建响应
        var result = """
## Web Fetch Result

**URL**: \(url.absoluteString)
**Status**: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))
**Duration**: \(String(format: "%.0f", duration))ms
**Size**: \(formatBytes(data.count))

---

"""
        
        // 如果有 prompt，尝试提取关键信息
        if let prompt = prompt, !prompt.isEmpty {
            result += "### Extracted Content (Prompt: \(prompt))\n\n"
            // 简单处理：搜索关键词或截取相关段落
            let extracted = extractWithPrompt(markdown: markdown, prompt: prompt)
            result += extracted
        } else {
            result += "### Content (Markdown)\n\n\(markdown)"
        }
        
        return result
    }
    
    /// 处理 JSON 内容
    private func processJSON(data: Data, statusCode: Int, duration: Double) -> String {
        var result = """
## Web Fetch Result

**Status**: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))
**Duration**: \(String(format: "%.0f", duration))ms
**Size**: \(formatBytes(data.count))
**Content-Type**: JSON

---

"""
        
        // 尝试美化 JSON
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
    
    /// 处理纯文本
    private func processPlainText(data: Data, statusCode: Int, duration: Double) -> String {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return "Error: Could not decode text content"
        }
        
        return """
## Web Fetch Result

**Status**: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))
**Duration**: \(String(format: "%.0f", duration))ms
**Size**: \(formatBytes(data.count))
**Content-Type**: Plain Text

---

\(text)
"""
    }
    
    /// 处理二进制文件
    private func processBinary(
        data: Data,
        contentType: String,
        url: URL,
        statusCode: Int,
        duration: Double
    ) -> String {
        // 保存到临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let filename = url.lastPathComponent.isEmpty ? "downloaded-file" : url.lastPathComponent
        let tempFile = tempDir.appendingPathComponent("webfetch-\(UUID().uuidString)-\(filename)")
        
        do {
            try data.write(to: tempFile)
            
            return """
## Web Fetch Result

**URL**: \(url.absoluteString)
**Status**: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))
**Duration**: \(String(format: "%.0f", duration))ms
**Size**: \(formatBytes(data.count))
**Content-Type**: \(contentType)

---

**Binary content saved to**: \(tempFile.path)

Note: This is a binary file and cannot be displayed as text. You can use the file path above to read it with appropriate tools.
"""
        } catch {
            return """
## Web Fetch Result

**URL**: \(url.absoluteString)
**Status**: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))
**Duration**: \(String(format: "%.0f", duration))ms
**Size**: \(formatBytes(data.count))
**Content-Type**: \(contentType)

---

**Binary content** - Unable to save to temporary directory: \(error.localizedDescription)
"""
        }
    }
    
    /// 处理图片
    private func processImage(
        data: Data,
        contentType: String,
        url: URL,
        statusCode: Int,
        duration: Double
    ) -> String {
        // 保存到临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let ext = contentType.split(separator: "/").last ?? "png"
        let tempFile = tempDir.appendingPathComponent("webfetch-\(UUID().uuidString).\(ext)")
        
        do {
            try data.write(to: tempFile)
            
            return """
## Web Fetch Result

**URL**: \(url.absoluteString)
**Status**: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))
**Duration**: \(String(format: "%.0f", duration))ms
**Size**: \(formatBytes(data.count))
**Content-Type**: \(contentType)

---

**Image saved to**: \(tempFile.path)

Note: This is an image file. The file has been saved to the path above.
"""
        } catch {
            return """
## Web Fetch Result

**URL**: \(url.absoluteString)
**Status**: \(statusCode)
**Size**: \(formatBytes(data.count))
**Content-Type**: \(contentType)

---

**Image content** - Unable to save: \(error.localizedDescription)
"""
        }
    }
    
    /// 处理重定向
    private func handleRedirect(
        originalURL: URL,
        redirectURL: String,
        statusCode: Int,
        prompt: String?
    ) -> String {
        // 解析重定向 URL
        let resolvedRedirectURL: URL
        if let absoluteRedirect = URL(string: redirectURL) {
            if redirectURL.hasPrefix("/") || redirectURL.hasPrefix("./") {
                // 相对路径，基于原始 URL 解析
                resolvedRedirectURL = URL(string: redirectURL, relativeTo: originalURL) ?? originalURL
            } else {
                resolvedRedirectURL = absoluteRedirect
            }
        } else {
            resolvedRedirectURL = originalURL
        }
        
        // 检查是否跨域
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
        
        if isCrossDomain {
            return """
## Redirect Detected

**Original URL**: \(originalURL.absoluteString)
**Redirect URL**: \(resolvedRedirectURL.absoluteString)
**Status**: \(statusCode) \(statusText)

---

⚠️ **Cross-domain redirect detected**

The URL redirects to a different domain. Please use `web_fetch` again with the new URL:
- url: "\(resolvedRedirectURL.absoluteString)"
\(prompt != nil ? "- prompt: \"\(prompt!)\"" : "")

"""
        } else {
            // 同域重定向，自动提示用户
            return """
## Redirect Detected

**Original URL**: \(originalURL.absoluteString)
**Redirect URL**: \(resolvedRedirectURL.absoluteString)
**Status**: \(statusCode) \(statusText)

---

The URL redirects within the same domain. Please use `web_fetch` again with the new URL:
- url: "\(resolvedRedirectURL.absoluteString)"
\(prompt != nil ? "- prompt: \"\(prompt!)\"" : "")

"""
        }
    }
    
    /// 根据 prompt 提取内容（简单实现）
    private func extractWithPrompt(markdown: String, prompt: String) -> String {
        // 简单的关键词匹配
        let keywords = prompt.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " ,.?!"))
            .filter { $0.count > 2 }
        
        // 搜索包含关键词的段落
        let paragraphs = markdown.components(separatedBy: "\n\n")
        var relevantParagraphs: [String] = []
        
        for paragraph in paragraphs {
            let lowerParagraph = paragraph.lowercased()
            for keyword in keywords {
                if lowerParagraph.contains(keyword) {
                    relevantParagraphs.append(paragraph)
                    break
                }
            }
        }
        
        if relevantParagraphs.isEmpty {
            // 没找到相关内容，返回前几个段落
            let firstParagraphs = paragraphs.prefix(5).joined(separator: "\n\n")
            return "\(firstParagraphs)\n\n[Note: No specific match found for prompt, showing first paragraphs]"
        }
        
        return relevantParagraphs.joined(separator: "\n\n")
    }
    
    /// 处理缓存内容
    private func processCachedContent(_ cached: CachedContent, prompt: String?) -> String {
        var result = """
## Web Fetch Result (Cached)

**Status**: \(cached.statusCode)
**Size**: \(formatBytes(cached.contentSize))
**Cached at**: \(formatDate(cached.fetchedAt))

---

"""
        
        if let prompt = prompt, !prompt.isEmpty {
            result += "### Extracted Content (Prompt: \(prompt))\n\n"
            let extracted = extractWithPrompt(markdown: cached.content, prompt: prompt)
            result += extracted
        } else {
            result += cached.content
        }
        
        return result
    }
    
    // MARK: - Helper Functions
    
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

// MARK: - Cache

/// 缓存管理
private final class Cache: @unchecked Sendable {
    static let shared = Cache()
    
    private var store: [String: CachedContent] = [:]
    private let lock = NSLock()
    private let maxEntries = 50
    private let ttl: TimeInterval = 15 * 60 // 15 分钟
    
    private init() {}
    
    func get(_ key: String) -> CachedContent? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let cached = store[key] else { return nil }
        
        // 检查 TTL
        if Date().timeIntervalSince(cached.fetchedAt) > ttl {
            store.removeValue(forKey: key)
            return nil
        }
        
        return cached
    }
    
    func set(_ key: String, value: CachedContent) {
        lock.lock()
        defer { lock.unlock() }
        
        // 清理过期缓存
        let now = Date()
        for (k, v) in store {
            if now.timeIntervalSince(v.fetchedAt) > ttl {
                store.removeValue(forKey: k)
            }
        }
        
        // 如果超过最大条目数，移除最旧的
        if store.count >= maxEntries {
            let oldest = store.min { $0.value.fetchedAt < $1.value.fetchedAt }
            if let oldestKey = oldest?.key {
                store.removeValue(forKey: oldestKey)
            }
        }
        
        store[key] = value
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
    }
}

/// 缓存内容结构
private struct CachedContent: Sendable {
    let content: String
    let contentType: String
    let statusCode: Int
    let contentSize: Int
    let duration: Double
    let fetchedAt: Date
}

/// 处理重定向的 URLSession 委托
private final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
    /// 不自动跟随重定向，返回给调用方处理
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        // 不跟随重定向，让工具自己处理
        completionHandler(.cancel)
    }
}