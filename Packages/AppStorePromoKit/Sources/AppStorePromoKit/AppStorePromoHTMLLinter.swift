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

    public func lint(html: String, documentDirectory: URL? = nil) -> AppStorePromoLintReport {
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
        if lower.range(of: #"https?://"#, options: .regularExpression) != nil || lower.contains("//cdn.") {
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

        for path in localResourcePaths(in: html) {
            guard !path.hasPrefix("data:") && !path.hasPrefix("#") else { continue }
            let decoded = path.removingPercentEncoding ?? path
            if decoded.hasPrefix("/") || decoded.contains("..") {
                add(.error, "unsafe_asset_path", "Asset path escapes the page directory: \(path)")
                continue
            }
            if let documentDirectory {
                let url = documentDirectory.appendingPathComponent(decoded).standardizedFileURL
                let root = documentDirectory.standardizedFileURL.path
                guard url.path.hasPrefix(root + "/") else {
                    add(.error, "unsafe_asset_path", "Asset path escapes the page directory: \(path)")
                    continue
                }
                if !FileManager.default.fileExists(atPath: url.path) {
                    add(.error, "missing_asset", "Referenced asset does not exist: \(path)")
                }
            }
        }

        return AppStorePromoLintReport(issues: issues)
    }

    private func localResourcePaths(in html: String) -> [String] {
        let pattern = #"(?:src|href)\s*=\s*[\"']([^\"']+)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[valueRange])
        }
    }
}
