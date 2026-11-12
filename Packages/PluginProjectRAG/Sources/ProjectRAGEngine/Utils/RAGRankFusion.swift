import Foundation

/// 参与融合的单条证据（与具体结果类型解耦，协调器与索引检索共用）。
public struct RAGFusionInput: Sendable {
    public let source: String
    public let startLine: Int?
    public let endLine: Int?
    public let content: String
    public let score: Float

    public init(source: String, startLine: Int?, endLine: Int?, content: String, score: Float) {
        self.source = source
        self.startLine = startLine
        self.endLine = endLine
        self.content = content
        self.score = score
    }
}

/// 融合结果用 (listIndex, itemIndex) 指回原始证据，保留完整 payload。
public struct RAGFusionOutput: Sendable {
    public let listIndex: Int
    public let itemIndex: Int
    public let fusedScore: Double
    public let bestOriginalScore: Float
}

/// Reciprocal Rank Fusion：`rrf(d) = Σ 1/(k + rank_i(d))`，k = 60。
///
/// 跨路原始分量纲不同（语义 cosine、词法命中率、路径命中率），禁止恢复
/// 原始分排序——那会让单路高分证据压过跨源共识。每个输入 list 必须已按
/// 各自内部排序排好；输出按 rrf 降序，展示分保留簇内最佳原始分。
public enum RAGRankFusion {
    public static let k = 60

    public static func fuse(_ lists: [[RAGFusionInput]], limit: Int) -> [RAGFusionOutput] {
        struct Member {
            let listIndex: Int
            let itemIndex: Int
            let rank: Int
        }
        struct Cluster {
            let anchor: RAGFusionInput
            var members: [Member]
            var bestScore: Float
            var rrf: Double
        }

        var clusters: [Cluster] = []
        for (listIndex, list) in lists.enumerated() {
            for (rank, item) in list.enumerated() {
                let contribution = 1.0 / Double(k + rank + 1)
                if let index = clusters.firstIndex(where: { isDuplicate($0.anchor, item) }) {
                    clusters[index].members.append(Member(listIndex: listIndex, itemIndex: rank, rank: rank))
                    clusters[index].rrf += contribution
                    clusters[index].bestScore = max(clusters[index].bestScore, item.score)
                } else {
                    clusters.append(Cluster(
                        anchor: item,
                        members: [Member(listIndex: listIndex, itemIndex: rank, rank: rank)],
                        bestScore: item.score,
                        rrf: contribution
                    ))
                }
            }
        }

        return clusters
            .sorted {
                if $0.rrf != $1.rrf { return $0.rrf > $1.rrf }
                return $0.anchor.source < $1.anchor.source
            }
            .prefix(max(limit, 1))
            .map { cluster in
                // 代表取排名最前者（rank 最小，平手取更靠前的 list）。
                let representative = cluster.members.min {
                    ($0.rank, $0.listIndex) < ($1.rank, $1.listIndex)
                }!
                return RAGFusionOutput(
                    listIndex: representative.listIndex,
                    itemIndex: representative.itemIndex,
                    fusedScore: cluster.rrf,
                    bestOriginalScore: cluster.bestScore
                )
            }
    }

    /// 同文件区间相交视为同一证据；内容完全相同也去重。
    private static func isDuplicate(_ a: RAGFusionInput, _ b: RAGFusionInput) -> Bool {
        if !a.content.isEmpty, a.content == b.content { return true }
        guard a.source == b.source else { return false }
        guard let aStart = a.startLine, let aEnd = a.endLine,
              let bStart = b.startLine, let bEnd = b.endLine else {
            return a.startLine == b.startLine && a.endLine == b.endLine
        }
        return aStart <= bEnd && bStart <= aEnd
    }
}