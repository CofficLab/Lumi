import Foundation
import MagicKit

/// Grep 工具（纯 Swift 原生实现）
///
/// 使用 FileManager + NSRegularExpression 搜索文件内容。
/// 零外部依赖，不需要 ripgrep。
///
/// 支持：
/// - 正则表达式搜索（基于 NSRegularExpression）
/// - 多种输出模式（content / files_with_matches / count）
/// - 上下文行、行号
/// - Glob / Type 文件过滤
/// - 分页（head_limit / offset）
/// - 多行模式
/// - 大小写敏感/不敏感
struct GrepTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    let name = "grep"
    let description = """
Search file contents using regex. Supports multiple output modes and file filtering.

Output modes:
- `files_with_matches` (default): Shows file paths that contain matches.
- `content`: Shows matching lines with line numbers and context.
- `count`: Shows match counts per file.

Tips:
- Use `glob` to filter by file type (e.g., "*.swift", "*.{ts,tsx}").
- Use `type` for common language types (swift, js, py, rust, go, java, etc.).
- Use `head_limit` to limit results (default 250). Pass 0 for unlimited.
- Use `output_mode: "content"` with `-A`/`-B`/`-C` for context around matches.
"""

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "The regular expression pattern to search for in file contents"
                ],
                "path": [
                    "type": "string",
                    "description": "File or directory to search in. Defaults to current working directory."
                ],
                "glob": [
                    "type": "string",
                    "description": "Glob pattern to filter files (e.g. \"*.swift\", \"*.{ts,tsx}\")"
                ],
                "output_mode": [
                    "type": "string",
                    "enum": ["content", "files_with_matches", "count"],
                    "description": "Output mode. Defaults to \"files_with_matches\"."
                ],
                "-i": [
                    "type": "boolean",
                    "description": "Case insensitive search"
                ],
                "-n": [
                    "type": "boolean",
                    "description": "Show line numbers (default true, only for content mode)"
                ],
                "-A": [
                    "type": "number",
                    "description": "Lines to show after each match (content mode only)"
                ],
                "-B": [
                    "type": "number",
                    "description": "Lines to show before each match (content mode only)"
                ],
                "-C": [
                    "type": "number",
                    "description": "Lines to show before and after each match (content mode only)"
                ],
                "type": [
                    "type": "string",
                    "description": "File type to search (e.g., swift, python, rust, go, java)"
                ],
                "head_limit": [
                    "type": "number",
                    "description": "Limit output to first N results (default 250). Pass 0 for unlimited."
                ],
                "offset": [
                    "type": "number",
                    "description": "Skip first N results before applying head_limit (default 0)"
                ],
                "multiline": [
                    "type": "boolean",
                    "description": "Enable multiline mode where . matches newlines (default false)"
                ]
            ],
            "required": ["pattern"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let pattern = arguments["pattern"]?.value as? String else {
            return "Error: Missing required argument 'pattern'."
        }

        let path = arguments["path"]?.value as? String
        let glob = arguments["glob"]?.value as? String
        let outputMode = arguments["output_mode"]?.value as? String ?? "files_with_matches"
        let caseInsensitive = arguments["-i"]?.value as? Bool ?? false
        let showLineNumbers = arguments["-n"]?.value as? Bool ?? true
        let contextAfter = arguments["-A"]?.value as? Int
        let contextBefore = arguments["-B"]?.value as? Int
        let contextBoth = arguments["-C"]?.value as? Int
        let type = arguments["type"]?.value as? String
        let headLimit = arguments["head_limit"]?.value as? Int
        let offset = arguments["offset"]?.value as? Int ?? 0
        let multiline = arguments["multiline"]?.value as? Bool ?? false

        // 确定搜索路径
        let searchPath: String
        if let path = path {
            searchPath = (path as NSString).expandingTildeInPath
        } else {
            searchPath = FileManager.default.currentDirectoryPath
        }

        // 编译正则表达式
        let regexOptions: NSRegularExpression.Options = [
            caseInsensitive ? .caseInsensitive : [],
        ]
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: regexOptions)
        } catch {
            return "Error: Invalid regex pattern: \(error.localizedDescription)"
        }

        // 构建 glob 过滤器
        let globPatterns: [String]
        if let glob = glob {
            globPatterns = glob.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            globPatterns = []
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)grep '/\(pattern)/' in \(searchPath) mode=\(outputMode)")
        }

        // 验证搜索路径
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: searchPath, isDirectory: &isDir) else {
            return "Error: Path does not exist: \(searchPath)"
        }

        // 如果搜索路径是文件，直接搜索该文件
        if !isDir.boolValue {
            return searchSingleFile(
                at: searchPath,
                relativePath: (searchPath as NSString).lastPathComponent,
                regex: regex,
                outputMode: outputMode,
                showLineNumbers: showLineNumbers,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                contextBoth: contextBoth,
                multiline: multiline,
                headLimit: headLimit,
                offset: offset
            )
        }

        // 枚举目录中所有文件
        let files = enumerateFiles(in: searchPath, maxResults: nil)

        // 过滤文件
        let filteredFiles = files.filter { _, relativePath in
            // Type 过滤
            if let type = type {
                let fileName = (relativePath as NSString).lastPathComponent
                if !fileMatchesType(fileName: fileName, type: type) {
                    return false
                }
            }

            // Glob 过滤
            if !globPatterns.isEmpty {
                if !globPatterns.contains(where: { matchesGlobPattern($0, path: relativePath) }) {
                    return false
                }
            }

            // 跳过二进制文件（通过扩展名快速判断）
            let ext = (relativePath as NSString).pathExtension.lowercased()
            if isBinaryExtension(ext) { return false }

            return true
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)scanning \(filteredFiles.count) files")
        }

        // 根据输出模式执行搜索
        switch outputMode {
        case "files_with_matches":
            return searchFilesWithMatches(
                files: filteredFiles,
                regex: regex,
                multiline: multiline,
                headLimit: headLimit,
                offset: offset
            )

        case "content":
            return searchContent(
                files: filteredFiles,
                regex: regex,
                showLineNumbers: showLineNumbers,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                contextBoth: contextBoth,
                multiline: multiline,
                headLimit: headLimit,
                offset: offset
            )

        case "count":
            return searchCount(
                files: filteredFiles,
                regex: regex,
                multiline: multiline,
                headLimit: headLimit,
                offset: offset
            )

        default:
            return searchFilesWithMatches(
                files: filteredFiles,
                regex: regex,
                multiline: multiline,
                headLimit: headLimit,
                offset: offset
            )
        }
    }

    // MARK: - Search Modes

    /// files_with_matches 模式：返回包含匹配的文件路径
    private func searchFilesWithMatches(
        files: [(absolute: String, relative: String)],
        regex: NSRegularExpression,
        multiline: Bool,
        headLimit: Int?,
        offset: Int
    ) -> String {
        let effectiveLimit = headLimit ?? 250
        let isUnlimited = headLimit == 0

        var matchedFiles: [(path: String, relative: String)] = []

        for file in files {
            guard let content = readFileContent(at: file.absolute) else { continue }

            let text = multiline ? content : content
            let fullRange = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, options: [], range: fullRange) != nil {
                matchedFiles.append((file.absolute, file.relative))
            }

            if !isUnlimited && matchedFiles.count >= effectiveLimit + offset { break }
        }

        if matchedFiles.isEmpty { return "No files found" }

        // 按修改时间排序
        let fm = FileManager.default
        let sorted = matchedFiles.sorted { a, b in
            let mtimeA = (try? fm.attributesOfItem(atPath: a.path)[.modificationDate] as? Date) ?? .distantPast
            let mtimeB = (try? fm.attributesOfItem(atPath: b.path)[.modificationDate] as? Date) ?? .distantPast
            return mtimeA > mtimeB
        }

        // 分页
        let paginated = isUnlimited
            ? Array(sorted.dropFirst(offset))
            : Array(sorted.dropFirst(offset).prefix(effectiveLimit))
        let wasTruncated = !isUnlimited && sorted.count - offset > effectiveLimit

        let relativePaths = paginated.map(\.relative)
        let numFiles = relativePaths.count

        var output = "Found \(numFiles) \(numFiles == 1 ? "file" : "files")"
        var paginationParts: [String] = []
        if wasTruncated { paginationParts.append("limit: \(effectiveLimit)") }
        if offset > 0 { paginationParts.append("offset: \(offset)") }
        if !paginationParts.isEmpty {
            output += " \(paginationParts.joined(separator: ", "))"
        }
        output += "\n" + relativePaths.joined(separator: "\n")

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)\(numFiles) files found")
        }
        return output
    }

    /// content 模式：返回匹配的行内容
    private func searchContent(
        files: [(absolute: String, relative: String)],
        regex: NSRegularExpression,
        showLineNumbers: Bool,
        contextBefore: Int?,
        contextAfter: Int?,
        contextBoth: Int?,
        multiline: Bool,
        headLimit: Int?,
        offset: Int
    ) -> String {
        let effectiveLimit = headLimit ?? 250
        let isUnlimited = headLimit == 0
        let beforeLines = contextBoth ?? contextBefore ?? 0
        let afterLines = contextBoth ?? contextAfter ?? 0

        var outputLines: [String] = []
        var stopped = false

        for file in files {
            if stopped { break }
            guard let content = readFileContent(at: file.absolute) else { continue }

            let lines = content.components(separatedBy: "\n")
            let matches = findMatchingLines(in: lines, regex: regex)

            for matchLineNum in matches {
                if !isUnlimited && outputLines.count >= effectiveLimit + offset {
                    stopped = true
                    break
                }

                let contextStart = max(0, matchLineNum - beforeLines)
                let contextEnd = min(lines.count - 1, matchLineNum + afterLines)

                for lineNum in contextStart...contextEnd {
                    let line = lines[lineNum]
                    if showLineNumbers {
                        outputLines.append("\(file.relative):\(lineNum + 1):\(line)")
                    } else {
                        outputLines.append("\(file.relative):\(line)")
                    }
                }

                // 在不同匹配之间插入分隔（仅在有上下文时）
                if beforeLines > 0 || afterLines > 0 {
                    outputLines.append("--")
                }
            }
        }

        if outputLines.isEmpty { return "No matches found." }

        // 移除末尾的 "--" 分隔符
        if outputLines.last == "--" { outputLines.removeLast() }

        // 分页
        let paginated = isUnlimited
            ? Array(outputLines.dropFirst(offset))
            : Array(outputLines.dropFirst(offset).prefix(effectiveLimit))
        let wasTruncated = !isUnlimited && outputLines.count - offset > effectiveLimit

        var output = paginated.joined(separator: "\n")

        if wasTruncated || offset > 0 {
            var parts: [String] = []
            if wasTruncated { parts.append("limit: \(effectiveLimit)") }
            if offset > 0 { parts.append("offset: \(offset)") }
            output += "\n\n[Showing results with pagination = \(parts.joined(separator: ", "))]"
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)\(paginated.count) lines returned")
        }
        return output
    }

    /// count 模式：返回每个文件的匹配数
    private func searchCount(
        files: [(absolute: String, relative: String)],
        regex: NSRegularExpression,
        multiline: Bool,
        headLimit: Int?,
        offset: Int
    ) -> String {
        let effectiveLimit = headLimit ?? 250
        let isUnlimited = headLimit == 0

        var countEntries: [(relative: String, count: Int)] = []

        for file in files {
            guard let content = readFileContent(at: file.absolute) else { continue }

            let fullRange = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: fullRange)
            if !matches.isEmpty {
                countEntries.append((file.relative, matches.count))
            }
        }

        if countEntries.isEmpty { return "No matches found." }

        // 分页
        let paginated = isUnlimited
            ? Array(countEntries.dropFirst(offset))
            : Array(countEntries.dropFirst(offset).prefix(effectiveLimit))
        let wasTruncated = !isUnlimited && countEntries.count - offset > effectiveLimit

        let totalMatches = paginated.reduce(0) { $0 + $1.count }
        let fileCount = paginated.count

        var output = paginated.map { "\($0.relative):\($0.count)" }.joined(separator: "\n")
        output += "\n\nFound \(totalMatches) total \(totalMatches == 1 ? "occurrence" : "occurrences") across \(fileCount) \(fileCount == 1 ? "file" : "files")."

        if wasTruncated || offset > 0 {
            var parts: [String] = []
            if wasTruncated { parts.append("limit: \(effectiveLimit)") }
            if offset > 0 { parts.append("offset: \(offset)") }
            output += " with pagination = \(parts.joined(separator: ", "))"
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)\(totalMatches) matches in \(fileCount) files")
        }
        return output
    }

    // MARK: - Single File Search (when path is a file, not directory)

    private func searchSingleFile(
        at absolutePath: String,
        relativePath: String,
        regex: NSRegularExpression,
        outputMode: String,
        showLineNumbers: Bool,
        contextBefore: Int?,
        contextAfter: Int?,
        contextBoth: Int?,
        multiline: Bool,
        headLimit: Int?,
        offset: Int
    ) -> String {
        guard let content = readFileContent(at: absolutePath) else {
            return "Error: Cannot read file: \(absolutePath)"
        }

        let fullRange = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: fullRange)

        if matches.isEmpty { return "No matches found." }

        switch outputMode {
        case "files_with_matches":
            return "Found 1 file\n\(relativePath)"

        case "count":
            return "\(relativePath):\(matches.count)\n\nFound \(matches.count) total \(matches.count == 1 ? "occurrence" : "occurrences") across 1 file."

        case "content":
            let lines = content.components(separatedBy: "\n")
            let beforeLines = contextBoth ?? contextBefore ?? 0
            let afterLines = contextBoth ?? contextAfter ?? 0
            let effectiveLimit = headLimit ?? 250
            let isUnlimited = headLimit == 0

            // 找出所有匹配行号
            let matchedLineNums = findMatchingLines(in: lines, regex: regex)

            var outputLines: [String] = []
            for matchLineNum in matchedLineNums {
                if !isUnlimited && outputLines.count >= effectiveLimit { break }

                let ctxStart = max(0, matchLineNum - beforeLines)
                let ctxEnd = min(lines.count - 1, matchLineNum + afterLines)

                for ln in ctxStart...ctxEnd {
                    let line = lines[ln]
                    if showLineNumbers {
                        outputLines.append("\(relativePath):\(ln + 1):\(line)")
                    } else {
                        outputLines.append("\(relativePath):\(line)")
                    }
                }
                if beforeLines > 0 || afterLines > 0 {
                    outputLines.append("--")
                }
            }

            if outputLines.last == "--" { outputLines.removeLast() }
            return outputLines.isEmpty ? "No matches found." : outputLines.joined(separator: "\n")

        default:
            return "Found 1 file\n\(relativePath)"
        }
    }

    // MARK: - Helpers

    /// 读取文件内容，自动处理编码
    private func readFileContent(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }

        // 尝试 UTF-8
        if let str = String(data: data, encoding: .utf8) {
            // 快速检测二进制：检查前 8KB 中是否有 null 字节
            let checkSize = min(data.count, 8192)
            let checkData = data.prefix(checkSize)
            if checkData.contains(where: { $0 == 0 }) { return nil }
            return str
        }

        // 尝试 UTF-16
        if let str = String(data: data, encoding: .utf16LittleEndian) { return str }
        if let str = String(data: data, encoding: .utf16BigEndian) { return str }

        return nil
    }

    /// 在行数组中找到所有匹配正则的行号
    private func findMatchingLines(in lines: [String], regex: NSRegularExpression) -> [Int] {
        var matchLineNums: [Int] = []
        for (idx, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            if regex.firstMatch(in: line, options: [], range: range) != nil {
                matchLineNums.append(idx)
            }
        }
        return matchLineNums
    }

    /// 判断文件扩展名是否属于二进制文件
    private func isBinaryExtension(_ ext: String) -> Bool {
        let binaryExts: Set<String> = [
            "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp", "svg",
            "mp3", "mp4", "wav", "avi", "mov", "mkv", "flv", "wmv",
            "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "iso",
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "exe", "dll", "so", "dylib", "o", "a", "lib",
            "pyc", "pyo", "class", "jar", "war",
            "woff", "woff2", "ttf", "otf", "eot",
            "sqlite", "db", "bin", "dat",
            "nib", "storyboardc", "xib", "xcassets",
        ]
        return binaryExts.contains(ext)
    }
}
