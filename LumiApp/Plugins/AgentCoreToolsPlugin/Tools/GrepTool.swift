import Foundation
import MagicKit

/// Grep 工具
///
/// 使用 ripgrep (rg) 搜索文件内容。
/// 支持：
/// - 正则表达式搜索
/// - 多种输出模式（content / files_with_matches / count）
/// - 上下文行、行号
/// - Glob 过滤
/// - 分页（head_limit / offset）
struct GrepTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    let name = "grep"
    let description = """
Search file contents using ripgrep (rg). Supports regex patterns and multiple output modes.

Output modes:
- `files_with_matches` (default): Shows file paths that contain matches.
- `content`: Shows matching lines with line numbers and context.
- `count`: Shows match counts per file.

Tips:
- Use `glob` to filter by file type (e.g., "*.swift", "*.{ts,tsx}").
- Use `type` for common language types (js, py, rust, go, java, etc.) — more efficient than glob.
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

        // Determine search path
        let searchPath: String
        if let path = path {
            searchPath = (path as NSString).expandingTildeInPath
        } else {
            searchPath = FileManager.default.currentDirectoryPath
        }

        // Build ripgrep arguments
        var args: [String] = ["--hidden", "--max-columns", "500"]

        // Exclude VCS directories
        let vcsDirs = [".git", ".svn", ".hg", ".bzr"]
        for dir in vcsDirs {
            args += ["--glob", "!\(dir)"]
        }

        // Multiline mode
        if multiline {
            args += ["-U", "--multiline-dotall"]
        }

        // Case insensitive
        if caseInsensitive {
            args.append("-i")
        }

        // Output mode
        switch outputMode {
        case "files_with_matches":
            args.append("-l")
        case "count":
            args.append("-c")
        case "content":
            break
        default:
            args.append("-l")
        }

        // Line numbers (content mode only)
        if showLineNumbers && outputMode == "content" {
            args.append("-n")
        }

        // Context lines (content mode only)
        if outputMode == "content" {
            if let c = contextBoth {
                args += ["-C", "\(c)"]
            } else {
                if let b = contextBefore { args += ["-B", "\(b)"] }
                if let a = contextAfter { args += ["-A", "\(a)"] }
            }
        }

        // Pattern (handle patterns starting with dash)
        if pattern.hasPrefix("-") {
            args += ["-e", pattern]
        } else {
            args.append(pattern)
        }

        // Type filter
        if let type = type {
            args += ["--type", type]
        }

        // Glob filter
        if let glob = glob {
            let patterns = glob.split(separator: ",").map(String.init)
            for p in patterns {
                args += ["--glob", p.trimmingCharacters(in: .whitespaces)]
            }
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)rg \(args.joined(separator: " ")) in \(searchPath)")
        }

        // Execute ripgrep
        let result = try await runRipgrep(args: args, path: searchPath)

        if result.isEmpty {
            return "No matches found."
        }

        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Apply pagination
        let effectiveLimit = headLimit ?? 250  // default limit
        let isUnlimited = headLimit == 0

        let sliced: [String]
        let wasTruncated: Bool

        if isUnlimited {
            sliced = Array(lines.dropFirst(offset))
            wasTruncated = false
        } else {
            let dropped = Array(lines.dropFirst(offset))
            wasTruncated = dropped.count > effectiveLimit
            sliced = Array(dropped.prefix(effectiveLimit))
        }

        // Process results based on output mode
        switch outputMode {
        case "content":
            // Make paths relative for readability
            let processed = sliced.map { makePathRelative($0, basePath: searchPath) }
            var output = processed.joined(separator: "\n")

            // Add pagination info
            if wasTruncated || offset > 0 {
                var parts: [String] = []
                if wasTruncated { parts.append("limit: \(effectiveLimit)") }
                if offset > 0 { parts.append("offset: \(offset)") }
                output += "\n\n[Showing results with pagination = \(parts.joined(separator: ", "))]"
            }

            if Self.verbose {
                AgentCoreToolsPlugin.logger.info("\(self.t)\(sliced.count) lines returned")
            }
            return output

        case "count":
            let processed = sliced.map { makePathRelative($0, basePath: searchPath) }
            var output = processed.joined(separator: "\n")

            // Parse totals
            var totalMatches = 0
            var fileCount = 0
            for line in processed {
                if let colonIdx = line.lastIndex(of: ":") {
                    let afterColon = line[line.index(after: colonIdx)...]
                    if let count = Int(afterColon) {
                        totalMatches += count
                        fileCount += 1
                    }
                }
            }

            let summary = "\n\nFound \(totalMatches) total \(totalMatches == 1 ? "occurrence" : "occurrences") across \(fileCount) \(fileCount == 1 ? "file" : "files")."
            output += summary

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

        default: // files_with_matches
            // Sort by modification time (most recent first)
            let sorted = sortByModificationTime(sliced)
            let relative = sorted.map { makePathRelative($0, basePath: searchPath) }
            let numFiles = relative.count

            var output = "Found \(numFiles) \(numFiles == 1 ? "file" : "files")"
            if wasTruncated || offset > 0 {
                var parts: [String] = []
                if wasTruncated { parts.append("limit: \(effectiveLimit)") }
                if offset > 0 { parts.append("offset: \(offset)") }
                output += " \(parts.joined(separator: ", "))"
            }
            output += "\n" + relative.joined(separator: "\n")

            if Self.verbose {
                AgentCoreToolsPlugin.logger.info("\(self.t)\(numFiles) files found")
            }
            return output
        }
    }

    // MARK: - Helper Methods

    /// Run ripgrep with the given arguments.
    private func runRipgrep(args: [String], path: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            // Try to find rg
            let rgPaths = ["/opt/homebrew/bin/rg", "/usr/local/bin/rg", "/usr/bin/rg"]
            var rgURL: URL?
            for p in rgPaths {
                if FileManager.default.isExecutableFile(atPath: p) {
                    rgURL = URL(fileURLWithPath: p)
                    break
                }
            }

            guard let executableURL = rgURL else {
                continuation.resume(returning: "Error: ripgrep (rg) is not installed. Install it with: brew install ripgrep")
                return
            }

            process.executableURL = executableURL
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: path)
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { _ in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: stdoutData, encoding: .utf8) ?? ""

                // Check exit code — ripgrep returns 1 for "no matches" (not an error)
                if process.terminationStatus == 0 || process.terminationStatus == 1 {
                    continuation.resume(returning: output)
                } else {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.resume(returning: "Error from ripgrep (exit \(process.terminationStatus)): \(errorOutput)")
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: "Error running ripgrep: \(error.localizedDescription)")
            }
        }
    }

    /// Make absolute paths relative to a base path for readability.
    private func makePathRelative(_ line: String, basePath: String) -> String {
        let trimmedBase = basePath.hasSuffix("/") ? basePath : basePath + "/"
        return line.replacingOccurrences(of: trimmedBase, with: "")
    }

    /// Sort file paths by modification time (most recent first).
    private func sortByModificationTime(_ paths: [String]) -> [String] {
        let fm = FileManager.default
        return paths.sorted { a, b in
            let mtimeA = (try? fm.attributesOfItem(atPath: a)[.modificationDate] as? Date) ?? .distantPast
            let mtimeB = (try? fm.attributesOfItem(atPath: b)[.modificationDate] as? Date) ?? .distantPast
            return mtimeA > mtimeB
        }
    }
}
