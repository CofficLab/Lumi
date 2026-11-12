import Foundation

public struct RAGGrepMatch: Sendable, Equatable {
    public let filePath: String
    public let lineNumber: Int
    public let text: String
    public let isContext: Bool

    public init(filePath: String, lineNumber: Int, text: String, isContext: Bool) {
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.text = text
        self.isContext = isContext
    }
}

public struct RAGGrepOutcome: Sendable {
    /// 按 ripgrep 输出顺序保留的命中（含上下文行），匹配行不超过 maxResults。
    public let matches: [RAGGrepMatch]
    /// 全部匹配行数量（不受 maxResults 截断影响），用于截断标记。
    public let totalMatchCount: Int

    public init(matches: [RAGGrepMatch], totalMatchCount: Int) {
        self.matches = matches
        self.totalMatchCount = totalMatchCount
    }
}

public enum RAGGrepError: LocalizedError, Sendable {
    case ripgrepUnavailable
    case searchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .ripgrepUnavailable:
            return "ripgrep executable is unavailable; the bundled copy may be missing."
        case let .searchFailed(detail):
            return "grep failed: \(detail)"
        }
    }
}

/// grep 工具的内容搜索层：忠实执行用户正则，不做查询词提取或打分。
///
/// 与 `RAGLexicalFileSearcher` 分离：后者服务于语义兜底的「提取词 + 打分」，
/// 这里必须原样传递正则。不依赖索引，`--no-ignore` 与索引扫描看到同一组文件
/// （回归 #1113）。rg 缺失时显式报错，不做静默回退。
public enum RAGGrepSearcher {
    public static let maxOutputBytes = 20_000

    public static func search(
        pattern: String,
        projectPath: String,
        glob: String? = nil,
        caseInsensitive: Bool = false,
        maxResults: Int = 100,
        contextLines: Int = 0,
        ripgrepURL: URL? = nil
    ) throws -> RAGGrepOutcome {
        let executable = ripgrepURL ?? RAGRipgrepLocator.executable()
        guard let executable, FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw RAGGrepError.ripgrepUnavailable
        }

        var arguments = [
            "--json",
            "--no-heading",
            "--no-ignore",
            "--color", "never",
            "--max-filesize", "1500K",
        ]
        if caseInsensitive { arguments.append("-i") }
        if contextLines > 0 { arguments.append(contentsOf: ["-C", String(contextLines)]) }
        if let glob, !glob.isEmpty { arguments.append(contentsOf: ["--glob", glob]) }
        for directory in RAGFileScanner.grepExcludeDirPatterns {
            arguments.append(contentsOf: ["--glob", "!\(directory)/**"])
        }
        arguments.append(contentsOf: ["--regexp", pattern, projectPath])

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        // 确定性回收管道 fd，避免热路径上依赖 autorelease pool 造成 fd 泄漏。
        defer {
            try? outputPipe.fileHandleForReading.close()
            try? outputPipe.fileHandleForWriting.close()
            try? errorPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForWriting.close()
        }

        do {
            try process.run()
        } catch {
            throw RAGGrepError.searchFailed(error.localizedDescription)
        }
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try Task.checkCancellation()

        // rg 的 1 表示“没有匹配”，大于 1 才是执行错误（含非法正则）。
        let status = process.terminationStatus
        guard status == 0 || status == 1 else {
            let detail = String(decoding: errorOutput, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw RAGGrepError.searchFailed(detail.isEmpty ? "ripgrep exited with status \(status)" : detail)
        }

        var events: [RAGGrepMatch] = []
        for rawLine in String(decoding: output, as: UTF8.self).split(separator: "\n") {
            guard let event = try? JSONSerialization.jsonObject(with: Data(rawLine.utf8)) as? [String: Any],
                  let eventType = event["type"] as? String,
                  eventType == "match" || eventType == "context",
                  let data = event["data"] as? [String: Any],
                  let path = (data["path"] as? [String: Any])?["text"] as? String,
                  let lineNumber = data["line_number"] as? Int,
                  let line = (data["lines"] as? [String: Any])?["text"] as? String else {
                continue
            }
            events.append(RAGGrepMatch(
                filePath: path,
                lineNumber: lineNumber,
                text: line.trimmingCharacters(in: .newlines),
                isContext: eventType == "context"
            ))
        }

        var kept: [RAGGrepMatch] = []
        var keptMatchCount = 0
        var totalMatchCount = 0
        var capFile: String?
        var capLine = 0
        for event in events {
            if event.isContext {
                if capFile == nil {
                    kept.append(event)
                } else if event.filePath == capFile, event.lineNumber <= capLine + contextLines {
                    kept.append(event)
                }
                continue
            }
            totalMatchCount += 1
            guard capFile == nil else { continue }
            kept.append(event)
            keptMatchCount += 1
            if keptMatchCount >= maxResults {
                capFile = event.filePath
                capLine = event.lineNumber
            }
        }

        return RAGGrepOutcome(matches: kept, totalMatchCount: totalMatchCount)
    }

    /// 输出 `path:line:content`（上下文行用 `-` 分隔），总字节不超过 maxBytes。
    /// 截断时附 `[truncated: N more matches; ...]`，N 为未展示的匹配行数。
    public static func formatOutput(
        _ outcome: RAGGrepOutcome,
        projectPath: String,
        maxBytes: Int = maxOutputBytes
    ) -> String {
        guard !outcome.matches.isEmpty else { return "" }

        let lines = outcome.matches.map { match -> String in
            let source = RAGPathUtils.displayPath(filePath: match.filePath, projectPath: projectPath)
            let separator = match.isContext ? "-" : ":"
            return "\(source)\(separator)\(match.lineNumber)\(separator)\(match.text)"
        }
        let keptMatchCount = outcome.matches.lazy.filter { !$0.isContext }.count
        var fullBytes = 0
        for (index, line) in lines.enumerated() {
            fullBytes += line.utf8.count + (index == 0 ? 0 : 1)
        }
        let needsMarker = outcome.totalMatchCount > keptMatchCount || fullBytes > maxBytes
        // 预留最坏情况标记（一条都没展示时 remaining == totalMatchCount）。
        let reserve = needsMarker ? truncationMarker(remaining: outcome.totalMatchCount).utf8.count + 1 : 0

        var shown: [String] = []
        var used = 0
        var shownMatches = 0
        for (index, line) in lines.enumerated() {
            let cost = line.utf8.count + (index == 0 ? 0 : 1)
            if used + cost > maxBytes - reserve { break }
            shown.append(line)
            used += cost
            if !outcome.matches[index].isContext { shownMatches += 1 }
        }

        var output = shown.joined(separator: "\n")
        let remaining = outcome.totalMatchCount - shownMatches
        if remaining > 0 {
            output += "\n" + truncationMarker(remaining: remaining)
        }
        return output
    }

    private static func truncationMarker(remaining: Int) -> String {
        "[truncated: \(remaining) more matches; narrow the pattern or use glob]"
    }
}