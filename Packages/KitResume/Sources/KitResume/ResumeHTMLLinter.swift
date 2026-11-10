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
        if containsRemoteResourceReference(in: html) {
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

        // 本地资产存在性与路径安全（含 CSS `url(...)` 引用的背景/字体）。
        for path in localResourcePaths(in: html) {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasPrefix("data:"), !trimmed.hasPrefix("#"), !Self.isRemoteURL(trimmed) else { continue }
            let decoded = trimmed.removingPercentEncoding ?? trimmed
            if decoded.hasPrefix("/") || decoded.contains("..") {
                add(.error, "unsafe_asset_path", "Asset path escapes the resume directory: \(trimmed)")
                continue
            }
            if let documentDirectory {
                let url = documentDirectory.appendingPathComponent(decoded).standardizedFileURL
                let root = documentDirectory.standardizedFileURL.path
                guard url.path.hasPrefix(root + "/") else {
                    add(.error, "unsafe_asset_path", "Asset path escapes the resume directory: \(trimmed)")
                    continue
                }
                if !FileManager.default.fileExists(atPath: url.path) {
                    add(.error, "missing_asset", "Referenced asset does not exist: \(trimmed)")
                }
            }
        }

        return ResumeLintReport(issues: issues)
    }

    private func localResourcePaths(in html: String) -> [String] {
        let attributePattern = #"(?:src|href)\s*=\s*[\"']([^\"']+)[\"']"#
        // CSS `url(...)` 同样会加载本地资源；背景图缺失不能让导出静默成功。
        let cssURLPattern = #"url\(\s*[\"']?([^\"')]+?)[\"']?\s*\)"#
        return capturedValues(matching: attributePattern, in: html)
            + capturedValues(matching: cssURLPattern, in: html)
    }

    /// 只检查真正会加载资源的位置：资源属性、`srcset` 候选与 CSS `url(...)`。
    ///
    /// `xmlns="http://www.w3.org/2000/svg"` 这类命名空间标识不会触发网络
    /// 请求，普通文本里的 URL 也不构成远程资源，都不能按“出现 http://
    /// 就报错”处理。
    private func containsRemoteResourceReference(in html: String) -> Bool {
        let attributePattern = #"(?:\bsrc|\bhref|\bposter|\bdata)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#
        for value in capturedValues(matching: attributePattern, in: html) where Self.isRemoteURL(value) {
            return true
        }

        // srcset 是逗号分隔的候选列表，每个候选以 URL 开头。
        let srcsetPattern = #"\bsrcset\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#
        for value in capturedValues(matching: srcsetPattern, in: html) {
            for candidate in value.split(separator: ",") {
                if let url = candidate.split(whereSeparator: \.isWhitespace).first,
                   Self.isRemoteURL(String(url)) {
                    return true
                }
            }
        }

        let urlPattern = #"url\(\s*([^)]*)\)"#
        return capturedValues(matching: urlPattern, in: html).contains {
            Self.isRemoteURL($0.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'")))
        }
    }

    private func capturedValues(matching pattern: String, in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            for index in 1..<match.numberOfRanges {
                let capture = match.range(at: index)
                if capture.location != NSNotFound, let valueRange = Range(capture, in: html) {
                    return String(html[valueRange])
                }
            }
            return nil
        }
    }

    private static func isRemoteURL(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.hasPrefix("http://") || value.hasPrefix("https://") || value.hasPrefix("//")
    }
}
