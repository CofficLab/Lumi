import Foundation

public enum WorkspaceFileEditOutcome: Equatable {
    case createdNewFile(path: String)
    case wroteEmptyFile(path: String)
    case updated(path: String, matchCount: Int, replaceAll: Bool, diff: String)
}

public struct WorkspaceFileEditor: Sendable {
    public init() {}

    public func edit(filePath: String, oldString: String, newString: String, replaceAll: Bool = false) throws -> WorkspaceFileEditOutcome {
        let fileURL = WorkspacePathResolver.fileURL(from: filePath)
        let resolvedPath = fileURL.path

        guard oldString != newString else {
            throw WorkspaceFileError("No changes to make — old_string and new_string are exactly the same.")
        }

        let fileManager = FileManager.default
        var originalContent = ""
        var originalEncoding = String.Encoding.utf8
        var fileExists = false
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                throw WorkspaceFileError("Path is a directory, not a file: \(resolvedPath)")
            }

            var detectedEncoding = String.Encoding.utf8
            do {
                originalContent = try String(contentsOf: fileURL, usedEncoding: &detectedEncoding)
                originalEncoding = detectedEncoding
            } catch {
                throw WorkspaceFileError("File content is not valid text.")
            }
            fileExists = true
        }

        if !fileExists {
            guard oldString.isEmpty else {
                throw WorkspaceFileError("File does not exist: \(filePath). To create a new file, use an empty old_string.")
            }

            let directoryURL = fileURL.deletingLastPathComponent()
            isDirectory = false
            if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
                guard isDirectory.boolValue else {
                    throw WorkspaceFileError("Parent path is not a directory: \(directoryURL.path)")
                }
            } else {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            try newString.write(to: fileURL, atomically: true, encoding: .utf8)
            return .createdNewFile(path: filePath)
        }

        if oldString.isEmpty {
            guard originalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WorkspaceFileError("Cannot create new file — file already exists and has content.")
            }

            try newString.write(to: fileURL, atomically: true, encoding: originalEncoding)
            return .wroteEmptyFile(path: filePath)
        }

        guard let matched = findActualString(in: originalContent, searchFor: oldString) else {
            let snippet = oldString.count > 200 ? String(oldString.prefix(200)) + "..." : oldString
            throw WorkspaceFileError("String to replace not found in file.\nString: \(snippet)")
        }

        let matchCount = countOccurrences(of: matched, in: originalContent)
        if matchCount > 1 && !replaceAll {
            throw WorkspaceFileError("Found \(matchCount) matches of the string to replace, but replace_all is false. To replace all occurrences, set replace_all to true. To replace only one occurrence, please provide more context to uniquely identify the instance.")
        }

        let replacement = adaptReplacementLineEndings(newString, toMatch: matched)
        let updatedContent: String
        if replaceAll {
            updatedContent = originalContent.replacingOccurrences(of: matched, with: replacement)
        } else if let range = originalContent.range(of: matched) {
            updatedContent = originalContent.replacingCharacters(in: range, with: replacement)
        } else {
            throw WorkspaceFileError("Failed to apply replacement.")
        }

        guard updatedContent != originalContent else {
            throw WorkspaceFileError("Replacement produced no changes.")
        }

        try updatedContent.write(to: fileURL, atomically: true, encoding: originalEncoding)

        let diff = generateDiffSummary(original: originalContent, updated: updatedContent)
        return .updated(path: filePath, matchCount: matchCount, replaceAll: replaceAll, diff: diff)
    }

    private func findActualString(in content: String, searchFor: String) -> String? {
        let candidates = searchCandidates(for: searchFor, in: content)

        for candidate in candidates where content.contains(candidate) {
            return candidate
        }

        let normalizedContent = normalizeQuotes(content)

        for candidate in candidates {
            let normalizedSearch = normalizeQuotes(candidate)
            if let range = normalizedContent.range(of: normalizedSearch) {
                let nsContent = content as NSString
                let nsRange = NSRange(range, in: content)
                if nsRange.location != NSNotFound && nsRange.location + nsRange.length <= nsContent.length {
                    return nsContent.substring(with: nsRange)
                }
            }
        }

        return nil
    }

    private func normalizeQuotes(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
    }

    private func searchCandidates(for search: String, in content: String) -> [String] {
        var candidates = [search]
        if let lineEnding = preferredLineEnding(in: content) {
            let adaptedSearch = normalizeLineEndings(search, to: lineEnding)
            if adaptedSearch != search {
                candidates.append(adaptedSearch)
            }
        }
        return candidates
    }

    private func adaptReplacementLineEndings(_ replacement: String, toMatch matched: String) -> String {
        guard let lineEnding = preferredLineEnding(in: matched) else { return replacement }
        return normalizeLineEndings(replacement, to: lineEnding)
    }

    private func preferredLineEnding(in text: String) -> String? {
        if text.contains("\r\n") { return "\r\n" }
        if text.contains("\n") { return "\n" }
        if text.contains("\r") { return "\r" }
        return nil
    }

    private func normalizeLineEndings(_ text: String, to lineEnding: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: lineEnding)
    }

    private func countOccurrences(of substring: String, in string: String) -> Int {
        var count = 0
        var searchStart = string.startIndex
        while let range = string.range(of: substring, range: searchStart..<string.endIndex) {
            count += 1
            searchStart = range.upperBound
        }
        return count
    }

    private func generateDiffSummary(original: String, updated: String) -> String {
        let originalLines = normalizeLineEndings(original, to: "\n").components(separatedBy: "\n")
        let updatedLines = normalizeLineEndings(updated, to: "\n").components(separatedBy: "\n")

        var firstChange = -1
        var lastChange = -1

        let maxLines = max(originalLines.count, updatedLines.count)
        for i in 0..<maxLines {
            let originalLine = i < originalLines.count ? originalLines[i] : nil
            let updatedLine = i < updatedLines.count ? updatedLines[i] : nil
            if originalLine != updatedLine {
                if firstChange == -1 { firstChange = i }
                lastChange = i
            }
        }

        guard firstChange != -1 else {
            return "(No visible changes in diff)"
        }

        let contextLines = 2
        let startLine = max(0, firstChange - contextLines)
        let endLine = min(updatedLines.count - 1, lastChange + contextLines)

        var result = ""
        for i in startLine...endLine {
            let lineNum = i + 1
            let prefix: String
            let originalLine = i < originalLines.count ? originalLines[i] : nil
            let updatedLine = i < updatedLines.count ? updatedLines[i] : nil

            if originalLine != updatedLine {
                if originalLine != nil, i < updatedLines.count {
                    prefix = "  "
                } else if i >= originalLines.count {
                    prefix = "+ "
                } else {
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
