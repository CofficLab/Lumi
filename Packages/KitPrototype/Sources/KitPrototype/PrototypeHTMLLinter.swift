import Foundation

// MARK: - 校验结果

public enum PrototypeLintSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct PrototypeLintIssue: Codable, Equatable, Sendable {
    public let severity: PrototypeLintSeverity
    public let code: String
    public let message: String

    public init(severity: PrototypeLintSeverity, code: String, message: String) {
        self.severity = severity
        self.code = code
        self.message = message
    }
}

public struct PrototypeLintReport: Codable, Equatable, Sendable {
    public let issues: [PrototypeLintIssue]

    public var errors: [PrototypeLintIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [PrototypeLintIssue] { issues.filter { $0.severity == .warning } }
    public var isValid: Bool { errors.isEmpty }

    public init(issues: [PrototypeLintIssue]) {
        self.issues = issues
    }
}

// MARK: - 校验器

/// 原型屏幕 HTML 静态校验器。
///
/// 规则集建立在 `AppStorePromoHTMLLinter` 之上，差异有三点，都是原型场景的必然要求：
///
/// 1. **允许 `transition` / `animation`**——原型常有过渡效果。promo 场景禁用它们
///    是为了导出确定性；此处降为 warning（导出时由 `PrototypeHTMLExporter` 关闭动效）。
/// 2. **要求 `data-block` 标注**——右键区块「发给助手」依赖它定位元素；
///    没有任何标注时只给 warning，不阻断（存量手写 HTML 仍可预览）。
/// 3. **跳转目标必须存在于项目内**——`data-prototype-link` 指向不存在的屏幕时，
///    原型点不通。调用方传入已知屏幕 slug 集合后本规则才生效。
public struct PrototypeHTMLLinter: Sendable {
    public let maximumUTF8Bytes: Int

    public init(maximumUTF8Bytes: Int = 2_000_000) {
        self.maximumUTF8Bytes = maximumUTF8Bytes
    }

    /// 校验一屏 HTML。
    ///
    /// - Parameters:
    ///   - html: 完整 HTML 文档。
    ///   - documentDirectory: 屏幕目录；相对资源路径以此为基准解析。
    ///   - allowedResourceRoot: 资源允许存在的最高层级目录。默认等于
    ///     `documentDirectory`。项目级共享素材位于屏幕目录的父级，因此
    ///     store 会传入**项目目录**，让 `../assets/x.png` 合法，同时仍然
    ///     拒绝逃逸出项目之外的路径。
    ///   - knownScreenIDs: 项目内已知屏幕 slug；提供时校验跳转目标有效性。
    ///                      传 `nil` 表示跳过该规则（例如新建项目首屏尚无同伴）。
    public func lint(
        html: String,
        documentDirectory: URL? = nil,
        allowedResourceRoot: URL? = nil,
        knownScreenIDs: Set<String>? = nil
    ) -> PrototypeLintReport {
        var issues: [PrototypeLintIssue] = []
        let lower = html.lowercased()

        func add(_ severity: PrototypeLintSeverity, _ code: String, _ message: String) {
            issues.append(.init(severity: severity, code: code, message: message))
        }

        // 已转义为 &lt; 的尖括号会掩盖 script/iframe 检查，先拦下来。
        if lower.range(of: #"&lt;\s*(script|iframe)\b"#, options: .regularExpression) != nil {
            add(.warning, "escaped_markup", "Found escaped <script>/<iframe> text. Make sure real markup was not accidentally HTML-escaped.")
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
            add(.error, "script_forbidden", "Scripts are not allowed. Declare screen jumps with data-prototype-link instead; the host injects the navigation script.")
        }
        if lower.range(of: #"<\s*iframe\b"#, options: .regularExpression) != nil {
            add(.error, "iframe_forbidden", "Iframes are not allowed.")
        }
        if lower.range(of: #"https?://"#, options: .regularExpression) != nil || lower.contains("//cdn.") {
            add(.error, "remote_resource", "Remote resources are not allowed; import files into the project assets directory.")
        }
        if lower.range(of: #"@import\s"#, options: .regularExpression) != nil {
            add(.error, "css_import_forbidden", "CSS @import is not allowed.")
        }

        // 原型特有：允许动效，但提醒导出时会关闭。
        if lower.range(of: #"(?:animation|transition)\s*:"#, options: .regularExpression) != nil {
            add(.warning, "motion_present", "Motion is disabled during export; keep it decorative only.")
        }
        if lower.range(of: #"overflow\s*:\s*hidden"#, options: .regularExpression) == nil {
            add(.warning, "overflow_not_hidden", "Set overflow: hidden on the page root to avoid accidental scrolling inside the device frame.")
        }
        if lower.range(of: #"background(?:-color)?\s*:"#, options: .regularExpression) == nil {
            add(.warning, "background_missing", "Declare an opaque page background so the exported screen is not transparent.")
        }
        if lower.range(of: PrototypeHTMLAttributes.block + #"\s*="#, options: .regularExpression) == nil {
            add(.warning, "no_block_annotations", "No data-block annotations found. Add data-block and data-block-label to major regions so they can be edited from the preview.")
        }

        validateBlockAnnotations(html: html, add: add)
        validateJumpTargets(html: html, knownScreenIDs: knownScreenIDs, add: add)
        validateLocalResources(
            html: html,
            documentDirectory: documentDirectory,
            allowedResourceRoot: allowedResourceRoot,
            add: add
        )

        return PrototypeLintReport(issues: issues)
    }

