import Foundation

public enum ResumeLintSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct ResumeLintIssue: Codable, Equatable, Sendable {
    public let severity: ResumeLintSeverity
    public let code: String
    public let message: String

    public init(severity: ResumeLintSeverity, code: String, message: String) {
        self.severity = severity
        self.code = code
        self.message = message
    }
}

public struct ResumeLintReport: Codable, Equatable, Sendable {
    public let issues: [ResumeLintIssue]
    public var errors: [ResumeLintIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [ResumeLintIssue] { issues.filter { $0.severity == .warning } }
    public var isValid: Bool { errors.isEmpty }

    public init(issues: [ResumeLintIssue]) {
        self.issues = issues
    }
}

/// 简历 HTML 静态校验器。
///
/// 在 promo 校验规则（禁脚本/iframe/远程资源/@import、大小上限、
/// 资产路径安全）之上，增加确定性分页约束：文档必须包含
/// `.resume-page` 容器，且 CSS 中必须声明其固定宽高。
/// 容器是否精确等于纸张尺寸、内容是否溢出由导出器的
/// 运行时测量兜底（见 `ResumeHTMLExporter.measurePages`）。
public struct ResumeHTMLLinter: Sendable {
    public let maximumUTF8Bytes: Int

    public init(maximumUTF8Bytes: Int = 2_000_000) {
        self.maximumUTF8Bytes = maximumUTF8Bytes
    }

    public func lint(html: String, paper: ResumePaperKind? = nil, documentDirectory: URL? = nil) -> ResumeLintReport {
        var issues: [ResumeLintIssue] = []
        let lower = html.lowercased()

        func add(_ severity: ResumeLintSeverity, _ code: String, _ message: String) {
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
            add(.error, "script_forbidden", "Scripts are not allowed in resumes.")
        }
        if lower.range(of: #"<\s*iframe\b"#, options: .regularExpression) != nil {
            add(.error, "iframe_forbidden", "Iframes are not allowed in resumes.")
        }
        if lower.range(of: #"https?://"#, options: .regularExpression) != nil || lower.contains("//cdn.") {
            add(.error, "remote_resource", "Remote resources are not allowed; import files into the resume assets directory.")
        }
        if lower.range(of: #"@import\s"#, options: .regularExpression) != nil {
            add(.error, "css_import_forbidden", "CSS @import is not allowed.")
        }
        if lower.range(of: #"(?:animation|transition)\s*:"#, options: .regularExpression) != nil {
            add(.warning, "motion_disabled", "Animations and transitions are disabled during export and should be removed.")
        }

        // 分页约束：至少一个 .resume-page 容器。
        if lower.range(of: #"class\s*=\s*["'][^"']*\bresume-page\b"#, options: .regularExpression) == nil {
            add(.error, "missing_resume_page", "HTML must contain at least one element with class \"resume-page\".")
        }
        // .resume-page 必须声明固定宽高（具体数值是否匹配纸张由导出器测量校验）。
        if let pageRuleRange = lower.range(of: #"\.resume-page\s*\{[^}]*\}"#, options: .regularExpression) {
            let rule = String(lower[pageRuleRange])
            if rule.range(of: #"width\s*:"#, options: .regularExpression) == nil
                || rule.range(of: #"height\s*:"#, options: .regularExpression) == nil {
                add(.error, "resume_page_missing_size", "The .resume-page CSS rule must declare fixed width and height matching the paper preset.")
            }
            if rule.range(of: #"overflow\s*:\s*hidden"#, options: .regularExpression) == nil {
                add(.warning, "overflow_not_hidden", "Set overflow: hidden on .resume-page to avoid accidental scrolling in exports.")
            }
        } else {
            add(.error, "resume_page_missing_size", "HTML must define a .resume-page CSS rule with fixed width and height.")
        }
        // 打印分页双保险。
        if lower.range(of: #"page-break-inside\s*:\s*avoid|break-inside\s*:\s*avoid"#, options: .regularExpression) == nil {
            add(.warning, "break_inside_missing", "Use break-inside: avoid on entries so content never splits across printed pages.")
        }
        if lower.range(of: #"background(?:-color)?\s*:"#, options: .regularExpression) == nil {
            add(.warning, "background_missing", "Declare an opaque page background so exports and prints have no transparent gaps.")
        }

        // 本地资产存在性与路径安全。
        for path in localResourcePaths(in: html) {
            guard !path.hasPrefix("data:") && !path.hasPrefix("#") else { continue }
            let decoded = path.removingPercentEncoding ?? path
            if decoded.hasPrefix("/") || decoded.contains("..") {
                add(.error, "unsafe_asset_path", "Asset path escapes the resume directory: \(path)")
                continue
            }
            if let documentDirectory {
                let url = documentDirectory.appendingPathComponent(decoded).standardizedFileURL
                let root = documentDirectory.standardizedFileURL.path
                guard url.path.hasPrefix(root + "/") else {
                    add(.error, "unsafe_asset_path", "Asset path escapes the resume directory: \(path)")
                    continue
                }
                if !FileManager.default.fileExists(atPath: url.path) {
                    add(.error, "missing_asset", "Referenced asset does not exist: \(path)")
                }
            }
        }

        return ResumeLintReport(issues: issues)
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
