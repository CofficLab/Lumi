import Foundation

/// 本地规则扫描器
///
/// 使用轻量级本地规则扫描项目文件，零成本、零 Token 消耗。
/// 检测内容：TODO/FIXME/HACK 注释、空 catch 块、大文件等。
struct LocalRuleScanner: Sendable {

    // MARK: - Configuration

    /// 忽略的目录名
    private let ignoredDirectories: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData",
        ".swiftpm", "Pods", ".gradle", "build",
        ".venv", "__pycache__", ".next", "dist"
    ]

    /// 支持文本扫描的文件扩展名。空扩展名用于 Dockerfile、Makefile 等。
    private let supportedExtensions: Set<String> = [
        "", "swift", "m", "mm", "h", "c", "cc", "cpp", "hpp",
        "js", "jsx", "ts", "tsx", "vue", "svelte",
        "py", "rb", "go", "rs", "java", "kt", "kts",
        "php", "cs", "sh", "zsh", "bash",
        "json", "yaml", "yml", "toml", "xml", "md"
    ]

    /// 触发大文件警告的行数阈值
    private let largeFileLineThreshold = 500

    // MARK: - Public API

    /// 扫描指定项目路径
    func scan(projectPath: String) -> [ProjectIssue] {
        let rootURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var issues: [ProjectIssue] = []

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
                if values.isDirectory == true {
                    if ignoredDirectories.contains(fileURL.lastPathComponent) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard values.isRegularFile == true else { continue }
                guard shouldScan(fileURL: fileURL, fileSize: values.fileSize) else { continue }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                issues.append(contentsOf: scanFile(content: content, fileURL: fileURL, rootURL: rootURL))
            } catch {
                continue
            }
        }

        return issues
    }

    // MARK: - Private

    private func shouldScan(fileURL: URL, fileSize: Int?) -> Bool {
        if let fileSize, fileSize > 512 * 1024 {
            return false
        }

        let extensionName = fileURL.pathExtension.lowercased()
        guard supportedExtensions.contains(extensionName) else {
            return false
        }

        return true
    }

    private func scanFile(content: String, fileURL: URL, rootURL: URL) -> [ProjectIssue] {
        let relativePath = relativePath(for: fileURL, rootURL: rootURL)
        let lines = content.components(separatedBy: .newlines)
        let now = Date()
        var issues: [ProjectIssue] = []

        for (offset, line) in lines.enumerated() {
            let lineNumber = offset + 1
            let uppercasedLine = line.uppercased()

            if uppercasedLine.contains("FIXME") {
                issues.append(commentIssue(
                    type: .fixme,
                    severity: .warning,
                    marker: "FIXME",
                    line: line,
                    lineNumber: lineNumber,
                    relativePath: relativePath,
                    rootURL: rootURL,
                    now: now
                ))
            } else if uppercasedLine.contains("HACK") {
                issues.append(commentIssue(
                    type: .hack,
                    severity: .info,
                    marker: "HACK",
                    line: line,
                    lineNumber: lineNumber,
                    relativePath: relativePath,
                    rootURL: rootURL,
                    now: now
                ))
            } else if uppercasedLine.contains("TODO") {
                issues.append(commentIssue(
                    type: .todo,
                    severity: .info,
                    marker: "TODO",
                    line: line,
                    lineNumber: lineNumber,
                    relativePath: relativePath,
                    rootURL: rootURL,
                    now: now
                ))
            }
        }

        if lines.count >= largeFileLineThreshold {
            issues.append(ProjectIssue(
                type: .largeFile,
                severity: .warning,
                projectPath: rootURL.path,
                filePath: relativePath,
                lineNumber: nil,
                title: "Large file",
                description: "\(relativePath) has \(lines.count) lines.",
                suggestion: "Consider splitting this file into smaller focused types or modules.",
                source: .localRule,
                createdAt: now,
                updatedAt: now
            ))
        }

        issues.append(contentsOf: emptyCatchIssues(lines: lines, relativePath: relativePath, rootURL: rootURL, now: now))

        return issues
    }

    private func commentIssue(
        type: ProjectIssueType,
        severity: ProjectIssueSeverity,
        marker: String,
        line: String,
        lineNumber: Int,
        relativePath: String,
        rootURL: URL,
        now: Date
    ) -> ProjectIssue {
        let cleaned = line
            .replacingOccurrences(of: "//", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "/*", with: "")
            .replacingOccurrences(of: "*/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ProjectIssue(
            type: type,
            severity: severity,
            projectPath: rootURL.path,
            filePath: relativePath,
            lineNumber: lineNumber,
            title: marker,
            description: cleaned.isEmpty ? "\(marker) marker found." : cleaned,
            suggestion: "Review whether this marker still represents actionable work.",
            source: .localRule,
            createdAt: now,
            updatedAt: now
        )
    }

    private func emptyCatchIssues(lines: [String], relativePath: String, rootURL: URL, now: Date) -> [ProjectIssue] {
        var issues: [ProjectIssue] = []

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("catch") || trimmed.contains(" catch ") || trimmed.contains(" catch(") else {
                continue
            }

            guard catchBlockStarting(at: index, lines: lines) == true else { continue }

            issues.append(ProjectIssue(
                type: .emptyCatch,
                severity: .warning,
                projectPath: rootURL.path,
                filePath: relativePath,
                lineNumber: index + 1,
                title: "Empty catch block",
                description: "A catch block swallows errors without handling or logging them.",
                suggestion: "Handle the error, log it, or document why ignoring it is intentional.",
                source: .localRule,
                createdAt: now,
                updatedAt: now
            ))
        }

        return issues
    }

    private func catchBlockStarting(at startIndex: Int, lines: [String]) -> Bool? {
        var depth = 0
        var sawOpeningBrace = false
        var bodyLines: [String] = []

        for index in startIndex..<min(lines.count, startIndex + 20) {
            let line = lines[index]
            if line.contains("{") {
                sawOpeningBrace = true
            }

            if sawOpeningBrace {
                let withoutComments = stripLineComment(line)
                let bodyCandidate = withoutComments
                    .replacingOccurrences(of: "catch", with: "")
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !bodyCandidate.isEmpty {
                    bodyLines.append(bodyCandidate)
                }

                depth += line.filter { $0 == "{" }.count
                depth -= line.filter { $0 == "}" }.count
                if depth <= 0 {
                    return bodyLines.isEmpty
                }
            }
        }

        return nil
    }

    private func stripLineComment(_ line: String) -> String {
        guard let range = line.range(of: "//") else {
            return line
        }
        return String(line[..<range.lowerBound])
    }

    private func relativePath(for fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return filePath }

        let start = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        return String(filePath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