    // MARK: - 可编辑区块标注

    private func validateBlockAnnotations(
        html: String,
        add: (PrototypeLintSeverity, String, String) -> Void
    ) {
        let tagPattern = #"<[a-zA-Z][^>]*\bdata-block\s*=\s*[\"']([^\"']*)[\"'][^>]*>"#
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive]) else {
            return
        }
        let labelPattern = #"\bdata-block-label\s*=\s*[\"'][^\"']*[\"']"#
        let labelRegex = try? NSRegularExpression(pattern: labelPattern, options: [.caseInsensitive])
        let documentRange = NSRange(html.startIndex..., in: html)
        var counts: [String: Int] = [:]

        for match in tagRegex.matches(in: html, range: documentRange) {
            guard match.numberOfRanges > 1,
                  let idRange = Range(match.range(at: 1), in: html),
                  let tagRange = Range(match.range(at: 0), in: html) else { continue }
            let rawID = String(html[idRange])
            let blockID = Self.decodeBasicHTMLEntities(rawID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if blockID.isEmpty {
                add(.warning, "empty_block_id", "data-block values must not be empty.")
            } else {
                counts[blockID, default: 0] += 1
            }

            let tag = String(html[tagRange])
            let tagNSRange = NSRange(tag.startIndex..., in: tag)
            if labelRegex?.firstMatch(in: tag, range: tagNSRange) == nil {
                let identity = blockID.isEmpty ? "this element" : "data-block=\"\(blockID)\""
                add(.warning, "missing_block_label", "Add data-block-label to \(identity) so the context menu is readable.")
            }
        }

        for blockID in counts.keys.sorted() where counts[blockID, default: 0] > 1 {
            add(.warning, "duplicate_block_id", "data-block=\"\(blockID)\" is duplicated. Block IDs must be unique within a screen.")
        }
    }

    private static func decodeBasicHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: - 跳转目标

    private func validateJumpTargets(
        html: String,
        knownScreenIDs: Set<String>?,
        add: (PrototypeLintSeverity, String, String) -> Void
    ) {
        guard let knownScreenIDs else { return }
        let targets = PrototypeHotspot.declaredTargets(inHTML: html)
        guard !targets.isEmpty else {
            add(.warning, "no_navigation", "This screen declares no data-prototype-link, so nothing is clickable from it.")
            return
        }
        for target in targets.sorted() where !knownScreenIDs.contains(target) {
            add(.error, "unknown_link_target", "data-prototype-link=\"\(target)\" does not match any screen in this project.")
        }
    }

    // MARK: - 本地资源

    /// 校验本地资源引用。
    ///
    /// 解析基准是**屏幕目录**（`documentDirectory`），允许边界默认也是它。
    /// 但共享素材位于项目目录（屏幕目录的父级），因此 store 会把
    /// `allowedResourceRoot` 传成项目目录——这样 `../assets/x.png` 合法，
    /// 而 `../../../etc/passwd` 之类的越界路径仍被拒绝。
    private func validateLocalResources(
        html: String,
        documentDirectory: URL?,
        allowedResourceRoot: URL?,
        add: (PrototypeLintSeverity, String, String) -> Void
    ) {
        for path in Self.localResourcePaths(in: html) {
            guard !path.hasPrefix("data:") && !path.hasPrefix("#") else { continue }
            let decoded = path.removingPercentEncoding ?? path

            // 绝对路径一律拒绝：原型必须可随项目整体搬迁。
            if decoded.hasPrefix("/") {
                add(.error, "unsafe_asset_path", "Absolute asset paths are not allowed: \(path)")
                continue
            }
            guard let documentDirectory else { continue }

            let url = documentDirectory.appendingPathComponent(decoded).standardizedFileURL
            let baseDirectory = documentDirectory.standardizedFileURL
            let allowedRoot = (allowedResourceRoot ?? documentDirectory).standardizedFileURL

            // 先确认路径解析后仍在屏幕目录内，或落在允许的共享根目录内。
            let basePath = baseDirectory.path
            let rootPath = allowedRoot.path
            let resolved = url.path
            let isInsideScreen = resolved == basePath || resolved.hasPrefix(basePath + "/")
            let isInsideRoot = resolved == rootPath || resolved.hasPrefix(rootPath + "/")
            guard isInsideScreen || isInsideRoot else {
                add(.error, "unsafe_asset_path", "Asset path escapes the prototype directory: \(path)")
                continue
            }

            if !FileManager.default.fileExists(atPath: url.path) {
                add(.error, "missing_asset", "Referenced asset does not exist: \(path)")
            }
        }
    }

    private static func localResourcePaths(in html: String) -> [String] {
        let pattern = #"(?:src|href)\s*=\s*[\"']([^\"']+)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[valueRange])
        }
    }
}
