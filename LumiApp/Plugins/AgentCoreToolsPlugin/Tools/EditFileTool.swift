import Foundation
import MagicKit

/// 文件编辑工具
///
/// 基于精确字符串替换的文件编辑工具。
/// 支持：
/// - 先读后写的安全检查
/// - 智能引号匹配
/// - 原子性文件操作
/// - 详细的 diff 输出
struct EditFileTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose: Bool = false
    let name = "edit_file"
    let description = """
Performs exact string replacements in files.

Usage:
- The file must have been read with `read_file` in this conversation before editing. This tool will error if you attempt an edit without reading the file.
- When editing text from Read tool output, ensure you preserve the exact indentation (tabs/spaces) — everything after the line number prefix is the actual file content to match.
- The edit will FAIL if `old_string` is not unique in the file. Either provide a larger string with more surrounding context to make it unique or use `replace_all` to change every instance of `old_string`.
- Use `replace_all` for replacing and renaming strings across the file.
- Use the smallest old_string that's clearly unique — usually 2-4 adjacent lines is sufficient.
"""

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the file to modify"
                ],
                "old_string": [
                    "type": "string",
                    "description": "The text to replace"
                ],
                "new_string": [
                    "type": "string",
                    "description": "The text to replace it with (must be different from old_string)"
                ],
                "replace_all": [
                    "type": "boolean",
                    "description": "Replace all occurrences of old_string (default false)"
                ]
            ],
            "required": ["file_path", "old_string", "new_string"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let filePath = arguments["file_path"]?.value as? String,
              let oldString = arguments["old_string"]?.value as? String,
              let newString = arguments["new_string"]?.value as? String else {
            return "Error: Missing required arguments (file_path, old_string, new_string)."
        }

        let replaceAll = arguments["replace_all"]?.value as? Bool ?? false

        // Expand ~ to home directory
        let expandedPath = (filePath as NSString).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)编辑文件：\(expandedPath)")
        }

        // 1. Validate: old_string and new_string must be different
        if oldString == newString {
            return "Error: No changes to make — old_string and new_string are exactly the same."
        }

        // 2. Read the file
        let fileManager = FileManager.default
        var originalContent = ""
        var fileExists = false

        if fileManager.fileExists(atPath: expandedPath) {
            do {
                let data = try Data(contentsOf: fileURL)
                guard let content = String(data: data, encoding: .utf8) else {
                    return "Error: File content is not valid UTF-8 text."
                }
                originalContent = content
                fileExists = true
            } catch {
                return "Error reading file: \(error.localizedDescription)"
            }
        }

        // 3. Handle new file creation (old_string is empty and file doesn't exist)
        if !fileExists {
            if oldString.isEmpty {
                // Create parent directories if needed
                let directoryURL = fileURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: directoryURL.path) {
                    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                }
                try newString.write(to: fileURL, atomically: true, encoding: .utf8)
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)创建新文件：\(expandedPath)")
                }
                return "Created new file: \(filePath)"
            } else {
                return "Error: File does not exist: \(filePath). To create a new file, use an empty old_string."
            }
        }

        // 4. Empty file with empty old_string — write content
        if oldString.isEmpty {
            if originalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try newString.write(to: fileURL, atomically: true, encoding: .utf8)
                return "Wrote content to empty file: \(filePath)"
            } else {
                return "Error: Cannot create new file — file already exists and has content."
            }
        }

        // 5. Find the actual string (with quote normalization)
        let actualOldString = findActualString(in: originalContent, searchFor: oldString)

        guard let matched = actualOldString else {
            // Provide helpful error message
            let snippet: String
            if oldString.count > 200 {
                snippet = String(oldString.prefix(200)) + "..."
            } else {
                snippet = oldString
            }
            return "Error: String to replace not found in file.\nString: \(snippet)"
        }

        // 6. Check for multiple matches
        let matchCount = countOccurrences(of: matched, in: originalContent)
        if matchCount > 1 && !replaceAll {
            return "Error: Found \(matchCount) matches of the string to replace, but replace_all is false. To replace all occurrences, set replace_all to true. To replace only one occurrence, please provide more context to uniquely identify the instance."
        }

        // 7. Perform the replacement
        let updatedContent: String
        if replaceAll {
            updatedContent = originalContent.replacingOccurrences(of: matched, with: newString)
        } else {
            // Only replace the first occurrence
            if let range = originalContent.range(of: matched) {
                updatedContent = originalContent.replacingCharacters(in: range, with: newString)
            } else {
                return "Error: Failed to apply replacement."
            }
        }

        // 8. Verify something changed
        if updatedContent == originalContent {
            return "Error: Replacement produced no changes."
        }

        // 9. Write to disk (atomic write)
        try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // 10. Generate and return diff summary
        let diff = generateDiffSummary(original: originalContent, updated: updatedContent, filePath: filePath)

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)文件编辑成功：\(expandedPath)")
        }

        if replaceAll {
            return "The file \(filePath) has been updated. All \(matchCount) occurrences were successfully replaced.\n\n\(diff)"
        }

        return "The file \(filePath) has been updated successfully.\n\n\(diff)"
    }

    // MARK: - Helper Methods

    /// Find the actual string in the file content, handling quote normalization.
    /// Returns the actual matched string (may differ from search string due to quote style).
    private func findActualString(in content: String, searchFor: String) -> String? {
        // Try exact match first
        if content.contains(searchFor) {
            return searchFor
        }

        // Try with normalized quotes (curly → straight)
        let normalizedSearch = normalizeQuotes(searchFor)
        let normalizedContent = normalizeQuotes(content)

        if let range = normalizedContent.range(of: normalizedSearch) {
            // Map back to original content
            let nsContent = content as NSString
            let nsRange = NSRange(range, in: content)
            if nsRange.location != NSNotFound && nsRange.location + nsRange.length <= nsContent.length {
                return nsContent.substring(with: nsRange)
            }
        }

        return nil
    }

    /// Normalize curly quotes to straight quotes for matching.
    private func normalizeQuotes(_ str: String) -> String {
        str
            .replacingOccurrences(of: "\u{2018}", with: "'")  // '
            .replacingOccurrences(of: "\u{2019}", with: "'")  // '
            .replacingOccurrences(of: "\u{201C}", with: "\"") // "
            .replacingOccurrences(of: "\u{201D}", with: "\"") // "
    }

    /// Count occurrences of a substring in a string.
    private func countOccurrences(of substring: String, in string: String) -> Int {
        var count = 0
        var searchStart = string.startIndex
        while let range = string.range(of: substring, range: searchStart..<string.endIndex) {
            count += 1
            searchStart = range.upperBound
        }
        return count
    }

    /// Generate a unified diff-style summary showing what changed.
    private func generateDiffSummary(original: String, updated: String, filePath: String) -> String {
        let originalLines = original.components(separatedBy: "\n")
        let updatedLines = updated.components(separatedBy: "\n")

        // Find the first and last changed lines
        var firstChange = -1
        var lastChange = -1

        let maxLines = max(originalLines.count, updatedLines.count)
        for i in 0..<maxLines {
            let orig = i < originalLines.count ? originalLines[i] : nil
            let upd = i < updatedLines.count ? updatedLines[i] : nil
            if orig != upd {
                if firstChange == -1 { firstChange = i }
                lastChange = i
            }
        }

        if firstChange == -1 {
            return "(No visible changes in diff)"
        }

        // Show context around changes (2 lines before/after)
        let contextLines = 2
        let startLine = max(0, firstChange - contextLines)
        let endLine = min(updatedLines.count - 1, lastChange + contextLines)

        var result = ""
        for i in startLine...endLine {
            let lineNum = i + 1
            let prefix: String
            let origLine = i < originalLines.count ? originalLines[i] : nil
            let updLine = i < updatedLines.count ? updatedLines[i] : nil

            if origLine != updLine {
                if let orig = origLine, i < updatedLines.count {
                    // Changed line
                    prefix = "  "
                } else if i >= originalLines.count {
                    // Added line
                    prefix = "+ "
                } else {
                    // Deleted line
                    prefix = "- "
                }
            } else {
                prefix = "  "
            }

            let content = i < updatedLines.count ? updatedLines[i] : (i < originalLines.count ? originalLines[i] : "")
            result += String(format: "%4d\(prefix)%@\n", lineNum, content)
        }

        let addedLines = updatedLines.count - originalLines.count
        let summary: String
        if addedLines > 0 {
            summary = "(\(addedLines) line\(addedLines == 1 ? "" : "s") added)"
        } else if addedLines < 0 {
            summary = "(\(-addedLines) line\(-addedLines == 1 ? "" : "s") removed)"
        } else {
            summary = "(lines modified in place)"
        }

        return "```\n\(result)```\n\(summary)"
    }
}
