import AgentToolKit
import Foundation
import RAGKit

struct RAGCodeSearchTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "RAG"
    nonisolated static let verbose: Bool = true

    let name = "search_code"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            在当前项目中搜索代码片段。适合查找符号、错误字符串、文件路径、实现位置，或按自然语言描述检索相关代码。

            默认使用 hybrid 模式：结合精确关键字搜索和 RAG 语义检索。keyword 模式不依赖索引；semantic 模式依赖 RAG 索引。
            """
        case .english:
            return """
            Search code snippets in the current project. Use this to find symbols, error strings, file paths, implementation locations, or code related to a natural-language query.

            The default hybrid mode combines exact keyword search with RAG semantic retrieval. Keyword mode does not require an index; semantic mode uses the RAG index.
            """
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let queryDescription: String
        let modeDescription: String
        let topKDescription: String
        let pathFilterDescription: String
        let projectPathDescription: String

        switch language {
        case .chinese:
            queryDescription = "要搜索的关键字、符号名、错误文本或自然语言问题。"
            modeDescription = "搜索模式。keyword 为精确文本搜索，semantic 为 RAG 语义检索，hybrid 会合并两者。默认 hybrid。"
            topKDescription = "最多返回多少条结果，默认 8，范围 1-20。"
            pathFilterDescription = "可选，仅返回路径中包含该字符串的文件。"
            projectPathDescription = "可选，项目根路径。默认使用当前会话的项目路径。"
        case .english:
            queryDescription = "Keyword, symbol name, error text, or natural-language question to search for."
            modeDescription = "Search mode. keyword performs exact text search, semantic uses RAG retrieval, and hybrid merges both. Defaults to hybrid."
            topKDescription = "Maximum number of results to return. Defaults to 8, range 1-20."
            pathFilterDescription = "Optional path substring filter."
            projectPathDescription = "Optional project root path. Defaults to the current session project path."
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
                ],
                "pathFilter": [
                    "type": "string",
                    "description": pathFilterDescription,
                ],
                "projectPath": [
                    "type": "string",
                    "description": projectPathDescription,
                ],
            ],
            "required": ["query"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let query = (arguments["query"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let preview = query.isEmpty ? "code" : String(query.prefix(40))
        return "Search code: \(preview)"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let rawQuery = arguments["query"]?.value as? String else {
            return "## Code Search\n\nMissing required `query` parameter."
        }

        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return "## Code Search\n\n`query` must not be empty."
        }

        let mode = SearchMode(rawValue: (arguments["mode"]?.value as? String)?.lowercased() ?? "") ?? .hybrid
        let topK = normalizedTopK(arguments["topK"]?.value)
        let pathFilter = (arguments["pathFilter"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

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

        var results: [CodeSearchResult] = []

        if mode.includesKeyword {
            results.append(contentsOf: keywordSearch(
                query: query,
                projectPath: projectPath,
                pathFilter: pathFilter,
                limit: topK
            ))
        }

        if mode.includesSemantic {
            results.append(contentsOf: await semanticSearch(
                query: query,
                projectPath: projectPath,
                pathFilter: pathFilter,
                limit: topK
            ))
        }

        let merged = mergeResults(results, limit: topK)
        return render(results: merged, query: query, mode: mode, projectPath: projectPath)
    }

    private func resolveProjectPath(arguments: [String: ToolArgument], context: ToolExecutionContext) -> String? {
        let explicit = (arguments["projectPath"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let current = context.currentProjectPath?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        guard let path = explicit ?? current else { return nil }
        return RAGPathUtils.normalizeProjectPath(path)
    }

    private func normalizedTopK(_ value: Any?) -> Int {
        let raw: Int
        if let int = value as? Int {
            raw = int
        } else if let double = value as? Double {
            raw = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            raw = int
        } else {
            raw = 8
        }
        return min(max(raw, 1), 20)
    }

    private func keywordSearch(
        query: String,
        projectPath: String,
        pathFilter: String?,
        limit: Int
    ) -> [CodeSearchResult] {
        let lowerQuery = query.lowercased()
        let files = RAGFileScanner.discoverFiles(in: projectPath)
            .filter { filePath in
                guard let pathFilter else { return true }
                return filePath.localizedCaseInsensitiveContains(pathFilter)
            }

        var matches: [CodeSearchResult] = []
        matches.reserveCapacity(limit)

        for filePath in files {
            guard matches.count < limit else { break }
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
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

    @MainActor
    private func semanticSearch(
        query: String,
        projectPath: String,
        pathFilter: String?,
        limit: Int
    ) async -> [CodeSearchResult] {
        let service = RAGPlugin.getService()
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
            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.error("\(Self.t)search_code semantic search failed: \(error.localizedDescription)")
            }
            return []
        }
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
        projectPath: String
    ) -> String {
        guard !results.isEmpty else {
            return """
            ## Code Search

            No results found.

            Query: `\(query)`
            Mode: `\(mode.rawValue)`
            Project: `\(projectPath)`
            """
        }

        var output = """
        ## Code Search

        Query: `\(query)`
        Mode: `\(mode.rawValue)`
        Project: `\(projectPath)`
        Results: \(results.count)

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

    var includesKeyword: Bool {
        self == .hybrid || self == .keyword
    }

    var includesSemantic: Bool {
        self == .hybrid || self == .semantic
    }
}

private struct CodeSearchResult {
    let source: String
    let line: Int?
    let content: String
    let score: Float
    let origin: CodeSearchOrigin
}

private enum CodeSearchOrigin: String {
    case keyword
    case semantic

    var sortOrder: Int {
        switch self {
        case .keyword:
            return 0
        case .semantic:
            return 1
        }
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self, !value.isEmpty else { return nil }
        return value
    }
}
