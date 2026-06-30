import AgentToolKit
import Foundation
import SuperLogKit

public struct RAGCodeSearchTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "RAG"
    public nonisolated static let verbose: Bool = false

    /// 默认返回结果数量
    static let defaultTopK = 8

    /// 最少返回结果数量
    static let minTopK = 1

    /// 最多返回结果数量
    static let maxTopK = 20

    /// 默认超时时间（秒）
    static let defaultTimeoutSeconds: TimeInterval = 15

    /// 最小容忍超时时间（秒）
    static let minTimeoutSeconds: TimeInterval = 1

    /// 最大容忍超时时间（秒）
    static let maxTimeoutSeconds: TimeInterval = 60

    public let name = "search_code"

    struct CapturedProcessOutput: Sendable, Equatable {
        let terminationStatus: Int32
        let stdout: Data
    }

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            在当前项目中搜索代码片段。适合查找符号、错误字符串、文件路径、实现位置，或按自然语言描述检索相关代码。

            默认使用 hybrid 模式：结合精确关键字搜索和 RAG 语义检索。keyword 模式不依赖索引；semantic 模式依赖 RAG 索引。

            可通过 `timeout` 参数设置最大容忍等待时间（默认 15 秒，最大 60 秒），超时后返回已收集到的部分结果。
            """
        case .english:
            return """
            Search code snippets in the current project. Use this to find symbols, error strings, file paths, implementation locations, or code related to a natural-language query.

            The default hybrid mode combines exact keyword search with RAG semantic retrieval. Keyword mode does not require an index; semantic mode uses the RAG index.

            Use the `timeout` parameter to set a maximum tolerable wait time (default 15s, max 60s). Partial results collected so far are returned on timeout.
            """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let queryDescription: String
        let modeDescription: String
        let topKDescription: String
        let pathFilterDescription: String
        let projectPathDescription: String
        let timeoutDescription: String

        switch language {
        case .chinese:
            queryDescription = "要搜索的关键字、符号名、错误文本或自然语言问题。"
            modeDescription = "搜索模式。keyword 为精确文本搜索，semantic 为 RAG 语义检索，hybrid 会合并两者。默认 hybrid。"
            topKDescription = "最多返回多少条结果，默认 8，范围 1-20。"
            pathFilterDescription = "可选，仅返回路径中包含该字符串的文件。"
            projectPathDescription = "可选，项目根路径。默认使用当前会话的项目路径。"
            timeoutDescription = "可选，最大容忍等待时间（秒）。默认 15，范围 1-60。超时后返回已收集到的部分结果。"
        case .english:
            queryDescription = "Keyword, symbol name, error text, or natural-language question to search for."
            modeDescription = "Search mode. keyword performs exact text search, semantic uses RAG retrieval, and hybrid merges both. Defaults to hybrid."
            topKDescription = "Maximum number of results to return. Defaults to 8, range 1-20."
            pathFilterDescription = "Optional path substring filter."
            projectPathDescription = "Optional project root path. Defaults to the current session project path."
            timeoutDescription = "Optional max tolerable wait time in seconds. Default 15, range 1-60. Returns partial results on timeout."
        }

        return [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": queryDescription,
                ],
                "mode": [
                    "type": "string",
                    "enum": ["hybrid", "keyword", "semantic"],
                    "description": modeDescription,
                ],
                "topK": [
                    "type": "integer",
                    "description": topKDescription,
                    "minimum": Self.minTopK,
                    "maximum": Self.maxTopK,
                ],
                "pathFilter": [
                    "type": "string",
                    "description": pathFilterDescription,
                ],
                "projectPath": [
                    "type": "string",
                    "description": projectPathDescription,
                ],
                "timeout": [
                    "type": "integer",
                    "description": timeoutDescription,
                    "minimum": Int(Self.minTimeoutSeconds),
                    "maximum": Int(Self.maxTimeoutSeconds),
                ],
            ],
            "required": ["query"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let query = (arguments["query"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let preview = query.isEmpty ? "code" : String(query.prefix(40))
        return "Search code: \(preview)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let rawQuery = arguments["query"]?.value as? String else {
            return "## Code Search\n\nMissing required `query` parameter."
        }

        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return "## Code Search\n\n`query` must not be empty."
        }

        let mode = SearchMode(rawValue: (arguments["mode"]?.value as? String)?.lowercased() ?? "") ?? .hybrid
        let topK = Self.normalizedTopK(arguments["topK"]?.value)
        let pathFilter = trimmedNonEmpty(arguments["pathFilter"]?.value as? String)
        let timeoutSeconds = Self.normalizedTimeout(arguments["timeout"]?.value)

        guard let projectPath = resolveProjectPath(arguments: arguments, context: context) else {
            return """
            ## Code Search

            No project path is available. Open or select a project, or pass `projectPath`.
            """
        }

        if !context.isPathAllowed(projectPath) {
            return """
            ## Code Search

            Refusing to search outside the allowed project directories.

            Path: `\(projectPath)`
            """
        }

        // 使用带超时的并发搜索
        let deadline = CFAbsoluteTimeGetCurrent() + timeoutSeconds

        let keywordTask: Task<[CodeSearchResult], Never>? = mode.includesKeyword
            ? Task.detached(priority: .utility) {
                await self.keywordSearchWithTimeout(
                    query: query,
                    projectPath: projectPath,
                    pathFilter: pathFilter,
                    limit: topK,
                    context: context
                )
            }
            : nil

        let semanticTask: Task<[CodeSearchResult], Never>? = mode.includesSemantic
            ? Task(priority: .utility) {
                await self.semanticSearch(
                    query: query,
                    projectPath: projectPath,
                    pathFilter: pathFilter,
                    limit: topK
                )
            }
            : nil

        // 带超时收集结果
        var results: [CodeSearchResult] = []
        var timedOut = false

        // 收集 keyword 结果
        if let keywordTask {
            let remaining = max(deadline - CFAbsoluteTimeGetCurrent(), 0)
            let keywordResult = await RAGTimeout.withTimeout(seconds: remaining) {
                await keywordTask.value
            }
            switch keywordResult {
            case .success(let hits):
                results.append(contentsOf: hits)
            case .timedOut:
                timedOut = true
                keywordTask.cancel()
            }
        }

        // 收集 semantic 结果
        if let semanticTask {
            let remaining = max(deadline - CFAbsoluteTimeGetCurrent(), 0)
            let semanticResult = await RAGTimeout.withTimeout(seconds: remaining) {
                await semanticTask.value
            }
            switch semanticResult {
            case .success(let hits):
                results.append(contentsOf: hits)
            case .timedOut:
                timedOut = true
                semanticTask.cancel()
            }
        }

        try context.checkCancellation()
        let merged = mergeResults(results, limit: topK)
        return render(results: merged, query: query, mode: mode, projectPath: projectPath, timedOut: timedOut, timeoutSeconds: timeoutSeconds)
    }

    // MARK: - Keyword Search (grep-based)

    /// 使用系统 grep 进行关键字搜索，带超时保护
    private func keywordSearchWithTimeout(
        query: String,
        projectPath: String,
        pathFilter: String?,
        limit: Int,
        context: ToolExecutionContext
    ) async -> [CodeSearchResult] {
        let keywordStart = CFAbsoluteTimeGetCurrent()
        // 优先使用 grep，失败时回退到 Swift 逐文件搜索
        if let grepResults = try? grepSearch(
            query: query,
            projectPath: projectPath,
            pathFilter: pathFilter,
            limit: limit
        ) {
            guard grepResults.count < limit else {
                logKeywordTiming(start: keywordStart, count: grepResults.count, mode: "grep(capped)")
                return grepResults
            }
            let fallbackResults = swiftFallbackSearch(
                query: query,
                projectPath: projectPath,
                pathFilter: pathFilter,
                limit: limit,
                context: context
            )
            let merged = mergeResults(grepResults + fallbackResults, limit: limit)
            logKeywordTiming(start: keywordStart, count: merged.count, mode: "grep+fallback")
            return merged
        }

        // 回退：逐文件搜索
        let fallbackResults = swiftFallbackSearch(
            query: query,
            projectPath: projectPath,
            pathFilter: pathFilter,
            limit: limit,
            context: context
        )
        logKeywordTiming(start: keywordStart, count: fallbackResults.count, mode: "swift-fallback")
        return fallbackResults
    }

    /// 记录 keyword 搜索耗时；超过 5 秒时升级为 warning，便于定位性能问题。
    private func logKeywordTiming(start: CFAbsoluteTime, count: Int, mode: String) {
        let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let durationSec = durationMs / 1000
        if durationSec > 5 {
            RAGPlugin.logger.error("\(Self.t)search_code keyword 搜索耗时过长：\(String(format: "%.2f", durationMs))ms, 结果数：\(count), 模式：\(mode)")
        } else {
            RAGPlugin.logger.info("\(Self.t)search_code keyword 搜索耗时：\(String(format: "%.2f", durationMs))ms, 结果数：\(count), 模式：\(mode)")
        }
    }

    /// 使用系统 grep 进行快速搜索
    private func grepSearch(
        query: String,
        projectPath: String,
        pathFilter: String?,
        limit: Int
    ) throws -> [CodeSearchResult]? {
        let arguments = [
            "-rnIi",
            "--max-count=\(limit)",
        ]
        + RAGFileScanner.grepExcludeDirPatterns.map { "--exclude-dir=\($0)" }
        + RAGFileScanner.allowedExtensions.map { "--include=*.\($0)" }
        + [
            "--",
            query,
            projectPath,
        ]

        guard let result = try Self.runProcessCapturingStdout(
            executableURL: URL(fileURLWithPath: "/usr/bin/grep"),
            arguments: arguments,
            timeout: 10,
            qualityOfService: .utility
        ) else {
            return nil
        }

        guard let output = String(data: result.stdout, encoding: .utf8), !output.isEmpty else {
            return []
        }

        let filteredOutput: String
        if let pathFilter {
            filteredOutput = output
                .components(separatedBy: .newlines)
                .filter { $0.localizedCaseInsensitiveContains(pathFilter) }
                .prefix(limit * 3)
                .joined(separator: "\n")
        } else {
            filteredOutput = output
                .components(separatedBy: .newlines)
                .prefix(limit * 3)
                .joined(separator: "\n")
        }

        return parseGrepOutput(filteredOutput, projectPath: projectPath, limit: limit)
    }

    static func runProcessCapturingStdout(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval,
        qualityOfService: QualityOfService? = nil
    ) throws -> CapturedProcessOutput? {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let qualityOfService {
            process.qualityOfService = qualityOfService
        }

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiRAGProcess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let stdoutURL = outputDirectory.appendingPathComponent("stdout.log")
        try Data().write(to: stdoutURL)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        process.standardOutput = stdoutHandle
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            try? stdoutHandle.close()
            throw error
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if process.isRunning {
            process.terminate()
            try? stdoutHandle.close()
            return nil
        }

        try? stdoutHandle.close()
        return CapturedProcessOutput(
            terminationStatus: process.terminationStatus,
            stdout: (try? Data(contentsOf: stdoutURL)) ?? Data()
        )
    }

    /// 解析 grep -rn 输出为 CodeSearchResult
    private func parseGrepOutput(_ output: String, projectPath: String, limit: Int) -> [CodeSearchResult] {
        var results: [CodeSearchResult] = []
        var fileLines: [String: [(Int, String)]] = [:]

        for line in output.components(separatedBy: "\n") {
            guard !line.isEmpty else { continue }
            // grep -rn 格式: filepath:linenum:content
            let parts = line.split(separator: ":", maxSplits: 2)
            guard parts.count >= 3,
                  let lineNum = Int(parts[1]) else { continue }

            let filePath = String(parts[0])
            let content = String(parts[2])

            if fileLines[filePath] == nil {
                fileLines[filePath] = []
            }
            fileLines[filePath]?.append((lineNum, content))
        }

        for (filePath, matches) in fileLines {
            guard results.count < limit else { break }
            guard let firstMatch = matches.first else { continue }

            let displayPath = RAGPathUtils.displayPath(filePath: filePath, projectPath: projectPath)
            let snippet = matches.prefix(5).map { "\($0.0): \($0.1)" }.joined(separator: "\n")

            results.append(CodeSearchResult(
                source: displayPath,
                line: firstMatch.0,
                content: snippet,
                score: 1,
                origin: .keyword
            ))
        }

        return results
    }

    /// Swift 回退搜索（grep 不可用时）
    private func swiftFallbackSearch(
        query: String,
        projectPath: String,
        pathFilter: String?,
        limit: Int,
        context: ToolExecutionContext
    ) -> [CodeSearchResult] {
        let lowerQuery = query.lowercased()
        let files = RAGFileScanner.discoverFilesCached(in: projectPath)
            .filter { filePath in
                guard let pathFilter else { return true }
                return filePath.localizedCaseInsensitiveContains(pathFilter)
            }

        var matches: [CodeSearchResult] = []
        matches.reserveCapacity(limit)

        for filePath in files {
            if Task.isCancelled { break }
            guard matches.count < limit else { break }
            guard let content = try? RAGTextFileReader.read(path: filePath) else { continue }
            guard let matchRange = content.range(of: lowerQuery, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }

            let lineNumber = lineNumber(in: content, at: matchRange.lowerBound)
            matches.append(CodeSearchResult(
                source: RAGPathUtils.displayPath(filePath: filePath, projectPath: projectPath),
                line: lineNumber,
                content: snippet(from: content, around: matchRange),
                score: 1,
                origin: .keyword
            ))
        }

        return matches
    }

    // MARK: - Semantic Search (with timeout & non-blocking check)

    /// 语义搜索，带超时和非阻塞检查
    private func semanticSearch(
        query: String,
        projectPath: String,
        pathFilter: String?,
        limit: Int
    ) async -> [CodeSearchResult] {
        // 快速检查：如果正在索引，直接跳过，避免卡在 actor 队列
        if RAGService.isAnyIndexing() {
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)search_code semantic: 跳过（后台索引进行中）")
            }
            return []
        }

        let service = await MainActor.run {
            RAGPlugin.getService()
        }
        guard service.isInitialized else { return [] }

        do {
            let response = try await service.retrieve(query: query, projectPath: projectPath, topK: limit)
            return response.results.compactMap { result in
                if let pathFilter, !result.source.localizedCaseInsensitiveContains(pathFilter) {
                    return nil
                }
                return CodeSearchResult(
                    source: result.source,
                    line: nil,
                    content: result.content,
                    score: result.score,
                    origin: .semantic
                )
            }
        } catch {
            RAGPlugin.logger.error("\(Self.t)search_code semantic search failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Helpers

    private func resolveProjectPath(arguments: [String: ToolArgument], context: ToolExecutionContext) -> String? {
        let explicit = trimmedNonEmpty(arguments["projectPath"]?.value as? String)
        let current = trimmedNonEmpty(context.currentProjectPath)

        guard let path = explicit ?? current else { return nil }
        return RAGPathUtils.normalizeProjectPath(path)
    }

    static func normalizedTopK(_ value: Any?) -> Int {
        let raw: Int
        if let int = value as? Int {
            raw = int
        } else if let double = value as? Double {
            raw = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            raw = int
        } else {
            raw = Self.defaultTopK
        }
        return min(max(raw, Self.minTopK), Self.maxTopK)
    }

    static func normalizedTimeout(_ value: Any?) -> TimeInterval {
        let raw: Double
        if let int = value as? Int {
            raw = Double(int)
        } else if let double = value as? Double {
            raw = double
        } else if let string = value as? String, let int = Int(string) {
            raw = Double(int)
        } else {
            raw = Self.defaultTimeoutSeconds
        }
        return min(max(raw, Self.minTimeoutSeconds), Self.maxTimeoutSeconds)
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func mergeResults(_ results: [CodeSearchResult], limit: Int) -> [CodeSearchResult] {
        var merged: [CodeSearchResult] = []
        var seen = Set<String>()

        for result in results.sorted(by: resultSort) {
            let key = "\(result.source)::\(result.line ?? 0)::\(result.content.prefix(120))"
            guard seen.insert(key).inserted else { continue }
            merged.append(result)
            if merged.count >= limit { break }
        }

        return merged
    }

    private func resultSort(_ lhs: CodeSearchResult, _ rhs: CodeSearchResult) -> Bool {
        if lhs.origin != rhs.origin {
            return lhs.origin.sortOrder < rhs.origin.sortOrder
        }
        return lhs.score > rhs.score
    }

    private func render(
        results: [CodeSearchResult],
        query: String,
        mode: SearchMode,
        projectPath: String,
        timedOut: Bool = false,
        timeoutSeconds: TimeInterval = Self.defaultTimeoutSeconds
    ) -> String {
        let timeoutNote = timedOut ? "\n⚠️ Search timed out after \(Int(timeoutSeconds))s. Results may be incomplete.\n" : ""

        guard !results.isEmpty else {
            return """
            ## Code Search

            No results found.

            Query: `\(query)`
            Mode: `\(mode.rawValue)`
            Project: `\(projectPath)`
            \(timedOut ? "⚠️ Search timed out after \(Int(timeoutSeconds))s.\n" : "")
            """
        }

        var output = """
        ## Code Search

        Query: `\(query)`
        Mode: `\(mode.rawValue)`
        Project: `\(projectPath)`
        Results: \(results.count)
        \(timeoutNote)
        """

        for (index, result) in results.enumerated() {
            let lineSuffix = result.line.map { ":\($0)" } ?? ""
            output += """
            ### \(index + 1). `\(result.source)\(lineSuffix)`

            Origin: `\(result.origin.rawValue)`, score: \(String(format: "%.3f", result.score))

            ```text
            \(result.content)
            ```

            """
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func snippet(from content: String, around range: Range<String.Index>, contextLines: Int = 2) -> String {
        let lines = content.components(separatedBy: .newlines)
        let line = lineNumber(in: content, at: range.lowerBound)
        let start = max(line - contextLines - 1, 0)
        let end = min(line + contextLines - 1, lines.count - 1)
        guard start <= end else { return "" }

        return (start...end).map { index in
            "\(index + 1): \(lines[index])"
        }.joined(separator: "\n")
    }

    private func lineNumber(in content: String, at index: String.Index) -> Int {
        content[..<index].reduce(1) { partial, character in
            character == "\n" ? partial + 1 : partial
        }
    }
}

private enum SearchMode: String {
    case hybrid
    case keyword
    case semantic

    public var includesKeyword: Bool {
        self == .hybrid || self == .keyword
    }

    public var includesSemantic: Bool {
        self == .hybrid || self == .semantic
    }
}

private struct CodeSearchResult {
    public let source: String
    public let line: Int?
    public let content: String
    public let score: Float
    public let origin: CodeSearchOrigin
}

private enum CodeSearchOrigin: String {
    case keyword
    case semantic

    public var sortOrder: Int {
        switch self {
        case .keyword:
            return 0
        case .semantic:
            return 1
        }
    }
}
