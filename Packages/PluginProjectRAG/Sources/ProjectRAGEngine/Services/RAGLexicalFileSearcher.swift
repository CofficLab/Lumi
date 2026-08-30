import Foundation

/// 在语义索引没有返回结果时，直接从项目文件中寻找词法命中。
///
/// 这是首次查询和索引更新期间的兜底路径，不写入 SQLite，也不生成 embedding。
public enum RAGLexicalFileSearcher {
    private static let maxFilesToInspect = 2_000
    private static let contextLineCount = 8

    private struct Snippet {
        let content: String
        let lineRange: RAGLineRange
    }

    public static func search(
        query: String,
        projectPath: String,
        topK: Int
    ) throws -> [RAGSearchResult] {
        let terms = RAGTextUtils.tokenize(query.lowercased())
        guard !terms.isEmpty else { return [] }

        if let ripgrepResults = try searchWithRipgrep(query: query, terms: terms, projectPath: projectPath, topK: topK),
           !ripgrepResults.isEmpty {
            return ripgrepResults
        }

        let files = RAGFileScanner.discoverFilesCached(in: projectPath)
        var matches: [(filePath: String, score: Float, snippet: Snippet)] = []
        matches.reserveCapacity(min(files.count, max(topK, 1)))

        for filePath in files.prefix(maxFilesToInspect) {
            try Task.checkCancellation()
            guard let content = try? RAGTextFileReader.read(path: filePath) else { continue }

            let contentScore = RAGTextUtils.lexicalBoost(query: query, content: content)
            let pathScore = RAGTextUtils.sourcePathBoost(queryTerms: terms, filePath: filePath)
            guard contentScore > 0 || pathScore > 0 else { continue }

            let score = contentScore * 0.85 + pathScore * 0.15
            matches.append((filePath, score, makeSnippet(content: content, terms: terms)))
        }

        return matches
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.filePath < $1.filePath
            }
            .prefix(max(topK, 1))
            .map {
                RAGSearchResult(
                    content: $0.snippet.content,
                    source: RAGPathUtils.displayPath(filePath: $0.filePath, projectPath: projectPath),
                    score: $0.score,
                    matchKind: .filesystemLexical,
                    lineRange: $0.snippet.lineRange
                )
            }
    }

    /// 优先使用 ripgrep 的 JSON 输出，避免为了找一行命中而读取整个项目的所有文件。
    /// 返回 nil 表示 ripgrep 不可用或执行失败，此时由调用方走文件扫描回退。
    private static func searchWithRipgrep(
        query: String,
        terms: [String],
        projectPath: String,
        topK: Int
    ) throws -> [RAGSearchResult]? {
        guard let executable = ripgrepExecutable() else { return nil }

        let pattern = "(?i)(\(terms.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")))"
        var arguments = [
            "--json",
            "--no-heading",
            "--color", "never",
            "--max-count", "3",
            "--max-filesize", "1500K",
        ]
        for fileExtension in RAGFileScanner.allowedExtensions {
            arguments.append(contentsOf: ["--glob", "*.\(fileExtension)"])
        }
        for directory in RAGFileScanner.grepExcludeDirPatterns {
            arguments.append(contentsOf: ["--glob", "!\(directory)/**"])
        }
        arguments.append(contentsOf: ["--regexp", pattern, projectPath])

        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try Task.checkCancellation()

        // rg 的 1 表示“没有匹配”，大于 1 才是执行错误。
        guard process.terminationStatus == 0 || process.terminationStatus == 1 else { return nil }

        struct Match {
            let filePath: String
            let lineNumber: Int
            let line: String
            let score: Float
        }
        var bestByFile: [String: Match] = [:]
        let queryTerms = terms.map { $0.lowercased() }

        for rawLine in String(decoding: output, as: UTF8.self).split(separator: "\n") {
            guard let event = try? JSONSerialization.jsonObject(with: Data(rawLine.utf8)) as? [String: Any],
                  event["type"] as? String == "match",
                  let data = event["data"] as? [String: Any],
                  let path = (data["path"] as? [String: Any])?["text"] as? String,
                  let lineNumber = data["line_number"] as? Int,
                  let line = (data["lines"] as? [String: Any])?["text"] as? String else {
                continue
            }
            let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
            guard RAGFileScanner.allowedExtensions.contains(fileExtension),
                  !RAGFileScanner.shouldSkipPath(path) else {
                continue
            }

            let cleanLine = line.trimmingCharacters(in: .newlines)
            let contentScore = RAGTextUtils.lexicalBoost(query: query, content: cleanLine)
            let pathScore = RAGTextUtils.sourcePathBoost(queryTerms: queryTerms, filePath: path)
            let score = contentScore * 0.85 + pathScore * 0.15
            let candidate = Match(
                filePath: path,
                lineNumber: lineNumber,
                line: cleanLine,
                score: score
            )
            if let current = bestByFile[path], current.score >= candidate.score { continue }
            bestByFile[path] = candidate
        }

        return bestByFile.values
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.filePath < $1.filePath
            }
            .prefix(max(topK, 1))
            .map {
                RAGSearchResult(
                    content: "\($0.lineNumber)\t\($0.line)",
                    source: RAGPathUtils.displayPath(filePath: $0.filePath, projectPath: projectPath),
                    score: $0.score,
                    matchKind: .filesystemLexical,
                    lineRange: RAGLineRange(startLine: $0.lineNumber, endLine: $0.lineNumber)
                )
            }
    }

    private static func ripgrepExecutable() -> URL? {
        let pathEntries = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        let candidates = pathEntries.map { "\($0)/rg" } + [
            "/opt/homebrew/bin/rg",
            "/usr/local/bin/rg",
            "/usr/bin/rg",
        ]
        return candidates.lazy
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func makeSnippet(content: String, terms: [String]) -> Snippet {
        let lines = content.components(separatedBy: "\n")
        let lowerTerms = terms.map { $0.lowercased() }
        let firstMatch = lines.firstIndex { line in
            let lowerLine = line.lowercased()
            return lowerTerms.contains { lowerLine.contains($0) }
        } ?? 0
        let start = max(firstMatch - contextLineCount / 2, 0)
        let end = min(start + contextLineCount, lines.count)

        let snippet = lines[start..<end].enumerated()
            .map { "\(start + $0.offset + 1)\t\($0.element)" }
            .joined(separator: "\n")
        return Snippet(
            content: snippet,
            lineRange: RAGLineRange(startLine: start + 1, endLine: max(start + 1, end))
        )
    }
}
