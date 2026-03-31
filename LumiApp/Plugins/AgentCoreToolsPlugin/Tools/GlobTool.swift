import Foundation
import MagicKit

/// Glob 工具
///
/// 使用 glob 模式匹配查找文件。
/// 支持：
/// - 通配符匹配（*, **, ?, [...]）
/// - 路径搜索
/// - 结果排序与截断
struct GlobTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose = false

    let name = "glob"
    let description = """
Find files matching a glob pattern. Useful for discovering files in a project by name or extension.

Pattern examples:
- `**/*.swift` — all Swift files recursively
- `src/**/*.ts` — all TypeScript files under src/
- `*.{json,yaml,yml}` — all config files
- `**/test_*.py` — all Python test files
- `README*` — all files starting with README

The search is case-sensitive. Use `path` to narrow the search to a specific directory.
"""

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "The glob pattern to match files against (e.g., \"**/*.swift\", \"*.{json,yaml}\")"
                ],
                "path": [
                    "type": "string",
                    "description": "The directory to search in. Defaults to current working directory. Must be a valid directory path if provided."
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
        let searchPath: String
        if let path = path {
            searchPath = (path as NSString).expandingTildeInPath
        } else {
            searchPath = FileManager.default.currentDirectoryPath
        }

        let fileManager = FileManager.default

        // Validate path exists and is a directory
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: searchPath, isDirectory: &isDir), isDir.boolValue else {
            return "Error: Directory does not exist: \(searchPath)"
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)glob '\(pattern)' in \(searchPath)")
        }

        let maxResults = 100
        let files = findFiles(pattern: pattern, in: searchPath, maxResults: maxResults)

        if files.isEmpty {
            return "No files found matching pattern: \(pattern)"
        }

        // Make paths relative for readability
        let relativePaths = files.map { makeRelative($0, basePath: searchPath) }

        var result = relativePaths.joined(separator: "\n")

        if files.count >= maxResults {
            result += "\n\n(Results are truncated at \(maxResults) files. Consider using a more specific path or pattern.)"
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)found \(files.count) files")
        }

        return result
    }

    // MARK: - File Matching

    /// Find files matching a glob pattern.
    ///
    /// Uses FileManager enumeration with custom pattern matching to support
    /// standard glob patterns: *, **, ?, and [...] character classes.
    private func findFiles(pattern: String, in directory: String, maxResults: Int) -> [String] {
        let fileManager = FileManager.default
        var results: [String] = []

        // Use deep enumeration for ** patterns
        let hasRecursiveGlob = pattern.contains("**")

        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            if results.count >= maxResults { break }

            let filePath = url.path
            let relativePath = makeRelative(filePath, basePath: directory)

            // Skip directories (unless the pattern explicitly targets them)
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                // Skip version control directories
                let lastComponent = url.lastPathComponent
                if [".git", ".svn", ".hg", ".bzr", "node_modules", ".build", "DerivedData"].contains(lastComponent) {
                    enumerator?.skipDescendants()
                }
                continue
            }

            // Match against pattern
            if matchesGlob(pattern: pattern, path: relativePath) {
                results.append(filePath)
            }
        }

        return results
    }

    /// Make a path relative to a base path.
    private func makeRelative(_ path: String, basePath: String) -> String {
        let trimmedBase = basePath.hasSuffix("/") ? basePath : basePath + "/"
        if path.hasPrefix(trimmedBase) {
            return String(path.dropFirst(trimmedBase.count))
        }
        return path
    }

    // MARK: - Glob Pattern Matching

    /// Match a file path against a glob pattern.
    ///
    /// Supports:
    /// - `*` matches any sequence of characters within a single path component
    /// - `**` matches any sequence of characters across path separators
    /// - `?` matches any single character
    /// - `[...]` matches any character in the brackets
    /// - `{a,b,c}` matches any of the alternatives
    private func matchesGlob(pattern: String, path: String) -> Bool {
        // Handle brace expansion: *.{ts,tsx} → *.ts, *.tsx
        if pattern.contains("{") && pattern.contains("}") {
            let expanded = expandBraces(pattern)
            return expanded.contains { matchesGlob(pattern: $0, path: path) }
        }

        // Convert glob pattern to regex
        var regex = ""
        var i = pattern.startIndex
        let chars = pattern

        while i < chars.endIndex {
            let c = chars[i]

            if c == "*" {
                let nextIdx = chars.index(after: i)
                if nextIdx < chars.endIndex && chars[nextIdx] == "*" {
                    // ** — match across directories
                    regex += ".*"
                    i = chars.index(after: nextIdx)
                    // Skip trailing /
                    if i < chars.endIndex && chars[i] == "/" {
                        regex += "/?"
                        i = chars.index(after: i)
                    }
                } else {
                    // * — match within a directory
                    regex += "[^/]*"
                    i = chars.index(after: i)
                }
            } else if c == "?" {
                regex += "[^/]"
                i = chars.index(after: i)
            } else if c == "[" {
                // Character class
                let start = i
                var end = chars.index(after: i)
                while end < chars.endIndex && chars[end] != "]" {
                    end = chars.index(after: end)
                }
                if end < chars.endIndex {
                    let bracketContent = chars[chars.index(after: start)..<end]
                    regex += "[\(bracketContent)]"
                    i = chars.index(after: end)
                } else {
                    regex += "\\["
                    i = chars.index(after: i)
                }
            } else {
                // Escape regex special characters
                if "\\^$.|+(){}!".contains(c) {
                    regex += "\\\(c)"
                } else {
                    regex += String(c)
                }
                i = chars.index(after: i)
            }
        }

        guard let compiledRegex = try? NSRegularExpression(pattern: "^\(regex)$", options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(path.startIndex..., in: path)
        return compiledRegex.firstMatch(in: path, options: [], range: range) != nil
    }

    /// Expand brace patterns like *.{ts,tsx} into [*.ts, *.tsx].
    private func expandBraces(_ pattern: String) -> [String] {
        guard let openIdx = pattern.firstIndex(of: "{"),
              let closeIdx = pattern.firstIndex(of: "}") else {
            return [pattern]
        }

        let prefix = String(pattern[pattern.startIndex..<openIdx])
        let suffix = String(pattern[pattern.index(after: closeIdx)...])
        let inner = pattern[pattern.index(after: openIdx)..<closeIdx]
        let alternatives = inner.split(separator: ",").map(String.init)

        return alternatives.map { "\(prefix)\($0)\(suffix)" }
    }
}
