import Foundation

public enum AppStorePromoLintSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct AppStorePromoLintIssue: Codable, Equatable, Sendable {
    public let severity: AppStorePromoLintSeverity
    public let code: String
    public let message: String

    public init(severity: AppStorePromoLintSeverity, code: String, message: String) {
        self.severity = severity
        self.code = code
        self.message = message
    }
}

public struct AppStorePromoLintReport: Codable, Equatable, Sendable {
    public let issues: [AppStorePromoLintIssue]
    public var errors: [AppStorePromoLintIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [AppStorePromoLintIssue] { issues.filter { $0.severity == .warning } }
    public var isValid: Bool { errors.isEmpty }

    public init(issues: [AppStorePromoLintIssue]) {
        self.issues = issues
    }
}

public struct AppStorePromoHTMLLinter: Sendable {
    public let maximumUTF8Bytes: Int

    public init(maximumUTF8Bytes: Int = 1_000_000) {
        self.maximumUTF8Bytes = maximumUTF8Bytes
    }

    public func lint(html: String, documentDirectory: URL? = nil, htmlDirectory: URL? = nil) -> AppStorePromoLintReport {
        var issues: [AppStorePromoLintIssue] = []
        let lower = html.lowercased()

        func add(_ severity: AppStorePromoLintSeverity, _ code: String, _ message: String) {
            issues.append(.init(severity: severity, code: code, message: message))
        }

        if html.utf8.count > maximumUTF8Bytes {
            add(.error, "html_too_large", "HTML exceeds the \(maximumUTF8Bytes)-byte limit.")
        }
        if !lower.contains("<!doctype html") || !lower.contains("<html") || !lower.contains("</html>") {
            add(.error, "incomplete_document", "HTML must be a complete document with a doctype and html element.")
        }
        if !lower.contains("name=\"viewport\"") && !lower.contains("name='viewport'") {
            add(.error, "missing_viewport", "HTML must declare a viewport meta tag.")
        }
        if lower.range(of: #"<\s*script\b"#, options: .regularExpression) != nil {
            add(.error, "script_forbidden", "Scripts are not allowed in promotional artwork.")
        }
        if lower.range(of: #"<\s*iframe\b"#, options: .regularExpression) != nil {
            add(.error, "iframe_forbidden", "Iframes are not allowed in promotional artwork.")
        }
        // 只检查真正会触发资源加载的位置。整份文档扫描会把 inline SVG 必需的
        // xmlns="http://www.w3.org/2000/svg" 误判成网络依赖（issue #1010）。
        if !remoteResourceReferences(in: html).isEmpty {
            add(.error, "remote_resource", "Remote resources are not allowed; import files into the page assets directory.")
        }
        if lower.range(of: #"@import\s"#, options: .regularExpression) != nil {
            add(.error, "css_import_forbidden", "CSS @import is not allowed.")
        }
        if lower.range(of: #"(?:animation|transition)\s*:"#, options: .regularExpression) != nil {
            add(.warning, "motion_disabled", "Animations and transitions are disabled during export and should be removed.")
        }
        if lower.range(of: #"overflow\s*:\s*hidden"#, options: .regularExpression) == nil {
            add(.warning, "overflow_not_hidden", "Set overflow: hidden to avoid accidental scrolling in exports.")
        }
        if lower.range(of: #"background(?:-color)?\s*:"#, options: .regularExpression) == nil {
            add(.warning, "background_missing", "Declare an opaque page background for App Store exports.")
        }

        // 本地化 HTML 位于 localizations/ 子目录，相对路径要按它自身所在目录解析；
        // 只要最终目标仍在图片根目录内就是安全的（本地化用 ../assets/ 共享素材）。
        let baseDirectory = htmlDirectory ?? documentDirectory
        for path in localResourcePaths(in: html) {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            // 远程地址由 remote_resource 报错，这里只校验本地文件。
            guard !trimmed.hasPrefix("data:"),
                  !trimmed.hasPrefix("#"),
                  !Self.isRemoteURL(trimmed) else { continue }
            let decoded = trimmed.removingPercentEncoding ?? trimmed
            if decoded.hasPrefix("/") {
                add(.error, "unsafe_asset_path", "Asset path escapes the page directory: \(trimmed)")
                continue
            }
            if let documentDirectory, let baseDirectory {
                let url = baseDirectory.appendingPathComponent(decoded).standardizedFileURL
                let root = documentDirectory.standardizedFileURL.path
                guard url.path.hasPrefix(root + "/") else {
                    add(.error, "unsafe_asset_path", "Asset path escapes the page directory: \(path)")
                    continue
                }
                if !FileManager.default.fileExists(atPath: url.path) {
                    add(.error, "missing_asset", "Referenced asset does not exist: \(path)")
                }
            } else if decoded.contains("..") {
                add(.error, "unsafe_asset_path", "Asset path escapes the page directory: \(path)")
            }
        }

        return AppStorePromoLintReport(issues: issues)
    }

    private func remoteResourceReferences(in html: String) -> [String] {
        var candidates: [String] = []
        candidates += captureValues(#"\b(?:src|poster|data)\s*=\s*["']([^"']+)["']"#, in: html)
        candidates += captureValues(#"\bsrcset\s*=\s*["']([^"']+)["']"#, in: html)
        candidates += captureValues(#"<(?:link|image|use)\b[^>]*?\bhref\s*=\s*["']([^"']+)["']"#, in: html)
        candidates += captureValues(#"url\(\s*["']?([^"')]+)["']?\s*\)"#, in: html)
        return candidates.filter(Self.isRemoteURL)
    }

    private static func isRemoteURL(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.contains("http://") || lower.contains("https://") || lower.contains("//cdn.")
    }

    private func captureValues(_ pattern: String, in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[valueRange])
        }
    }

    private func localResourcePaths(in html: String) -> [String] {
        // CSS `url(...)` 不在 src/href 里，但它与属性一样会加载资源；
        // 漏掉它会让缺背景图的文档通过 lint。
        captureValues(#"(?:src|href)\s*=\s*["']([^"']+)["']"#, in: html)
            + captureValues(#"url\(\s*["']?([^"')]+?)["']?\s*\)"#, in: html)
    }
}
