import Foundation

public enum WorkspaceFileEditOutcome: Equatable {
    case createdNewFile(path: String)
    case wroteEmptyFile(path: String)
    case updated(path: String, matchCount: Int, replaceAll: Bool, diff: String)
}

/// 「已读取文件」快照，用于在编辑前做乐观并发控制。
///
/// 记录某文件被 `read_file` 读取时的修改时间戳，编辑时若磁盘上的实际修改时间晚于该值，
/// 说明文件在读取之后被外部（用户、linter、云同步等）改动，应拒绝编辑并提示重新读取，
/// 避免基于过期内容盲目覆盖。
public struct WorkspaceReadFileSnapshot: Sendable, Equatable {
    public let modificationDate: Date
    public init(modificationDate: Date) {
        self.modificationDate = modificationDate
    }
}

/// 会话级「已读取文件」状态记录。
///
/// 以 `(conversationID, normalizedPath)` 为键保存最近一次读取快照。
/// `read_file` 工具在读取成功后记录，`edit_file` 工具在编辑前查询，实现：
/// 1. 先读后写的强制校验（可选，由调用方决定是否启用）
/// 2. 乐观并发控制（文件在读取后被外部修改则拒绝编辑）
public final class WorkspaceReadFileState: @unchecked Sendable {
    private struct Key: Hashable {
        let conversationID: UUID
        let path: String
    }

    private let lock = NSLock()
    private var snapshots: [Key: WorkspaceReadFileSnapshot] = [:]

    public init() {}

    /// 记录一次成功的文件读取。
    public func recordRead(conversationID: UUID, path: String, snapshot: WorkspaceReadFileSnapshot) {
        let key = Key(conversationID: conversationID, path: normalized(path))
        lock.lock(); defer { lock.unlock() }
        snapshots[key] = snapshot
    }

    /// 查询某文件在该会话中是否被读取过，以及当时的快照。
    public func snapshot(for conversationID: UUID, path: String) -> WorkspaceReadFileSnapshot? {
        let key = Key(conversationID: conversationID, path: normalized(path))
        lock.lock(); defer { lock.unlock() }
        return snapshots[key]
    }

    /// 清除某会话的全部记录（会话结束时调用，避免内存累积）。
    public func clear(conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        snapshots = snapshots.filter { $0.key.conversationID != conversationID }
    }

    private func normalized(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().standardizedFileURL
        var p = url.path
        if p.hasSuffix("/") { p.removeLast() }
        return p
    }
}

public struct WorkspaceFileEditor: Sendable {
    /// 单个编辑文件的大小上限（1GB），防止把超大文件整体读入内存导致 OOM。
    public static let maxFileSizeBytes: Int64 = 1_000_000_000

    public init() {}

