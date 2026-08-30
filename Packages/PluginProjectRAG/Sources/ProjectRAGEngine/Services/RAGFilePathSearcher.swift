import Foundation

/// 在用户明确提到文件名或路径时，按项目文件路径寻找候选文件。
///
/// 路径检索不读取文件内容，也不需要 embedding；只有查询包含路径分隔符或代码文件
/// 扩展名时才启用，避免普通自然语言查询额外遍历项目。
public enum RAGFilePathSearcher {
    private static let codeFileExtensions = RAGFileScanner.allowedExtensions

    public static func search(
        query: String,
        projectPath: String,
        topK: Int
    ) throws -> [RAGSearchResult] {
        guard hasPathHint(query) else { return [] }

        let queryTerms = RAGTextUtils.tokenize(query.lowercased())
        guard !queryTerms.isEmpty else { return [] }

        let directMatches = directPathMatches(query: query, projectPath: projectPath)
        if !directMatches.isEmpty {
            return directMatches.prefix(max(topK, 1)).map { $0 }
        }

        let matches = RAGFileScanner.discoverFilesCached(in: projectPath).compactMap { filePath -> RAGSearchResult? in
            let source = RAGPathUtils.displayPath(filePath: filePath, projectPath: projectPath)
            let score = RAGTextUtils.sourcePathBoost(queryTerms: queryTerms, filePath: source)
            guard score > 0 else { return nil }

            return RAGSearchResult(
                content: source,
                source: source,
                score: score,
                matchKind: .filesystemPath,
                lineRange: nil
            )
        }

        return matches
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.source < $1.source
            }
            .prefix(max(topK, 1))
            .map { $0 }
    }

    private static func directPathMatches(query: String, projectPath: String) -> [RAGSearchResult] {
        let projectRoot = RAGPathUtils.normalizeProjectPath(projectPath)
        guard !projectRoot.isEmpty else { return [] }

        let candidates = pathCandidates(in: query)
        return candidates.compactMap { candidate in
            let fileURL: URL
            if candidate.hasPrefix("/") {
                fileURL = URL(fileURLWithPath: candidate)
            } else {
                fileURL = URL(fileURLWithPath: projectRoot).appendingPathComponent(candidate)
            }

            let filePath = fileURL.standardizedFileURL.path
            let projectPrefix = projectRoot == "/" ? "/" : projectRoot + "/"
            guard filePath.hasPrefix(projectPrefix),
                  !RAGFileScanner.shouldSkipPath(filePath),
                  RAGFileScanner.allowedExtensions.contains(fileURL.pathExtension.lowercased()),
                  let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else {
                return nil
            }

            let source = RAGPathUtils.displayPath(filePath: filePath, projectPath: projectRoot)
            return RAGSearchResult(
                content: source,
                source: source,
                score: 1,
                matchKind: .filesystemPath,
                lineRange: nil
            )
        }
    }

    private static func pathCandidates(in query: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z0-9_./-]+"#) else { return [] }
        let nsQuery = query as NSString
        let range = NSRange(location: 0, length: nsQuery.length)
        return regex.matches(in: query, range: range).compactMap { match in
            let candidate = nsQuery.substring(with: match.range)
            let lowercased = candidate.lowercased()
            let hasExtension = codeFileExtensions.contains { lowercased.hasSuffix(".\($0)") }
            guard candidate.contains("/") || hasExtension else { return nil }
            return candidate
        }
    }

    private static func hasPathHint(_ query: String) -> Bool {
        let lowercased = query.lowercased()
        if lowercased.contains("/") || lowercased.contains("\\") {
            return true
        }
        return codeFileExtensions.contains { lowercased.contains(".\($0)") }
    }
}
