import Foundation

/// 在语义索引没有返回结果时，直接从项目文件中寻找词法命中。
///
/// 这是首次查询和索引更新期间的兜底路径，不写入 SQLite，也不生成 embedding。
public enum RAGLexicalFileSearcher {
    private static let maxFilesToInspect = 2_000
    private static let contextLineCount = 8

    public static func search(
        query: String,
        projectPath: String,
        topK: Int
    ) throws -> [RAGSearchResult] {
        let terms = RAGTextUtils.tokenize(query.lowercased())
        guard !terms.isEmpty else { return [] }

        let files = RAGFileScanner.discoverFilesCached(in: projectPath)
        var matches: [(filePath: String, score: Float, content: String)] = []
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
                    content: $0.content,
                    source: RAGPathUtils.displayPath(filePath: $0.filePath, projectPath: projectPath),
                    score: $0.score
                )
            }
    }

    private static func makeSnippet(content: String, terms: [String]) -> String {
        let lines = content.components(separatedBy: "\n")
        let lowerTerms = terms.map { $0.lowercased() }
        let firstMatch = lines.firstIndex { line in
            let lowerLine = line.lowercased()
            return lowerTerms.contains { lowerLine.contains($0) }
        } ?? 0
        let start = max(firstMatch - contextLineCount / 2, 0)
        let end = min(start + contextLineCount, lines.count)

        return lines[start..<end].enumerated()
            .map { "\(start + $0.offset + 1)\t\($0.element)" }
            .joined(separator: "\n")
    }
}