    /// - Parameters:
    ///   - readState: 可选的「已读取文件」状态。提供时启用乐观并发控制——若文件在被读取后
    ///     被外部修改，编辑会被拒绝并提示重新读取。为 `nil` 时退回到旧行为（不做并发检查）。
    public func edit(
        filePath: String,
        oldString: String,
        newString: String,
        replaceAll: Bool = false,
        conversationID: UUID? = nil,
        readState: WorkspaceReadFileState? = nil
    ) throws -> WorkspaceFileEditOutcome {
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

            // 文件大小保护：限制编辑文件不超过 1GB，避免把超大文件整体读入内存导致 OOM。
            if let attrs = try? fileManager.attributesOfItem(atPath: resolvedPath),
               let size = attrs[.size] as? Int64,
               size > Self.maxFileSizeBytes {
                throw WorkspaceFileError("File is too large to edit safely (\(size) bytes; limit is \(Self.maxFileSizeBytes) bytes).")
            }

            // 乐观并发控制：如果该文件在本会话中被读取过，比对当时的修改时间戳。
            // 若磁盘上的修改时间晚于读取时间，说明文件被外部改动，拒绝覆盖。
            if let conversationID, let readState,
               let readSnapshot = readState.snapshot(for: conversationID, path: resolvedPath),
               let attrs = try? fileManager.attributesOfItem(atPath: resolvedPath),
               let currentMtime = attrs[.modificationDate] as? Date,
               currentMtime > readSnapshot.modificationDate {
                throw WorkspaceFileError(
                    "File was modified externally after it was last read (read at \(readSnapshot.modificationDate), now \(currentMtime)). Re-read the file before editing to avoid overwriting external changes."
                )
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
                throw WorkspaceFileError(missingFileMessage(filePath: filePath, fileURL: fileURL, fileManager: fileManager))
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

        // 先按文件既有换行风格适配，再按文件既有引号风格适配，保持文件风格一致。
        var replacement = adaptReplacementLineEndings(newString, toMatch: matched)
        replacement = preserveQuoteStyle(replacement, matching: matched)
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
            // range 的索引属于 normalizedContent，不能直接用 NSRange(_:in: content) 转换，
            // 否则索引错位会截取到错误的子串（例如尾部多/少一个字符）。
            // 弯引号 → 直引号的归一化逐字符 1:1，因此用字符距离在原文中定位等价区间。
            if let range = normalizedContent.range(of: normalizedSearch) {
                let lowerOffset = normalizedContent.distance(from: normalizedContent.startIndex, to: range.lowerBound)
                let length = normalizedContent.distance(from: range.lowerBound, to: range.upperBound)
                let originalChars = Array(content)
                guard lowerOffset + length <= originalChars.count else { continue }
                let matched = String(originalChars[lowerOffset..<(lowerOffset + length)])
                if content.contains(matched) {
                    return matched
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

    /// 将替换文本中的引号转换为文件既有风格（弯引号），保持文件风格一致。
    ///
    /// 匹配阶段做了「弯引号 → 直引号」的标准化以便定位，但写入时若文件原本用弯引号，
    /// 替换文本里的直引号也应转回弯引号，否则会把 `"it's"` 这类风格破坏掉。
    /// 仅当匹配到的原文确实使用弯引号时才做反向转换，避免误伤直引号文件。
    private func preserveQuoteStyle(_ replacement: String, matching matched: String) -> String {
        let hasLeftSingle = matched.contains("\u{2018}")
        let hasRightSingle = matched.contains("\u{2019}")
        let hasLeftDouble = matched.contains("\u{201C}")
        let hasRightDouble = matched.contains("\u{201D}")
        guard hasLeftSingle || hasRightSingle || hasLeftDouble || hasRightDouble else {
            return replacement
        }

        var result = replacement
        // 单引号：开撇号用于起始（如 'word），闭撇号多用于缩写（如 don't）。
        // 这里用简单的成对替换：首个 ' → 开撇号，后续交替，保证缩写（don't）也得到弯撇号。
        if hasRightSingle {
            result = replaceStraightQuotes(result, straight: "'", open: "\u{2018}", close: "\u{2019}")
        }
        if hasLeftDouble || hasRightDouble {
            result = replaceStraightQuotes(result, straight: "\"", open: "\u{201C}", close: "\u{201D}")
        }
        return result
    }

    /// 把成对的直引号交替替换为开/闭弯引号。
    private func replaceStraightQuotes(_ string: String, straight: String, open: String, close: String) -> String {
        var output = ""
        output.reserveCapacity(string.count)
        var isOpen = true
        for char in string {
            if String(char) == straight {
                output.append(isOpen ? open : close)
                isOpen.toggle()
            } else {
                output.append(char)
            }
        }
        return output
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

    /// 构造「文件不存在」错误信息，并在能找到相近文件名时追加 "Did you mean X?" 提示。
    ///
    /// 列出目标目录的同级文件，按归一化编辑距离排序取最接近的一个。仅返回显著接近的
    /// 建议（距离阈值过滤），避免对完全无关的目录给出噪音提示。
    private func missingFileMessage(filePath: String, fileURL: URL, fileManager: FileManager) -> String {
        let base = "File does not exist: \(filePath). To create a new file, use an empty old_string."

        let targetName = fileURL.lastPathComponent.lowercased()
        guard !targetName.isEmpty else { return base }

        let directoryURL = fileURL.deletingLastPathComponent()
        guard let siblings = try? fileManager.contentsOfDirectory(atPath: directoryURL.path),
              !siblings.isEmpty else {
            return base
        }

        // 仅在同级文件中找最接近的；忽略隐藏文件和目录，聚焦真实候选
        let candidates = siblings.filter { name in
            !name.hasPrefix(".") && isRegularFile(name: name, in: directoryURL, fileManager: fileManager)
        }
        guard !candidates.isEmpty else { return base }

        let best = candidates
            .map { ($0, Self.editDistance(targetName, $0.lowercased())) }
            .min { $0.1 < $1.1 }

        // 阈值：编辑距离不超过较短文件名长度的 60%，且绝对值不超过 6，避免无意义建议。
        // 例如 Foo.swift → FooTests.swift 距离 5，较短名 9 字符，5 ≤ 9*0.6=5.4 → 给出建议。
        if let best, best.1 > 0 {
            let shorter = min(targetName.count, best.0.count)
            let relativeLimit = Int(Double(shorter) * 0.6)
            let limit = max(1, min(6, relativeLimit))
            if best.1 <= limit {
                let suggestedPath = (directoryURL.appendingPathComponent(best.0)).path
                return base + " Did you mean \"\(best.0)\" (\(suggestedPath))?"
            }
        }
        return base
    }

    private func isRegularFile(name: String, in directory: URL, fileManager: FileManager) -> Bool {
        var isDir: ObjCBool = false
        let path = directory.appendingPathComponent(name).path
        return fileManager.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
    }

    /// 经典 Levenshtein 编辑距离（不区分大小写由调用方保证），用于「相似文件名」排序。
    static func editDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a), bChars = Array(b)
        let n = aChars.count, m = bChars.count
        if n == 0 { return m }
        if m == 0 { return n }

        var prev = Array(0...m)
        var curr = [Int](repeating: 0, count: m + 1)
        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[m]
    }

    /// 生成 unified 风格的 diff 摘要。
    ///
    /// 改进的逐行比较：对每个变更行同时输出「- 旧行」和「+ 新行」，纯新增行只输出「+」，
    /// 纯删除行只输出「-」，未变行作为上下文输出空格前缀。这修正了旧实现里把原地修改
    /// 的行误标为「  」（无标记）的问题，让 diff 能正确显示删除与新增内容。
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
        let endLine = min(maxLines - 1, lastChange + contextLines)

        var result = ""
        for i in startLine...endLine {
            let originalLine = i < originalLines.count ? originalLines[i] : nil
            let updatedLine = i < updatedLines.count ? updatedLines[i] : nil

            if originalLine == updatedLine {
                // 上下文行（两侧都存在且相同）
                let lineNum = min(i + 1, max(originalLines.count, updatedLines.count))
                let content = updatedLine ?? originalLine ?? ""
                result += String(format: "%4d  %@\n", lineNum, content)
            } else {
                // 旧行存在 → 输出删除行
                if let originalLine {
                    result += String(format: "%4d- %@\n", i + 1, originalLine)
                }
                // 新行存在 → 输出新增行
                if let updatedLine {
                    result += String(format: "%4d+ %@\n", i + 1, updatedLine)
                }
            }
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
