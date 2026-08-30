import Foundation

/// 删除同一批检索结果中的重复证据。
///
/// 语义 chunk 可能因为重叠窗口返回相同内容；来源和行范围一起参与 key，
/// 避免只按文件去重而误删同一文件中的不同证据。
public enum RAGResultDeduplicator {
    public static func deduplicate(
        _ results: [RAGSearchResult],
        limit: Int? = nil
    ) -> [RAGSearchResult] {
        if let limit, limit <= 0 { return [] }

        var seen = Set<String>()
        var unique: [RAGSearchResult] = []
        unique.reserveCapacity(results.count)

        for result in results {
            let lineKey = result.lineRange.map { "\($0.startLine)-\($0.endLine)" } ?? "-"
            let key = "\(result.source)|\(lineKey)|\(result.content)"
            guard seen.insert(key).inserted else { continue }

            unique.append(result)
            if let limit, unique.count >= limit {
                break
            }
        }
        return unique
    }
}
